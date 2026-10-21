export const meta = {
  name: 'dev-workflow-milestone',
  description: 'Build one milestone of an ultra spec on fixed model roles: scaffold, failing tests, workers, review, a fold in parallel groups, and one verify',
  phases: [
    { title: 'Scaffold' },
    { title: 'Tests' },
    { title: 'Build' },
    { title: 'Decide' },
    { title: 'Review' },
    { title: 'Fold' },
    { title: 'Verify' },
  ],
}

const { epic, spec, plan, tree, base, projectBase, scripts, levels, milestone: m, logs, brief = '', decisions = {}, settled = {}, reviewed = null, folded = {} } = args
if (!levels || !scripts) throw new Error('pass levels (one account set from scripts/levels.json) and scripts (that directory, absolute)')

// A task's level: pinned and open name the role that fills it, and a critical task fills on open.
const LEVELS = ['pinned', 'open', 'critical']
const roleOf = level => (level === 'critical' ? 'open' : level)
const EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max']
const used = {}
const rerun = []
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
const REPORT = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['done', 'question'] },
    files: { type: 'array', items: STR },
    commits: { type: 'array', items: STR },
    question: STR,
    notes: STR,
  },
  required: ['status', 'files', 'commits'],
}
const BUILT = {
  ...REPORT,
  properties: { ...REPORT.properties, green: { type: 'boolean' } },
  required: [...REPORT.required, 'green'],
}
// A fold leaves a fix in a file another fold holds; once every group is done, one agent does what they left.
const FOLDED = {
  ...REPORT,
  properties: {
    ...REPORT.properties,
    left: { type: 'array', items: { type: 'object', properties: { file: STR, change: STR }, required: ['file', 'change'] } },
  },
}
const DECISIONS = {
  type: 'object',
  properties: {
    answers: {
      type: 'array',
      items: { type: 'object', properties: { key: STR, redesign: { type: 'boolean' }, decision: STR }, required: ['key', 'redesign', 'decision'] },
    },
  },
  required: ['answers'],
}
const VERIFY = {
  type: 'object',
  properties: {
    gate: { type: 'string', enum: ['pass', 'fail', 'escalate'] },
    reason: STR,
    findings: { type: 'array', items: { type: 'object' } },
  },
  required: ['gate', 'findings'],
}

const CONTEXT = `Spec: ${spec} — read the sections this work names. Milestone ${m.id}: ${m.title}. Its proof: \`${m.proof}\`.`
const SHARED = `Work only in ${tree}, by absolute path and \`git -C ${tree}\`. Other agents share this tree and its git index: commit only your own files, naming them — \`git -C ${tree} commit -m "<subject in the project's commit format; the ticket is ${epic}>" -- <your files>\`. Never run git reset, checkout --, stash, clean, restore, push, or merge. Edits you did not make belong to a sibling; leave them. Do the work yourself and spawn nothing. Leave the session's task list alone: it is the user's view of the run, so no TaskCreate or TaskUpdate. A decision you cannot make from the code and the spec: stop, set status to question, and say what you did.`
const decided = key => (decisions[key] ? `\n\nThe parent decided: ${decisions[key]}` : '')
const decidedHere = []
const stopped = (stage, key, report, rest) => ({ stopped: stage, key, report, decided: decidedHere, usage: { used, rerun }, ...rest })
const asked = r => !r || r.status === 'question'
// No agent runs the end-to-end tests: workers and the fold run unit tests, and green means those pass.
const stuck = r => asked(r) || r.green === false

