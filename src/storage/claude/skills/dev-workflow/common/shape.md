# Shape

The cheapest gate there is: the structure of the change, drawn before a line of code exists. Correcting placement here costs seconds. Correcting it after the scaffold is written means rewriting the scaffold.

Post it in chat. In `large`, stop and wait for the user — unattended, take your own answer and continue. In `medium`, post it in the same message as the scaffold's first tool call.

In `large`, lead with two lines before the tree: what the change is, and what this structure is for. A tree of real paths is only readable by someone already holding the change ([edge cases](edge-cases.md) states the full four-part frame; a shape needs its first two parts).

## What to draw

1. **A tree** — an ASCII tree with `├──` / `└──` / `│` connectors, the way `tree` prints one. Real paths.
2. **Arrows** for what calls what across that tree — only the edges this change creates or moves.
3. **Three lines under it**: what is new, what is changed, what is reused.

Plain ASCII. No code, no signatures, no prose paragraphs.

### The tree shows the layout after the change, not the diff

Every directory the change touches is drawn complete — the files already in it included, unannotated. Only the ones this change adds or edits carry an annotation (`new` or `changed`, plus the symbol or a short note).

This is what makes the tree worth reading: a new file in the wrong place is only visible next to the neighbours it was supposed to sit with. A tree of just the changed paths cannot show that.

Bound it to the directories the change touches. Never the whole repo.

## Answer reuse here

Name the existing symbol each new piece reuses or extends, with its file. "Does something like this already exist" is answerable from a tree, before anything is written — and it is the last cheap moment to answer it.

A new piece with no existing analog is a finding to state, not a silent new pattern.

## Example

```
src/
├── db/
│   ├── entities/
│   │   ├── item.ts               new      Item
│   │   └── transaction.ts
│   ├── migrations/
│   │   ├── 0007_accounts.sql
│   │   └── 0008_items.sql        new      items table, dedup_key unique index
│   └── transaction-repo.ts
├── plaid/
│   ├── client.ts
│   ├── deduplicator.ts           new      TransactionDeduplicator
│   ├── item-service.ts           new      PlaidItemService
│   ├── sync-orchestrator.ts      changed  iterates items, was single-item
│   └── types.ts
└── webhooks/
    ├── plaid-handler.ts          changed  routes by item id
    └── stripe-handler.ts

sync-orchestrator -> item-service -> deduplicator
plaid-handler -> sync-orchestrator
```

> New: item service, deduplicator, items table.
> Changed: sync orchestrator iterates items; webhook handler routes by item.
> Reused: `TransactionRepository` (`src/db/transaction-repo.ts`), existing retry wrapper in `src/plaid/client.ts`.
