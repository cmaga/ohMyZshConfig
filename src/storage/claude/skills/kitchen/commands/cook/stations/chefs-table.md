# The chef's table

Once an order's design exists, put the calls that are the user's to them before any test or code is written against it. A call made alone reaches the user at review, after the code is built on it, and overturning it there costs a rebuild.

Every recipe that ships code runs this station after its design step. A `manual` order skips it, since the user makes each call as they write. A `catering` order and its deployments make their calls in the plan, and use only [A piece with no precedent](#a-piece-with-no-precedent), for a deployment's skeleton.

## Which calls are the user's

A call is something the design changes or adds. Leaving a thing as it is, or declining work outside the order's intent, is not one. A change to something the ticket says to keep is not one either: it goes the [design route](../../../SKILL.md#autonomy). Anything else the design changes to reach the intent is a call, however far it reaches.

Classify each call first, per [SKILL.md](../../../SKILL.md#non-negotiables): one that a run, a read, or the repo's own precedent can settle is settled that way. Of the rest, a call is the user's when a mistake in it would be costly, no check would catch it, and it is one of these:

- **Stored or wire data**: the shape of a table, a migration, a message, or a file another process reads.
- **An interface another part uses**: an endpoint, a public signature, a config key, the contract between two systems.
- **How it fails**: what happens on an error, a timeout, or missing input, and what a safety check allows or refuses.
- **What a person sees or must do**: a page, an alert, wording, a default, a runbook step.
- **A piece with no precedent**: a module, layout, or pattern the repo lacks, which later code will copy.

Every other call is yours. Decide it and log it before you send the list: `kitchen.zsh decide <KEY> "<decision>: <why>" "<the file:line, run, or source behind it>"`. A design with no call of the user's proceeds without a word to them. A call already recorded in the order's `decisions` is settled: never ask it twice.

## Put them to the user

Send one message that lists every call that is theirs, then stop. Give each call two or three plain lines:

- the call as a question, and what depends on the answer;
- the options you weighed;
- your recommendation and why, citing a `file:line`, a run, or a source where one exists.

> **1. Should a failed export keep its partial file?** Keeping it lets a large export resume; deleting it means no reader ever opens half a file. I recommend deleting it: nothing reads a partial file today, and resuming would need a design of its own.

A piece with no precedent is one call on the list: what the piece is, and that the repo has no pattern for it. Its parts follow once the list is settled.

End the message with one line naming any calls you settled yourself, so the user can take one back.

The user approves the list, or names the calls to change or discuss. Take those one at a time. What they decide binds every later session on the order.

When the user has said they will not answer ("go with your recommendation", "I can't answer today"), do not stop: send the list with what you chose, log each call with plain `kitchen.zsh decide`, flag the PR as for any call made alone ([Autonomy](../../../SKILL.md#autonomy)), and carry on.

## A piece with no precedent

The user reads it as it is written, never as a finished draft:

1. Show the layout: each new file and directory, and what it holds.
2. Show the types and signatures, one module per message, bodies not implemented.
3. After each part, wait for the user's word and apply their changes before the next.

The contract author commits the scaffold as agreed ([contract](contract.md)).

## Record each call the user made

Once a call is answered, or a piece's last part is agreed:

`kitchen.zsh decide <KEY> "<the call>: <what the user chose, and their reason when they gave one>" "<what you recommended>" --chef <kept|changed>`

`kept` when they took your recommendation; `changed` when they chose otherwise or altered any part of a piece. With no order, list the calls in your reply.

## When the user is not here

A headless session never decides a call of the user's and never builds past one:

1. Stop any worker whose code depends on the call, and commit anything uncommitted on the branch: `wip: design sketch`, or `wip: <step>` when code is already written.
2. Write the message from [Put them to the user](#put-them-to-the-user) to a file.
3. Run `kitchen.zsh order set <KEY> status=ready pid=0 stage=calls calls=@<file> "question=waiting on your calls: <n>"`, and end the session.

The order then waits in `/kitchen status` until the user takes it, and it keeps its mode. The session they take it in:

1. Sends the order's `calls`, and shows any piece with no precedent part by part.
2. Records each answer.
3. Runs `kitchen.zsh order set <KEY> status=ready pid=0 stage= question=`, tells the user the scheduler builds the rest, and ends.

The session the scheduler starts next brings the design in line with the answers in the order's `decisions` before it writes a test or code. A locked test an answer makes wrong goes back to the contract author ([contract](contract.md)).

## A call that comes up later

A call of these kinds that first appears while the code is being written goes the same way, before any code is built on it. One a review turns up once the code exists goes the [design route](../../../SKILL.md#autonomy).
