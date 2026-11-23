# Intake: turn a ticket into an order

## Description

A raw ticket is often a placeholder: stale, a duplicate, low value, or written wrong. The following is the guided intake process used to convert a ticket into an executable order. The steps in the process marked [DISCUSSION] happen with the user, and steps that are not, you go through on your own.

## Intake Rules

- Do not allow ambiguity: When anything you need is missing or uncertain, ask and investigate rather than guess. Intake is when those kinds of mistakes are most expensive.
- You can recommend a ticket be dropped but it is **ALWAYS** the users call, not yours.

## Process Steps

1.  **Pre-requisites**: If an intake stops before finishing the order is where the earlier intake left what it had settled. Run `kitchen.zsh order get <KEY>` to load it. On a fresh ticket the order is empty, so go on to step 2. When the order has a `last_session`, read that session's conversation yourself: `kitchen.zsh order transcript <KEY> --conversation` (prints only what the user and the session said). From it, learn:
    - where each part of the `answer` came from: what the user was shown, what they decided, and why
    - why the session stopped, and whether this skill's text caused it. If the skill's text caused the stop, handle it per [SKILL.md](../../SKILL.md#defects-and-lessons).

    On a workspace line, read the type's doc now (`kitchen.zsh workspace` prints its path). It adds to steps 2 to 7: the fields the order carries, how you pick them, and how `station` paths read.

2.  **Gather Context** Read the ticket with the `ticket-provider` skill.

- Grab all possible information associated with the ticket: summary, description, every comment, links, status, assignee, and attachments. Capture the reporter's words, the expected and observed behavior, version and environment, frequency and trigger, error text, links to existing PRs or commits, and any statement that someone is already on it. Read screenshots and logs; when one cannot be read, say so rather than guess what it shows. If you can't access external links stop an ask the user, to paste it for you.
- Verify the ticket is not blocked by another ticket, or marked as such. If it is, stop and report this to the user.
- Verify no one else has started the ticket using the `git-provider` skill, and forgot to update the ticket.

3.  **Check it is still worth doing.** Search open tickets through the `ticket-provider` skill by error text, area, trigger, and symptom, and read the code and recent history far enough to tell whether the ticket still applies. Each of these is a drop you recommend, per the intake rules; a check that passes is never mentioned.
    - **Duplicate**: the same signature, or the same area, trigger, and symptom, or a confirmed shared cause. On the user's word, comment the link on both tickets, run `kitchen.zsh order set <KEY> status=86 "reason=duplicate of <OTHER>"`, and stop. A possible relation goes into the summary as uncertain. A long-closed match is a regression lead, not a duplicate.
    - **Stale**: already fixed, or no longer applies. On the user's word, comment the evidence on the ticket, move it with the `merged` moment through the `ticket-provider` skill, run `kitchen.zsh order set <KEY> status=86 reason=@<file>`, and stop.
    - **Low value**: real, but not worth the time now. On the user's word, leave the ticket open, comment why, run `kitchen.zsh order set <KEY> status=86 reason=@<file>`, and stop. The user can bring it back from `/kitchen status`.

4.  [DISCUSSION] **Agree the scope.** Send the ticket's link, then what it is about and the intent behind it: the goal and the problem it solves, without the ticket's implementation nouns, which are guesses about the solution. Mention a check from steps 2 and 3 only when it failed.
    - The user steers: the fix may sit a level deeper than the ticket says, or the ticket may ask for the wrong thing. Discuss until you agree on the scope.
    - When the agreed scope differs from the ticket, rewrite its description to match, and comment what changed and why.

5.  **Pick the recipe and write the done-when**, once the scope is agreed. The recipe's own steps find the approach, so intake researches none.
    - The recipe is the one from the list in [SKILL.md](../../SKILL.md#recipes) whose line fits the agreed scope, not the ticket's label. A ticket that bundles separable changes gets `multi-phase-plan`. A new system, a new design, or a large refactor whose target design is unsettled gets `catering`. None fits: `bespoke`, with the order's own `steps` designed per the [figure it out](../cook/stations/figure-it-out.md) station, each ending in a check and none waiting on the user: a step's measured result decides what comes next.
    - Each done-when line is a check that could fail: a command, a test, or a drive of the app that fails on the base branch today and passes once the order is done. "The settings page loads with no error, and errors today" qualifies; "works well" does not. A ticket filed from a multi-phase plan carries Verify blocks: they become the done-when as written. A `catering` order takes none.

6.  [DISCUSSION] **Recipe, mode, and review.** Send the recipe, the mode, and whether the PR waits for the user's review, each with its reason, and, for `bespoke`, the steps. The Intake defaults section of the project rules (`.claude/kitchen/house.md`) goes first and wins.
    - `mode`: recommend it per [mode](mode.md).
    - `review=true` when any done-when line is something only the user can judge: look and feel, wording users read, how a flow feels. A manual order always waits for the user whatever the flag says. A PR is finished code with no question on it, so a call only the user can make is asked now, never left for the PR.
    - `catering` takes no mode or review flag: send the recipe and why. On the user's go, write the order with `kitchen.zsh order set <KEY> status=ready recipe=catering summary=@<file> intent=@<file>` and carry on in this session from [cook](../cook/cook.md#before-starting).
    - The user steers. Move on once they agree.

7.  **Write the order** in one command. First write each text field to its own file with the Write tool, the list fields (`done_when`, `station`, `steps`) as JSON arrays. `intent` is the agreed scope. `station` lists the files and directories you expect the order to touch; the scheduler never runs two orders whose stations overlap.

        kitchen.zsh order set <KEY> status=ready recipe=<recipe> \
          mode=<manual|co-write|guided|auto> review=<true|false> review_why=@<file> \
          answer=@<file> summary=@<file> intent=@<file> done_when=@<file> \
          station=@<file> steps=@<file>

    `steps` only for `bespoke`; `review_why` only with `review=true`. `answer` holds what the user agreed to: the scope, the recipe, the mode, and the review, which binds the working session. The summary carries what intake found in a few lines, hypotheses labeled as such. Then tell them where the order waits: an `auto` order goes to the scheduler, which starts it on a pass when its files are free. A `manual` or `guided` order waits for `/kitchen next <mode>`, or for `take <KEY>` again, and nothing starts it until they do.

## Talking to the user

Each [DISCUSSION] step is one message, and it moves on only on the user's word.

- Write a few plain sentences: no headings, bold, lists, or tables, and no file, table, or function names or numbers unless the step needs them.
- Say nothing about intake itself, the checks that passed, or the calls you will make yourself.
- State what the user already decided, in this intake or an earlier one, and ask only about what is still open.
- Answer a question they ask inside the step it comes up in. A question about why the system works as it does gets the code or vault line behind it.
- End each message with one question, and end your turn.