// A question is answered inside the run with the coordinator's authority; only a redesign returns to it.
// One decider at a time takes every question then waiting, so its answers agree with each other and with every
// earlier one. The brief leads its prompt unchanged, so each decider after the first reads it from the prompt cache.
const running = new Map()
const waiting = []
let deciding = false
const decide = (key, critical, asking, report) => new Promise(resolve => { waiting.push({ key, critical, asking, report, resolve }); drain() })
const drain = async () => {
  if (deciding || !waiting.length) return
  deciding = true
  const batch = waiting.splice(0)
  let out = null
  try {
    out = await run('decide',
      `${brief ? `${brief}\n\n---\n\n` : ''}${CONTEXT}

You answer for the build's coordinator. These agents stopped with questions; answer every one under its key.
${batch.map(q => `${q.key} (${q.asking}): ${JSON.stringify(q.report)}`).join('\n\n')}

Decided earlier in this run: ${decidedHere.length ? JSON.stringify(decidedHere) : 'nothing'}
Running now, each owning its files: ${[...running].map(([id, files]) => `${id} (${files.join(', ')})`).join('; ') || 'nothing'}

Decide from the spec, the plan at ${plan}, and the code; read whatever you need. Every answer is yours to give: a file outside the task's list, a change to a signature, type, or schema the scaffold committed, an edit to a committed test that keeps what it proves, a choice the spec leaves open, or part of the work deferred to a later task whose card can absorb it.
- Your answers agree with each other and with every earlier decision, and never give two tasks running now the same file.
- Record each decision: append a line starting "Decided during the build:" to that task's section of the plan, and to each later task's section it changes. A decision that changes what the spec says goes into the spec too, committed alone: \`git -C ${tree} commit -m "<subject in the project's commit format; the ticket is ${epic}>" -- ${spec}\`.
- Set redesign only when the design itself cannot work and a component or the milestone order must be redrawn, so that carrying on would waste the build. Then say what is wrong in decision and change nothing.
- Edit only the plan and the spec. Never run git reset, checkout --, stash, clean, restore, push, or merge. Do the work yourself and spawn nothing.`,
      { label: `decide ${batch.map(q => q.key).join(', ')}`, phase: 'Decide', schema: DECISIONS }, batch.some(q => q.critical))
  } catch (e) {
    out = null
  }
  batch.forEach(q => q.resolve((out && out.answers.find(a => a.key === q.key)) || null))
  deciding = false
  drain()
}

// A rerun reports only what it touched, so the stage's files and commits are every round's.
const answered = async (key, role, asking, prompt, opts, critical = false) => {
  const files = new Set(), commits = new Set()
  const kept = r => { for (const f of r?.files || []) files.add(f); for (const c of r?.commits || []) commits.add(c); return r }
  let report = kept(await run(role, prompt, opts, critical))
  let said = ''
  for (let round = 1; report && report.status === 'question' && round <= 3; round++) {
    const d = await decide(key, critical, asking, report)
    if (!d || d.redesign) return { ...report, redesign: d ? d.decision : 'the decider died' }
    decidedHere.push({ key, question: report.question, decision: d.decision })
    said += `\n\nYou asked: ${report.question}\nThe coordinator decided: ${d.decision}`
    report = kept(await run(role, `${prompt}${said}\n\nYour earlier runs' commits stay; build on them.`, { ...opts, label: `${opts.label} answered ${round}` }, critical))
  }
  return report && { ...report, files: [...files], commits: [...commits] }
}

const unlevelled = m.tasks.filter(t => !LEVELS.includes(t.level)).map(t => t.id)
if (unlevelled.length) return stopped('plan', 'plan', null, { reason: `no level on ${unlevelled.join(', ')}` })

phase('Scaffold')
const scaffold = await answered('scaffold', 'plan', 'The scaffold',
  `${CONTEXT}

You are this milestone's scaffold. Make the moves first, one commit per move, with \`git mv\` so history follows. Then create every new file, signature, type, and schema the tasks below fill, with bodies that raise NotImplementedError or the language's equivalent. Write no behavior.

${m.scaffold}

Tasks that fill it:
${m.tasks.map(t => `- ${t.id}: ${t.title} (${t.files.join(', ')})`).join('\n')}

${SHARED}${decided('scaffold')}`,
  { label: `${m.id} scaffold`, phase: 'Scaffold', schema: REPORT })
if (asked(scaffold)) return stopped('scaffold', 'scaffold', scaffold)

