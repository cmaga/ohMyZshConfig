---
name: standup
description: Summarize the user's recent git activity on the current repo as a one-paragraph standup update.
disable-model-invocation: true
---

# Standup

Analyze all the changes the user has made since the last standup on the current repo and give them a quick paragraph for standup.

Standups are Monday–Friday at 1pm local time. "Since the last standup" means:

- Tuesday–Friday: since 1pm yesterday
- Monday: since 1pm Friday
- Saturday/Sunday: since 1pm Friday

Output: a single paragraph suitable for reading aloud. Focus on what was done; mention blockers or in-progress work only if evident.
