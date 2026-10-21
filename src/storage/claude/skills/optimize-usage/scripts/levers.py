"""Print one Claude account's lever values from lever-state.json.

    python3 levers.py [account]

The account defaults to this session's: the one whose config_dirs names the directory in
$CLAUDE_CONFIG_DIR (~/.claude when unset). A lever whose value is keyed by account takes that
account's value. Prints {account, levers, agents}: levers maps each lever to its value, and agents
maps each agent type to the opts a dispatch of it passes. inherit and DeepSeek values bind through
the agent's frontmatter, so they pass no opt; [1m] is dropped, since the opt enum lacks it.
"""

import json
import os
import sys
from pathlib import Path

STATE = Path(__file__).resolve().parent.parent / 'lever-state.json'


def account(state):
    name = Path(os.environ.get('CLAUDE_CONFIG_DIR') or Path.home() / '.claude').name
    for key, a in state['accounts'].items():
        if name in a['config_dirs']:
            return key
    sys.exit(f'no account in {STATE} lists {name} in config_dirs')


def resolve(acct=None):
    state = json.loads(STATE.read_text())
    acct = acct or account(state)
    if acct not in state['accounts']:
        sys.exit(f'no account {acct} in {STATE}')
    levers, agents = {}, {}
    for key, lever in state['levers'].items():
        value = lever['value'][acct] if isinstance(lever['value'], dict) else lever['value']
        levers[key] = value
        if value != 'inherit' and not value.startswith('deepseek'):
            for agent in lever.get('agents', []):
                agents.setdefault(agent, {})[lever['opt']] = value.removesuffix('[1m]')
    return {'account': acct, 'levers': levers, 'agents': agents}


if __name__ == '__main__':
    print(json.dumps(resolve(sys.argv[1] if len(sys.argv) > 1 else None), indent=2))