phase('Tests')
const tests = await answered('tests', 'plan', 'The test writer',
  `${CONTEXT}

Write the failing integration tests that prove this milestone, against the scaffold now committed. ${m.tests}
The proof drives the real entry point on the settings a fresh install ships with (code defaults and shipped config templates, no test-only overrides), over data shaped like real use: realistic ages, volumes, and refresh cadence. Every other test drives the same entry points on the bed's fast profile: each duration a test waits through (a cadence, a recovery period, a resolve) is a setting whose default is the shipped value and which the bed sets short, and every wait derives from the profile, never from a hand-typed number. The milestone's tests together run in under 15 minutes serially. Doubles only at external boundaries; never a double that re-implements this system's own logic.
Write integration tests only, matching the harness, fixtures, and naming of the project's existing suites. Implement nothing, and change no signature, type, or schema the scaffold committed: a test that needs one changed is a question.
Every test must run and fail for a reason you can name. A test that errors at import, collection, or setup is not failing; report it rather than working around it.
List each test path in files, and put its failing output in notes.

${SHARED}${decided('tests')}`,
  { label: `${m.id} tests`, phase: 'Tests', schema: REPORT })
if (asked(tests)) return stopped('tests', 'tests', tests, { scaffold })

const word = id => new RegExp(`\\b${id.replace(/\./g, '\\.')}\\b`)
const touches = (b, t) => (b.files || []).some(f => t.files.some(g => (g.endsWith('/') ? `/${f}`.includes(`/${g}`) : `/${f}`.endsWith(`/${g}`))))
const handed = t => built.filter(b => b.notes && (word(t.id).test(b.notes) || touches(b, t))).map(b => `${b.id}: ${b.notes}`)
const card = (t, layer) => `${CONTEXT}

Task ${t.id}: ${t.title}
Files you own: ${t.files.join(', ')}

${t.card}

- Read the lines starting "Decided during the build:" in ${t.id}'s section of ${plan} first: they record decisions made after this card was written, and they override it.
- Your files are where the work starts, not a fence. A file outside them that no task running beside you owns: edit it, commit it with yours, list it in files, and say why in notes. A question is only a file a task running beside you owns, a change to a signature, type, or schema the scaffold committed, or an edit to a committed test.
- Read each file you edit end to end before editing it, and one or two similar files in the codebase for the pattern to follow.
- Comment only what the code cannot say for itself, and fix any comment your change makes wrong.
- The milestone's failing tests: ${tests.files.join(', ')}. Write the code that passes the ones your task covers, but run none of them: they run once, end to end, after every task is done. Run the unit tests of your files, and the linter and type checker on your files; never the end-to-end tests or the full suite.
- Prove each unit test you add: break the line it guards, see it fail, and restore the line by editing it back. Commit only the restored code.
- Set green when the unit tests of your files, the linter, and the type checker pass.

Running beside you: ${layer.filter(s => s.id !== t.id && !settled[s.id]).map(s => `${s.id} (${s.files.join(', ')})`).join('; ') || 'nobody'}.${handed(t).length ? `

Finished tasks' reports that name yours:
${handed(t).join('\n\n')}` : ''}

${SHARED}${decided(t.id)}`

const build = async (t, layer) => {
  // A resume re-runs every agent call after the first changed one, so finished tasks come back as settled reports.
  if (settled[t.id]) return settled[t.id]
  running.set(t.id, t.files)
  try {
    return await attempt(t, layer)
  } finally {
    running.delete(t.id)
  }
}

const attempt = async (t, layer) => {
  const critical = t.level === 'critical'
  const first = await answered(t.id, roleOf(t.level), `The worker on ${t.id}`, card(t, layer), { label: t.id, phase: 'Build', schema: BUILT }, critical)
  if ((first && (first.status === 'question' || !stuck(first))) || critical) return first && { ...first, level: t.level }
  // A stuck worker reruns once on open: a pinned task moves up a model, an open one gets a fresh start.
  rerun.push(t.id)
  const second = await answered(t.id, 'open', `The worker on ${t.id}`,
    `${card(t, layer)}

A ${t.level} worker took this task first and stopped short. Its report: ${JSON.stringify(first)}
Its commits stay; build on them.`,
    { label: `${t.id} rerun`, phase: 'Build', schema: BUILT })
  return second && { ...second, level: 'open', first }
}

