export const meta = {
  name: 'review',
  description: 'Review a diff one unit at a time, check the seams between units, and try to disprove every bug before it counts',
  phases: [{ title: 'Find' }, { title: 'Disprove' }],
}

const { epic, spec, tree, base, projectBase, context, units, levels } = args
if (!levels) throw new Error('pass levels: one account set from scripts/levels.json')

const EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max']
const used = {}
// Critical work runs at least at the critical effort. A DeepSeek model binds only through an agent file's
// frontmatter, so it runs as the agent named for it.
const run = (role, prompt, opts, critical = false) => {
  const l = levels[role]
  if (!l) throw new Error(`no role named ${role}`)
  const floor = critical && levels.critical.effort
  const effort = l.effort && floor && EFFORTS.indexOf(floor) > EFFORTS.indexOf(l.effort) ? floor : l.effort
  const bind = l.model.startsWith('deepseek') ? { agentType: `${l.model.replace('[1m]', '')}-agent` } : { model: l.model }
  used[role] = (used[role] || 0) + 1
  return agent(prompt, { ...opts, ...bind, ...(effort && { effort }), label: `${role}${critical ? ' critical' : ''}(${l.model}${effort ? `/${effort}` : ''}): ${opts.label}` })
}

const STR = { type: 'string' }
const FINDINGS = {
  type: 'object',
  properties: {
    escalate: { type: 'boolean' },
    reason: STR,
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          class: { type: 'string', enum: ['bug', 'quality', 'design', 'debt'] },
          file: STR,
          line: { type: 'number' },
          summary: STR,
          failure_scenario: STR,
          impact: STR,
          instances: { type: 'array', items: STR },
        },
        required: ['class', 'file', 'line', 'summary'],
      },
    },
  },
  required: ['escalate', 'findings'],
}
const VERDICT = {
  type: 'object',
  properties: { verdict: { type: 'string', enum: ['disproved', 'holds', 'unsure'] }, why: STR },
  required: ['verdict', 'why'],
}

const KINDS = `Report four kinds of finding, each at a file and line you opened:
- bug: the code does the wrong thing, and you can name the inputs or state and the wrong result. It includes behavior deleted that something still needs, and a new test that would pass with its change reverted. Put the inputs and the wrong result in failure_scenario.
- quality: a misleading name, dead code, duplicated logic, or a change unrelated to this work, that the next reader would stumble on.
- design: built wrong for the job: far more machinery than the problem needs, or code where nobody would look for it.
- debt: a shortcut that works today and sends a bill later.
Put what a quality, design, or debt finding costs in impact. Skip style, anything a linter or type checker catches, and problems older than this diff that it does not worsen. The same mistake three times is one finding listing its instances. Not sure it is a finding: leave it out.
If the approach cannot meet the goal at all, set escalate, give the one finding that shows it, say in reason what is wrong underneath, and stop.

Read only: edit nothing, spawn nothing.`

const unitPrompt = u => `Review unit ${u.id}${u.title ? ` (${u.title})` : ''} of ${epic}. Other reviewers hold the rest of the diff.
Why the change was made: ${context}
Spec: ${spec}.
Your files: ${u.files.join(', ')}
Their diff: \`git -C ${tree} --no-pager diff -M ${base}...HEAD -- <your files>\`. The base is ${base}. Read each changed file whole, not only its changed lines; a moved file shows as a rename, and only its changed lines need review.
Compare behavior against ${projectBase}: for every threshold, default, limit, timeout, and enabled or armed state the diff adds, moves, or changes, read ${projectBase}'s value (\`git -C ${tree} --no-pager show ${projectBase}:<path>\`). A difference the spec does not order is a bug; for one it orders, cite the spec line.

${KINDS}`

const seamPrompt = `Check the seams of ${epic}'s diff: the places where changed code in one unit calls changed code in another. Separate reviewers hold each unit, and separate workers wrote them, so the connections are where they misread each other.
Why the change was made: ${context}
Spec: ${spec}.
The units: ${units.map(u => `${u.id}: ${u.files.join(', ')}`).join('; ')}
The diff: \`git -C ${tree} --no-pager diff -M ${base}...HEAD\`. Review only the calls, shapes, and shared state that cross between units.

${KINDS}`

const disprovePrompt = f => `A reviewer claims a bug in the tree at ${tree}, at ${f.file}:${f.line}:
${f.failure_scenario || f.summary}
Read the code fresh and try to prove the failure cannot happen: trace the inputs from where they enter to where the wrong result would appear.
Return disproved when you prove it cannot happen, holds when you followed the failure start to finish, and unsure otherwise. Say why in one or two sentences.

Read only: edit nothing, spawn nothing.`

const jobs = units.map(u => ({ id: u.id, critical: u.level === 'critical', prompt: unitPrompt(u) }))
if (units.length > 1) jobs.push({ id: 'seams', critical: false, prompt: seamPrompt })

const reviewed = await pipeline(
  jobs,
  job => run('review', job.prompt, { label: `${job.id} review`, phase: 'Find', schema: FINDINGS }, job.critical),
  async (found, job) => {
    if (!found) return null
    const checked = await parallel(found.findings.map(f => async () => {
      if (f.class !== 'bug') return f
      const v = await run('review', disprovePrompt(f), { label: `${job.id} disprove ${f.file}:${f.line}`, phase: 'Disprove', schema: VERDICT }, job.critical)
      if (v && v.verdict === 'disproved') return null
      return { ...f, verdict: v && v.verdict === 'holds' ? 'CONFIRMED' : 'PLAUSIBLE' }
    }))
    return { ...found, findings: checked.filter(Boolean).map(f => ({ ...f, unit: job.id, critical: job.critical })) }
  },
)

const silent = jobs.filter((_, i) => !reviewed[i]).map(j => j.id)
if (silent.length) log(`no review returned for ${silent.join(', ')}`)
const done = reviewed.filter(Boolean)
const findings = done.flatMap(r => r.findings)
const escalations = done.filter(r => r.escalate)
const gate = escalations.length ? 'escalate'
  : silent.length ? 'incomplete'
  : findings.some(f => f.class === 'bug') ? 'fail' : 'pass'
return { gate, reason: escalations.map(r => r.reason).join('\n\n'), findings, silent, used }
