"""Grade every subagent dispatch in an eval run's transcript against the kitchen's types.

    python3 check-dispatch.py <transcript.jsonl> <levers.py>

Prints ALL PASS or FAIL, then one line per dispatch. A dispatch passes when its description starts
with a type, as in `review(opus/xhigh): ...`, it passes exactly that type's opts from levers.py, and
its agent can run on that type. The other family's fallback, a general-purpose agent, passes on any
Claude model. Agents the roster leaves out are listed, not graded.
"""

import json
import re
import subprocess
import sys

TYPES_OF = {
    'worker-agent': {'code', 'critical_code'},
    'Explore': {'research'},
    'taster-agent': {'review'},
    'comment-sicko-agent': {'review'},
    'deepseek-flash-agent': {'other_family'},
    'general-purpose': {'judgment', 'review', 'general', 'other_family'},
}
OUTSIDE = {'vault-scribe-agent', 'adr-auditor-agent', 'claude-code-guide'}
PREFIX = re.compile(r'([a-z][a-z-]*)\(')


def dispatches(path):
    calls = {}
    with open(path) as f:
        for line in f:
            try:
                message = json.loads(line).get('message')
            except ValueError:
                continue
            content = message.get('content') if isinstance(message, dict) else None
            for block in content if isinstance(content, list) else []:
                if isinstance(block, dict) and block.get('type') == 'tool_use' and block.get('name') in ('Agent', 'Task'):
                    calls[block.get('id')] = block.get('input', {})
    return list(calls.values())


def grade(call, opts):
    agent = call.get('subagent_type', 'general-purpose').split(':')[-1]
    sent = {k: call[k] for k in ('model', 'effort') if k in call}
    if agent in OUTSIDE:
        return None, 'outside the roster'
    m = PREFIX.match(call.get('description', ''))
    kind = m.group(1).replace('-', '_') if m else None
    if kind not in opts:
        return False, 'its description names no type'
    if kind not in TYPES_OF.get(agent, {kind}):
        return False, f'{agent} cannot run on {kind}'
    if kind == 'other_family' and agent == 'general-purpose':
        claude = not sent.get('model', 'deepseek').startswith('deepseek')
        return claude, 'fallback on a Claude model' if claude else 'fallback without a Claude model'
    if sent != opts[kind]:
        return False, f'passed {sent or "no opts"}, {kind} passes {opts[kind] or "none"}'
    return True, ''


def main(transcript, levers):
    run = subprocess.run([sys.executable, levers], capture_output=True, text=True)
    if run.returncode:
        print(f'FAIL\nlevers.py failed: {run.stderr.strip()}')
        return
    opts = json.loads(run.stdout)['opts']
    try:
        calls = dispatches(transcript)
    except OSError as e:
        print(f'FAIL\nno transcript: {e}')
        return
    graded = [(grade(c, opts), c) for c in calls]
    print('FAIL' if any(ok is False for (ok, _), _ in graded) else 'ALL PASS')
    print(f'{len(calls)} dispatches')
    for (ok, why), c in graded:
        mark = {True: 'ok', False: 'WRONG', None: 'skip'}[ok]
        sent = ' '.join(f'{k}={c[k]}' for k in ('model', 'effort') if k in c) or 'no opts'
        agent = c.get('subagent_type', 'general-purpose')
        print(f'{mark}  {c.get("description", "")[:70]} | {agent} | {sent}{" | " + why if why else ""}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