phase('Build')
// A task starts as soon as every task it comes after is done, never when a whole layer is. A stuck task
// starts nothing new; those already running finish, so a resume finds them settled.
const built = []
const done = new Set()
const started = new Set()
const inFlight = new Map()
let halted = null
while (true) {
  if (!halted) {
    const batch = m.tasks.filter(t => !started.has(t.id) && (t.after || []).every(a => done.has(a)))
    const beside = [...m.tasks.filter(s => inFlight.has(s.id)), ...batch]
    for (const t of batch) {
      started.add(t.id)
      inFlight.set(t.id, build(t, beside).then(report => ({ t, report }), () => ({ t, report: null })))
    }
  }
  if (!inFlight.size) break
  const { t, report } = await Promise.race(inFlight.values())
  inFlight.delete(t.id)
  built.push({ id: t.id, ...report })
  // A settled report is finished: the parent closed it, whatever its green said under the rule it ran on.
  if (!settled[t.id] && stuck(report)) halted = halted || { t, report }
  else done.add(t.id)
}
if (halted) return stopped('build', halted.t.id, halted.report, { built })
const unready = m.tasks.filter(t => !started.has(t.id))
if (unready.length) return stopped('build', 'plan', null, { reason: `no task is ready: ${unready.map(t => t.id).join(', ')}`, built })

phase('Review')
// A resume replays only the unbroken prefix of calls in their first order, and a fan-out's calls return in a
// new order, so a finished review reaches a resume through its args, never through the cache.
const review = reviewed || await workflow({ scriptPath: `${scripts}/review.workflow.js` }, {
  epic, spec, tree, base, projectBase, levels,
  context: CONTEXT,
  units: m.tasks.map(t => ({ id: t.id, title: t.title, files: t.files, level: t.level })),
})
if (review && !reviewed) Object.entries(review.used).forEach(([role, n]) => { used[role] = (used[role] || 0) + n })
if (!review || review.gate === 'escalate' || review.gate === 'incomplete') return stopped('review', 'review', review, { built })

const fixable = review.findings.filter(f => f.class === 'bug' || f.class === 'quality')

// The fold runs one agent per group of related findings, all at once, each group on files no other group holds.
// A finding holds its file and every file of its task; findings that share a file share a group, and groups are
// packed into agents of up to FOLD_CAP findings. M-1's single fold took 3.5 h on 84 findings, about 2.5 min each:
// 24 is about an hour per agent.
const FOLD_CAP = 24
const rel = f => (f && f.startsWith(`${tree}/`) ? f.slice(tree.length + 1) : f)
const foldGroups = findings => {
  const taskFiles = Object.fromEntries(m.tasks.map(t => [t.id, t.files.map(rel)]))
  const held = findings.map(f => [...new Set([rel(f.file), ...(taskFiles[f.unit] || [])].filter(Boolean))])
  const parent = findings.map((_, i) => i)
  const root = i => (parent[i] === i ? i : (parent[i] = root(parent[i])))
  const holder = new Map()
  held.forEach((files, i) => files.forEach(file => (holder.has(file) ? (parent[root(i)] = root(holder.get(file))) : holder.set(file, i))))
  const parts = new Map()
  findings.forEach((f, i) => {
    const part = parts.get(root(i)) || { findings: [], files: new Set() }
    part.findings.push(f)
    held[i].forEach(file => part.files.add(file))
    parts.set(root(i), part)
  })
  const criticalOf = p => p.findings.some(f => f.critical)
  const agents = []
  for (const part of [...parts.values()].sort((a, b) => criticalOf(b) - criticalOf(a) || b.findings.length - a.findings.length)) {
    const into = agents.find(a => a.findings.length + part.findings.length <= FOLD_CAP)
    if (into) {
      into.findings.push(...part.findings)
      part.files.forEach(file => into.files.add(file))
    } else agents.push({ findings: [...part.findings], files: new Set(part.files) })
  }
  return agents.map((a, i) => ({ key: `fold-${i + 1}`, findings: a.findings, files: [...a.files], critical: criticalOf(a) }))
}

