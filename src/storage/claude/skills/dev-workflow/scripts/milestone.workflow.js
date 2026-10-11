export const meta = {
  name: 'dev-workflow-milestone',
  description: 'Build one milestone of an ultra spec on fixed model levels: scaffold, failing tests, workers, review, one fold, one verify',
  phases: [
    { title: 'Scaffold' },
    { title: 'Tests' },
    { title: 'Build' },
    { title: 'Review' },
    { title: 'Fold' },
    { title: 'Verify' },
  ],
}

const { epic, spec, tree, base, projectBase, scripts, levels, milestone: m, decisions = {}, settled = {} } = args
if (!levels || !scripts) throw new Error('pass levels (the contents of scripts/levels.json) and scripts (that directory, absolute)')

const ORDER = ['routine', 'judgment', 'critical']
const atLeast = (level, floor) => (ORDER.indexOf(level) >= ORDER.indexOf(floor) ? level : floor)
const highest = (list, floor) => list.reduce(atLeast, floor)
const used = { routine: 0, judgment: 0, critical: 0 }
const promoted = []
const run = (level, prompt, opts) => {
  const l = levels[level]
  if (!l) throw new Error(`no level named ${level}`)
  used[level]++
  return agent(prompt, { ...opts, model: l.model, effort: l.effort, label: `${level}(${l.model}/${l.effort}): ${opts.label}` })
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
const SHARED = `Work only in ${tree}, by absolute path and \`git -C ${tree}\`. Other agents share this tree and its git index: commit only your own files, naming them — \`git -C ${tree} commit -m "[${epic}] ${m.id} <what>" -- <your files>\`. Never run git reset, checkout --, stash, clean, restore, push, or merge. Edits you did not make belong to a sibling; leave them. Do the work yourself and spawn nothing. A decision you cannot make from the code and the spec: stop, set status to question, and say what you did.`
const decided = key => (decisions[key] ? `\n\nThe parent decided: ${decisions[key]}` : '')
const stopped = (stage, key, report, rest) => ({ stopped: stage, key, report, usage: { used, promoted }, ...rest })
const asked = r => !r || r.status === 'question'
// A milestone's tests run end to end, so only the last layer's workers can turn them green.
const stuck = (r, last) => asked(r) || (last && r.green === false)

const unlevelled = m.tasks.filter(t => !levels[t.level]).map(t => t.id)
if (unlevelled.length) return stopped('plan', 'plan', null, { reason: `no level on ${unlevelled.join(', ')}` })

phase('Scaffold')
const scaffold = await run('judgment',
  `${CONTEXT}

You are this milestone's scaffold. Make the moves first, one commit per move, with \`git mv\` so history follows. Then create every new file, signature, type, and schema the tasks below fill, with bodies that raise NotImplementedError or the language's equivalent. Write no behavior.

${m.scaffold}

Tasks that fill it:
${m.tasks.map(t => `- ${t.id}: ${t.title} (${t.files.join(', ')})`).join('\n')}

${SHARED}${decided('scaffold')}`,
  { label: `${m.id} scaffold`, phase: 'Scaffold', schema: REPORT })
if (asked(scaffold)) return stopped('scaffold', 'scaffold', scaffold)

phase('Tests')
const tests = await run('judgment',
  `${CONTEXT}

Write the failing integration tests that prove this milestone, against the scaffold now committed. ${m.tests}
Drive the real entry point on the settings a fresh install ships with (code defaults and shipped config templates, no test-only overrides), over data shaped like real use: realistic ages, volumes, and refresh cadence. Doubles only at external boundaries; never a double that re-implements this system's own logic.
Write integration tests only, matching the harness, fixtures, and naming of the project's existing suites. Implement nothing, and change no signature, type, or schema the scaffold committed: a test that needs one changed is a question.
Every test must run and fail for a reason you can name. A test that errors at import, collection, or setup is not failing; report it rather than working around it.
List each test path in files, and put its failing output in notes.

${SHARED}${decided('tests')}`,
  { label: `${m.id} tests`, phase: 'Tests', schema: REPORT })
if (asked(tests)) return stopped('tests', 'tests', tests, { scaffold })

const word = id => new RegExp(`\\b${id.replace(/\./g, '\\.')}\\b`)
const handed = t => built.filter(b => b.notes && word(t.id).test(b.notes)).map(b => `${b.id}: ${b.notes}`)
const card = (t, layer) => `${CONTEXT}

Task ${t.id}: ${t.title}
Files you own: ${t.files.join(', ')}

${t.card}

- Stay inside your files. Work that needs another file, a change to a signature, type, or schema the scaffold committed, or an edit to a committed test is a question.
- Read each file you edit end to end before editing it, and one or two similar files in the codebase for the pattern to follow.
- Comment only what the code cannot say for itself, and fix any comment your change makes wrong.
- The milestone's failing tests: ${tests.files.join(', ')}. Make the ones your task covers pass. Run them, the unit tests of your files, and the linter and type checker on your files; never the full suite.
- Prove each test you turn green: break the line it guards in your own file, run it and see it fail, restore the line by editing it back, and run it green again. Commit only the restored code; put each test and its break in notes.
- Set green only when every milestone test your task covers passes.

Running beside you: ${layer.filter(s => s.id !== t.id && !settled[s.id]).map(s => `${s.id} (${s.files.join(', ')})`).join('; ') || 'nobody'}.${handed(t).length ? `

Finished tasks' reports that name yours:
${handed(t).join('\n\n')}` : ''}

${SHARED}${decided(t.id)}`

const build = async (t, layer, last) => {
  // A resume re-runs every agent call after the first changed one, so finished tasks come back as settled reports.
  if (settled[t.id]) return settled[t.id]
  const first = await run(t.level, card(t, layer), { label: t.id, phase: 'Build', schema: BUILT })
  if (!stuck(first, last) || t.level === 'critical') return first && { ...first, level: t.level }
  const up = ORDER[ORDER.indexOf(t.level) + 1]
  promoted.push(t.id)
  const second = await run(up,
    `${card(t, layer)}

A ${t.level} worker took this task first and stopped short. Its report: ${JSON.stringify(first)}
Its commits stay; build on them.`,
    { label: `${t.id} rerun`, phase: 'Build', schema: BUILT })
  return second && { ...second, level: up, first }
}

phase('Build')
const built = []
const done = new Set()
let pending = [...m.tasks]
while (pending.length) {
  const layer = pending.filter(t => (t.after || []).every(a => done.has(a)))
  if (!layer.length) return stopped('build', 'plan', null, { reason: `no task is ready: ${pending.map(t => t.id).join(', ')}`, built })
  const last = layer.length === pending.length
  const reports = await parallel(layer.map(t => () => build(t, layer, last)))
  layer.forEach((t, i) => built.push({ id: t.id, ...reports[i] }))
  const open = layer.filter((_, i) => stuck(reports[i], last))
  if (open.length) return stopped('build', open[0].id, reports[layer.indexOf(open[0])], { built })
  layer.forEach(t => done.add(t.id))
  pending = pending.filter(t => !layer.includes(t))
}

phase('Review')
const review = await workflow({ scriptPath: `${scripts}/review.workflow.js` }, {
  epic, spec, tree, base, projectBase, levels,
  context: CONTEXT,
  units: m.tasks.map(t => ({ id: t.id, title: t.title, files: t.files, level: t.level })),
})
if (review) ORDER.forEach(l => { used[l] += review.used[l] })
if (!review || review.gate === 'escalate' || review.gate === 'incomplete') return stopped('review', 'review', review, { built })

const fixable = review.findings.filter(f => f.class === 'bug' || f.class === 'quality')
if (!fixable.length && !decisions.fold) return { scaffold, tests, built, review, usage: { used, promoted } }
const foldLevel = highest(fixable.map(f => f.level), 'judgment')

phase('Fold')
const fold = await run(foldLevel,
  `${CONTEXT}

Fold the review's findings into the milestone in one pass:
${JSON.stringify(fixable, null, 2)}

- Fix every bug. Fix a quality finding only when it is small and provably behavior-preserving.
- A finding is a shape, not a line. Search the whole diff (\`git -C ${tree} --no-pager diff ${base}...HEAD\`) for every sibling path with the same shape and fix them all now.
- Read the whole path before editing; the line a finding names is often not the defect.
- Run the milestone's tests and the unit tests of every file you touch.

${SHARED}${decided('fold')}`,
  { label: `${m.id} fold`, phase: 'Fold', schema: REPORT })
if (asked(fold)) return stopped('fold', 'fold', fold, { built, review })

phase('Verify')
const verify = await run(foldLevel,
  `Round 2 of the review gate, for milestone ${m.id} of ${epic}, started cold.
Why the change was made: ${CONTEXT}
The diff: \`git -C ${tree} --no-pager diff ${base}...HEAD\`. The base is ${base}, not main.
Round 1's findings: ${JSON.stringify(review.findings)}
The fix commits: ${fold.commits.join(', ')}. ${fold.notes || ''}
Answer only: is each round-1 finding fixed, and does any fix introduce a new problem. Read the fix commits as new code: they are the least-reviewed lines in the change. Return each finding still open, and each new problem, in findings; gate is fail when any is a bug, escalate when a fix broke something round 1 had passed.

Read only: edit nothing, spawn nothing.`,
  { label: `${m.id} verify`, phase: 'Verify', schema: VERIFY })

return { scaffold, tests, built, review, fold, verify, usage: { used, promoted } }
