"""Print one Claude account's levers and types from lever-state.json.

    python3 levers.py [account]

The account defaults to this session's: the one whose config_dirs names the directory in
$CLAUDE_CONFIG_DIR (~/.claude when unset), and whose env, when it has one, matches the
environment. An account with a matching env wins, since hosts share config dir names.
$KITCHEN_ACCOUNT, when set, names it instead: an eval run sets it, since its config dir is a
temporary one. Prints
{account, levers, types, opts}: levers maps each session-wide lever to its value, types maps each
type to the model and effort it is set to, and opts maps each type to the opts a dispatch of it
passes. inherit and DeepSeek values bind through the agent's frontmatter, so they pass no opt;
[1m] is dropped, since the opt enum lacks it.
"""

import json
import os
import sys
from pathlib import Path

STATE = Path(__file__).resolve().parent.parent / 'lever-state.json'
OPTS = ('model', 'effort')


def account_of(state, config_dir):
    matches = [key for key, a in state['accounts'].items()
               if config_dir.name in a['config_dirs']
               and all(os.environ.get(k) == v for k, v in a.get('env', {}).items())]
    if not matches:
        sys.exit(f'no account in {STATE} lists {config_dir.name} in config_dirs')
    return max(matches, key=lambda key: len(state['accounts'][key].get('env', {})))


def account(state):
    return os.environ.get('KITCHEN_ACCOUNT') or account_of(state, Path(os.environ.get('CLAUDE_CONFIG_DIR') or Path.home() / '.claude'))


def resolve(acct=None):
    state = json.loads(STATE.read_text())
    acct = acct or account(state)
    if acct not in state['accounts']:
        sys.exit(f'no account {acct} in {STATE}')
    levers = {key: lever['value'][acct] if isinstance(lever['value'], dict) else lever['value']
              for key, lever in state['levers'].items()}
    types = {name: {opt: t[opt][acct] for opt in OPTS if opt in t} for name, t in state['types'].items()}
    opts = {name: {opt: value.removesuffix('[1m]') for opt, value in values.items()
                   if value != 'inherit' and not value.startswith('deepseek')}
            for name, values in types.items()}
    return {'account': acct, 'levers': levers, 'types': types, 'opts': opts}


if __name__ == '__main__':
    print(json.dumps(resolve(sys.argv[1] if len(sys.argv) > 1 else None), indent=2))
