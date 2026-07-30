---
name: walkthrough
description: Guided tour of one part of a system. Opens the code in VSCode, briefs the problem before the solution, collaborates on how the user would have designed it, then drops them at the entrypoint and follows their questions component by component.
disable-model-invocation: true
---

# Walkthrough

Get the user oriented, get them to the right line of code, then stay out of the way. Explain as little as possible — the entrypoint teaches, you don't. Once they have the problem and the shape of the solution, they will find the right questions on their own.

## Rules that shape every step

- Show code, never a paraphrase of it. If opening a file answers the question, open the file and let them read it.
- Never preview a component before they reach it, and never offer to summarize what remains.
- The brief covers the problem. Nothing about the implementation reaches them before step 4.

## Workflow

1. **Open the code.** The target is the worktree for the thing under study, or the primary repo root on whatever branch it is on — do not switch branches. Run `code <dir>` once; every later jump reuses that window.
2. **Brief the problem.** Why this part of the system exists, what it has to accomplish, what constrained it. Pull the ticket via the `jira` skill and the PR via `git-provider` when the target has them, plus vault notes for the touched components. Keep it to what a colleague would say before opening a laptop. Say nothing about how it was built.
3. **Ask how they would have solved it.** Then genuinely discuss it — this is a design conversation between two engineers, not a quiz. Their approach may be better than what shipped. Say so when it is, name the tradeoff when it isn't, and follow the tangents: an idea worth building is a good outcome here. Capture anything worth acting on and hand it back at exit.
4. **Sketch the solution's shape.** One level deep: the approach taken and why, not the code. Then identify the components they should see and open one task per component with `TaskCreate`, ordered the way execution flows — subject is the component, description is its file path and one line on its role. The task list is the itinerary; it is the only thing keeping a free-form tour from dropping components.
5. **Drop them at the entrypoint.** Mark the first component `in_progress`, `code -g <file>:<line>`, one sentence on what they are looking at, then stop talking and wait.
6. **Follow their questions.** They drive. Answer at the minimum depth that unblocks them and point at the code that proves it. External lookups — library APIs, language semantics, framework behavior — answer immediately and completely; that part is worth automating. Questions about the code in front of them get an open file, not an essay. Before leaving a component, fold what the discussion settled into its task description — what they asked, what the code turned out to do.
7. **`next` moves on.** Complete the current task, mark the next `in_progress`, open it with `code -g <file>:<line>`, and repeat step 6. They can skip ahead or double back by naming a component. Anything the tour uncovers that they should also see becomes a new task on the spot.
8. **`exit` ends it.** Read `TaskList` and report what they covered, what is still pending, and anything from step 3 worth acting on. Tasks are session state — nothing on disk, nothing to resume.

## If they want to change something

Do not edit the tour. Confirm a branch name, then `git worktree add ../$(basename "$PWD")-<slug> -b <slug>`, run `code <new-dir>`, and continue the walkthrough there. The change is theirs to make.

## Keep it short

A walkthrough is one sitting over a handful of components. When their questions dry up, offer to end it rather than marching through the remaining itinerary — an unvisited component beats a tour they stopped following.
