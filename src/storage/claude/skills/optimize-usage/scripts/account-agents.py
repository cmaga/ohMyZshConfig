"""Give one Claude account's config dir agents that carry that account's lever values.

    python3 account-agents.py <config dir> <agents dir>

The agents dir holds the deployed agents, whose frontmatter carries personal's values. The config
dir's account comes from the config_dirs in lever-state.json. When every agent already carries
that account's values, <config dir>/agents links to the agents dir whole. Otherwise it becomes a
directory of links back to each agent, with a copy in place of each agent whose values differ.
"""

import json
import shutil
import sys
from pathlib import Path

from levers import STATE

MARKER = '.per-account'


def account_of(state, config_dir):
    for key, account in state['accounts'].items():
        if config_dir.name in account['config_dirs']:
            return key
    sys.exit(f'no account in {STATE} lists {config_dir.name} in config_dirs')


def frontmatter_values(state, account):
    """Map each agent to {key: value}; None drops the key, so the agent inherits it."""
    values = {}
    for lever in state['levers'].values():
        if 'agents' not in lever or not isinstance(lever['value'], dict):
            continue
        value = lever['value'][account]
        for agent in lever['agents']:
            values.setdefault(agent, {})[lever['opt']] = None if value == 'inherit' else value
    return values


def render(text, values):
    lines = text.split('\n')
    end = lines.index('---', 1)
    head = lines[1:end]
    for key, value in values.items():
        at = next((i for i, line in enumerate(head) if line.startswith(f'{key}:')), None)
        if value is None:
            if at is not None:
                del head[at]
        elif at is None:
            head.append(f'{key}: {value}')
        else:
            head[at] = f'{key}: {value}'
    return '\n'.join([lines[0], *head, *lines[end:]])


def main(config_dir, agents):
    state = json.loads(STATE.read_text())
    values = frontmatter_values(state, account_of(state, config_dir))
    copies = {}
    for agent in agents.glob('*.md'):
        text = agent.read_text()
        rendered = render(text, values.get(agent.stem, {}))
        if rendered != text:
            copies[agent.name] = rendered

    dest = config_dir / 'agents'
    if dest.is_symlink():
        dest.unlink()
    elif dest.is_dir():
        if not (dest / MARKER).exists():
            sys.exit(f'{dest} is neither a link nor a per-account build, left as is')
        shutil.rmtree(dest)

    if not copies:
        dest.symlink_to(agents, target_is_directory=True)
        return
    dest.mkdir()
    (dest / MARKER).write_text('Built by account-agents.py on every deploy; edits here are lost.\n')
    for agent in agents.glob('*.md'):
        if agent.name in copies:
            (dest / agent.name).write_text(copies[agent.name])
        else:
            (dest / agent.name).symlink_to(agent)
    print(f'{dest}: own copies of {", ".join(sorted(copies))}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(Path(sys.argv[1]).expanduser(), Path(sys.argv[2]).expanduser())
