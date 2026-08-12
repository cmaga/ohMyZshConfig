# Shape

The cheapest gate there is: the structure of the change, drawn before a line of code exists. Correcting placement here costs seconds. Correcting it after the scaffold is written means rewriting the scaffold.

Post it in chat. In `large`, stop and wait for the user — under auto, take your own answer and continue. In `medium`, post it in the same message as the scaffold's first tool call.

In `large`, lead with two lines before the tree: what the change is, and what this structure is for. A tree of real paths is only readable by someone already holding the change ([failure modes](failure-modes.md) states the full four-part frame; a shape needs its first two parts).

## What to draw

1. **A tree** of the files and modules the change involves, each marked `new`, `changed`, or `unchanged (context)`. Real paths.
2. **Arrows** for what calls what across that tree — only the edges this change creates or moves.
3. **Three lines under it**: what is new, what is changed, what is reused.

Plain ASCII. No code, no signatures, no prose paragraphs.

## Answer reuse here

Name the existing symbol each new piece reuses or extends, with its file. "Does something like this already exist" is answerable from a tree, before anything is written — and it is the last cheap moment to answer it.

A new piece with no existing analog is a finding to state, not a silent new pattern.

## Example

```
src/plaid/
  item-service.ts        new      PlaidItemService
  deduplicator.ts        new      TransactionDeduplicator
  sync-orchestrator.ts   changed  now iterates items, was single-item
src/db/
  migrations/            new      items table, dedup_key unique index
  entities/item.ts       new
src/webhooks/
  plaid-handler.ts       changed  routes by item id

sync-orchestrator -> item-service -> deduplicator
plaid-handler -> sync-orchestrator
```

> New: item service, deduplicator, items table.
> Changed: sync orchestrator iterates items; webhook handler routes by item.
> Reused: `TransactionRepository` (`src/db/transaction-repo.ts`), existing retry wrapper in `src/plaid/client.ts`.