let fold = null
let verify = null
if (fixable.length) {
  const foldCritical = fixable.some(f => f.critical)
  const groups = foldGroups(fixable)
  const foldRules = `- Fix every bug. Fix a quality finding only when it is small and provably behavior-preserving.
- A finding is a shape, not a line. Search the whole diff (\`git -C ${tree} --no-pager diff ${base}...HEAD\`) for every sibling path with the same shape and fix them all now.
- Read the whole path before editing; the line a finding names is often not the defect.
- Run the unit tests of every file you touch; never the end-to-end tests.`

  phase('Fold')
  const reports = await parallel(groups.map(g => async () => {
    if (folded[g.key]) return folded[g.key]
    const beside = groups.filter(o => o !== g)
    running.set(g.key, g.files)
    try {
      return await answered(g.key, 'open', `The fold of ${g.key}`,
        `${CONTEXT}

Fold these of the review's findings into the milestone in one pass:
${JSON.stringify(g.findings, null, 2)}

${foldRules}
- Your files: ${g.files.join(', ')}. ${beside.length ? `Folding beside you, each holding its own files: ${beside.map(o => `${o.key} (${o.files.join(', ')})`).join('; ')}. A fix or a sibling path in a file another fold holds: leave it and list it in left, with the file and the change it needs; it is done once every fold has finished. A file no fold holds is shared: re-read it right before each edit.` : 'No other fold runs beside you.'}

${SHARED}${decided(g.key)}`,
        { label: `${m.id} ${g.key}`, phase: 'Fold', schema: FOLDED }, g.critical)
    } finally {
      running.delete(g.key)
    }
  }))
  fold = groups.map((g, i) => ({ key: g.key, findings: g.findings.length, ...reports[i] }))
  const open = fold.find(asked)
  if (open) return stopped('fold', open.key, open, { built, review, fold })
  const left = fold.flatMap(f => (f.left || []).map(l => ({ ...l, from: f.key })))
  if (left.length) {
    const handoff = folded['fold-left'] || await answered('fold-left', 'open', 'The fold of what the groups left',
      `${CONTEXT}

The fold groups have all finished. Each left these changes in a file another group held; every file is free now. Make each one:
${JSON.stringify(left, null, 2)}

${foldRules}

${SHARED}${decided('fold-left')}`,
      { label: `${m.id} fold-left`, phase: 'Fold', schema: REPORT }, foldCritical)
    fold.push({ key: 'fold-left', findings: left.length, ...handoff })
    if (asked(handoff)) return stopped('fold', 'fold-left', handoff, { built, review, fold })
  }

  phase('Verify')
  verify = await run('review',
    `Round 2 of the review gate, for milestone ${m.id} of ${epic}, started cold.
Why the change was made: ${CONTEXT}
The diff: \`git -C ${tree} --no-pager diff ${base}...HEAD\`. The base is ${base}, not main.
Round 1's findings: ${JSON.stringify(review.findings)}
The fix commits: ${fold.flatMap(f => f.commits).join(', ')}.
What each fold said, including any finding or sibling path it left in a file another fold held: ${JSON.stringify(fold.map(f => ({ key: f.key, notes: f.notes || '' })))}
Answer only: is each round-1 finding fixed, and does any fix introduce a new problem. Read the fix commits as new code: they are the least-reviewed lines in the change. Run \`git -C ${tree} status --porcelain\`: every file it prints is a bug finding, naming the task that should have committed it, since a run's edit left uncommitted never reaches the bed. Return each finding still open, and each new problem, in findings; gate is fail when any is a bug, escalate when a fix broke something round 1 had passed.

Read only: edit nothing, spawn nothing.`,
    { label: `${m.id} verify`, phase: 'Verify', schema: VERIFY }, foldCritical)
}
return { scaffold, tests, built, review, fold, verify, decided: decidedHere, usage: { used, rerun } }
