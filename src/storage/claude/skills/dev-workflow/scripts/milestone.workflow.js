export const meta = {
  name: 'dev-workflow-milestone',
  description: 'Build one milestone of an ultra spec: scaffold, failing tests, workers, one review, one fold, one verify',
  phases: [
    { title: 'Scaffold' },
    { title: 'Tests' },
    { title: 'Build' },
    { title: 'Review' },
    { title: 'Fold' },
    { title: 'Verify' },
  ],
}

const { epic, spec, tree, base, milestone: m, decisions = {} } = args

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
const REVIEW = {
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
const stopped = (stage, key, report, rest) => ({ stopped: stage, key, report, ...rest })
const asked = r => !r || r.status === 'question'

phase('Scaffold')
const scaffold = await agent(
  `${CONTEXT}

You are this milestone's scaffold. Make the moves first, one commit per move. Then create every new file, signature, type, and schema the tasks below fill, with bodies that raise NotImplementedError or the language's equivalent. Write no behavior.

${m.scaffold}

Tasks that fill it:
${m.tasks.map(t => `- ${t.id}: ${t.title} (${t.files.join(', ')})`).join('\n')}

${SHARED}${decided('scaffold')}`,
  { agentType: 'worker-agent', label: `${m.id} scaffold`, phase: 'Scaffold', schema: REPORT })
if (asked(scaffold)) return stopped('scaffold', 'scaffold', scaffold)

phase('Tests')
const tests = await agent(
  `${CONTEXT}

Write the failing integration tests that prove this milestone, against the scaffold now committed. ${m.tests}
List each test path in files, and put its failing output in notes.

${SHARED}${decided('tests')}`,
  { agentType: 'tester-agent', label: `${m.id} tests`, phase: 'Tests', schema: REPORT })
if (asked(tests)) return stopped('tests', 'tests', tests, { scaffold })

const card = (t, layer) => `${CONTEXT}

Task ${t.id}: ${t.title}
Files you own: ${t.files.join(', ')}

${t.card}

The milestone's failing tests: ${tests.files.join(', ')}. Make the ones your task covers pass. Run them and the unit tests of your files.
Running beside you: ${layer.filter(s => s.id !== t.id).map(s => `${s.id} (${s.files.join(', ')})`).join('; ') || 'nobody'}.

${SHARED}${decided(t.id)}`

phase('Build')
const built = []
const done = new Set()
let pending = [...m.tasks]
while (pending.length) {
  const layer = pending.filter(t => (t.after || []).every(a => done.has(a)))
  if (!layer.length) return stopped('build', 'plan', null, { reason: `no task is ready: ${pending.map(t => t.id).join(', ')}`, built })
  const reports = await parallel(layer.map(t => () =>
    agent(card(t, layer), { agentType: 'worker-agent', label: t.id, phase: 'Build', schema: REPORT })))
  layer.forEach((t, i) => built.push({ id: t.id, ...reports[i] }))
  const open = layer.filter((_, i) => asked(reports[i]))
  if (open.length) return stopped('build', open[0].id, reports[layer.indexOf(open[0])], { built })
  layer.forEach(t => done.add(t.id))
  pending = pending.filter(t => !layer.includes(t))
}

phase('Review')
const review = await agent(
  `Round 1 of the review gate, for milestone ${m.id} of ${epic}.
Why the change was made: ${CONTEXT}
The diff: \`git -C ${tree} --no-pager diff ${base}...HEAD\`. The base is ${base}, not main.`,
  { agentType: 'code-review-agent', label: `${m.id} review`, phase: 'Review', schema: REVIEW })
if (!review || review.gate === 'escalate') return stopped('review', 'review', review, { built })

const fixable = review.findings.filter(f => f.class === 'bug' || f.class === 'quality')
if (!fixable.length && !decisions.fold) return { scaffold, tests, built, review }

phase('Fold')
const fold = await agent(
  `${CONTEXT}

Fold the review's findings into the milestone in one pass:
${JSON.stringify(fixable, null, 2)}

- Fix every bug. Fix a quality finding only when it is small and provably behavior-preserving.
- A finding is a shape, not a line. Search the whole diff (\`git -C ${tree} --no-pager diff ${base}...HEAD\`) for every sibling path with the same shape and fix them all now.
- Read the whole path before editing; the line a finding names is often not the defect.
- Run the milestone's tests and the unit tests of every file you touch.

${SHARED}${decided('fold')}`,
  { agentType: 'worker-agent', label: `${m.id} fold`, phase: 'Fold', schema: REPORT })
if (asked(fold)) return stopped('fold', 'fold', fold, { built, review })

phase('Verify')
const verify = await agent(
  `Round 2 of the review gate, for milestone ${m.id} of ${epic}, started cold.
Why the change was made: ${CONTEXT}
The diff: \`git -C ${tree} --no-pager diff ${base}...HEAD\`. The base is ${base}, not main.
Round 1's findings: ${JSON.stringify(review.findings)}
The fix commits: ${fold.commits.join(', ')}. ${fold.notes || ''}
Answer only: is each round-1 finding fixed, and does any fix introduce a new problem.`,
  { agentType: 'code-review-agent', label: `${m.id} verify`, phase: 'Verify', schema: REVIEW })

return { scaffold, tests, built, review, fold, verify }
