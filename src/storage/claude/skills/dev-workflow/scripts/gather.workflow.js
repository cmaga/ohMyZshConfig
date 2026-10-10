export const meta = {
  name: 'dev-workflow-gather',
  description: "Map each spec component onto today's code: what moves, adapts, is new, and every check it must keep",
  phases: [{ title: 'Gather' }],
}

const { spec, tree, components, model } = args

const ITEMS = (props, required) => ({
  type: 'array',
  items: { type: 'object', properties: props, required },
})
const STR = { type: 'string' }

const GATHER = {
  type: 'object',
  properties: {
    component: STR,
    today: ITEMS({ path: STR, role: STR }, ['path', 'role']),
    moves: ITEMS({ from: STR, to: STR, what: STR }, ['from', 'what']),
    adapts: ITEMS({ where: STR, change: STR, reason: STR }, ['where', 'change', 'reason']),
    new: ITEMS({ what: STR, forcedBy: STR }, ['what', 'forcedBy']),
    checks: ITEMS({ what: STR, where: STR }, ['what', 'where']),
    questions: { type: 'array', items: STR },
  },
  required: ['component', 'today', 'moves', 'adapts', 'new', 'checks', 'questions'],
}

const prompt = id => `Read section \`## ${id}:\` of the spec at ${spec}, and the sections its Needs line names. Then find where that responsibility lives in today's code, in the tree at ${tree}.

Report, citing file:line for every claim:
- today: every file that holds this responsibility now, and its role.
- moves: code that can move as-is into the new shape (from, to, what).
- adapts: code that moves but must change where it connects to the new system, and why.
- new: behavior with no home in today's code. Quote the spec sentence that forces it in forcedBy; without one it is not new, it is a move you have not found.
- checks: every check, guard, limit, or gate today's code performs in this area. Each must be kept or retired on purpose, so missing one drops it silently.
- questions: what the spec leaves undecided that the build needs answered.

Read only: edit nothing, spawn nothing.`

phase('Gather')
const results = await parallel(components.map(id => () =>
  agent(prompt(id), { label: `gather ${id}`, phase: 'Gather', schema: GATHER, ...(model ? { model } : {}) })))

const missing = components.filter((_, i) => !results[i])
if (missing.length) log(`no result for ${missing.join(', ')}`)
return { results: results.filter(Boolean), missing }
