export const meta = {
  name: 'dev-workflow-gather',
  description: "Map each spec component onto today's code, then sweep every file the build deletes or rewrites for behavior no component claims",
  phases: [{ title: 'Gather' }, { title: 'Sweep' }],
}

const { spec, tree, components, levels } = args
if (!levels) throw new Error('pass levels: the contents of scripts/levels.json')

const run = (level, prompt, opts) => {
  const l = levels[level]
  if (!l) throw new Error(`no level named ${level}`)
  return agent(prompt, { ...opts, model: l.model, effort: l.effort, label: `${level}(${l.model}/${l.effort}): ${opts.label}` })
}

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
    leaves: ITEMS({ path: STR, why: STR }, ['path', 'why']),
    questions: { type: 'array', items: STR },
  },
  required: ['component', 'today', 'moves', 'adapts', 'new', 'checks', 'leaves', 'questions'],
}

const FILES = { type: 'object', properties: { files: { type: 'array', items: STR } }, required: ['files'] }

const SWEEP = {
  type: 'object',
  properties: {
    behaviors: ITEMS({ file: STR, behavior: STR, where: STR, claimedBy: STR }, ['file', 'behavior', 'where', 'claimedBy']),
  },
  required: ['behaviors'],
}

const prompt = id => `Read section \`## ${id}:\` of the spec at ${spec}, and the sections its Needs line names. Then find where that responsibility lives in today's code, in the tree at ${tree}.

Report, citing file:line for every claim:
- today: every file that holds this responsibility now, and its role.
- moves: code that can move as-is into the new shape (from, to, what).
- adapts: code that moves but must change where it connects to the new system, and why.
- new: behavior with no home in today's code. Quote the spec sentence that forces it in forcedBy; without one it is not new, it is a move you have not found.
- checks: every check, guard, limit, or gate today's code performs in this area. Each must be kept or retired on purpose, so missing one drops it silently.
- leaves: every file or directory this component deletes or rewrites wholesale once built. Empty when it only adds or edits.
- questions: only observable behavior the spec leaves undecided (what a user or caller would see). How to build it — names, module layout, API shape, where code lives — is the planner's call: never ask it.

Read only: edit nothing, spawn nothing.`

phase('Gather')
const results = await parallel(components.map(id => () =>
  run('judgment', prompt(id), { label: `gather ${id}`, phase: 'Gather', schema: GATHER })))

const missing = components.filter((_, i) => !results[i])
if (missing.length) log(`no result for ${missing.join(', ')}`)
const found = results.filter(Boolean)

const leaving = [...new Set(found.flatMap(r => r.leaves.map(l => l.path)))]
if (!leaving.length) return { results: found, missing, leaving: [], sweep: [] }

phase('Sweep')
const listed = await run('routine',
  `List every tracked file under these paths in the tree at ${tree}, expanding each directory to all its files: \`git -C ${tree} ls-files -- <path>\`. Return paths exactly as git prints them.

${leaving.join('\n')}

Read only: edit nothing, spawn nothing.`,
  { label: 'sweep: list files', phase: 'Sweep', schema: FILES })
const files = listed ? listed.files : []

const claims = JSON.stringify(found.map(r => ({
  component: r.component,
  paths: [...new Set([...r.today.map(t => t.path), ...r.moves.map(m => m.from), ...r.adapts.map(a => a.where)])],
})))

const CHUNK = 15
const chunks = []
for (let i = 0; i < files.length; i += CHUNK) chunks.push(files.slice(i, i + CHUNK))

const swept = await parallel(chunks.map((chunk, i) => () => run('routine',
  `The build deletes or rewrites these files, in the tree at ${tree}. Behavior in them that no spec component carries forward disappears silently.

${chunk.join('\n')}

Read each file whole. List every behavior it implements that a user, a caller, or an operator would notice — a check, guard, limit, alert, job, command, decision rule, or data write something else reads; not helper functions. For each, set claimedBy to the component whose gather covers it, or "unclaimed". Decide by what the behavior does, not by path alone: a component whose spec section does not carry the behavior does not claim it. Cite file:line in where.

Spec: ${spec}. What each component's gather covers: ${claims}

Read only: edit nothing, spawn nothing.`,
  { label: `sweep ${i + 1}/${chunks.length}`, phase: 'Sweep', schema: SWEEP })))

const lost = chunks.filter((_, i) => !swept[i]).flat()
if (lost.length) log(`sweep returned nothing for ${lost.length} files: ${lost.join(', ')}`)
const sweep = swept.filter(Boolean).flatMap(s => s.behaviors)
log(`${files.length} leaving files, ${sweep.length} behaviors, ${sweep.filter(b => b.claimedBy === 'unclaimed').length} unclaimed`)
return { results: found, missing, leaving: files, unswept: lost, sweep }
