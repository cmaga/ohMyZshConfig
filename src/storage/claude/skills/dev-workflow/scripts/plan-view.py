"""Render the milestone build's plan view: templates/plan-view.html filled from the plan and a narrative file.

    python3 plan-view.py <milestones.md> <narrative.json> <out.html>

Every count on the page is computed here from the plan. The narrative carries only
the words a reader needs, in plain English, no ticket or decision codes:

    epic, title, lede               header
    stats: [{n, label}]             extra header figures, after the computed ones
    systems: [{short, name, lines, homes, at}]
                                    homes: path prefixes a task's files must start with
                                    to count as touching it; at: [col, row] in the diagram
    external: [{name, lines, at}]   boxes outside the build, such as the venue
    flows: [{from, to, label, dashed?, bend?}]
                                    from/to name a system's short or an external's name;
                                    arrows run straight, and bend (about -3 to 3) curves
                                    one around a box in its way; labelAt (0-1, default 0.5)
                                    slides a label along its arrow off a crossing
    archTitle?, archNote?, fatesNote?, levelNotes?: {critical, open, pinned}
    retiring?: {name, removedAt}    the old system and the milestone that removes it
    milestones: {"<n>": {short, lead, does, proof, guard?, you?}}
                                    lead: a system short; proof: the proof in plain words
    lessons?: {title?, items: [{then, at, now}]}
                                    only when an earlier attempt failed
    decisions?: {intro, groups: [{name, items: [{tag, text, covers}]}]}
                                    tag: kept (today's behavior), spec (a spec change),
                                    plan (a build-order call) or check (one to look at);
                                    covers: the 1-based numbers of the plan's Decisions
                                    lines the item states. Every line must be covered.
    pauses: {recommended: [n, ...], why}
    todos?: [{when, text}]          what needs the user along the way
    footer?
"""

import html
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'optimize-usage' / 'scripts'))
from levers import resolve
MODEL = {'opus': 'Opus', 'sonnet': 'Sonnet 1M', 'fable': 'Fable', 'haiku': 'Haiku', 'deepseek-flash[1m]': 'DeepSeek Flash 1M'}
LEVELS = ('pinned', 'open', 'critical')
EFFORTS = ('low', 'medium', 'high', 'xhigh', 'max')
FATE_TABLES = ("## Checks today's code performs", '## Behavior in code the build deletes or rewrites')


def sections(text, pattern):
    heads = list(re.finditer(pattern, text, re.M))
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        yield h, text[h.end():end]


def parse_plan(text):
    milestones = []
    for h, body in sections(text, r'^## M-(\d+): (.*)$'):
        body = re.split(r'^## ', body, maxsplit=1, flags=re.M)[0]
        proof = re.search(r'^\*\*Proof:\*\* `([^`]*)`', body, re.M)
        tasks = []
        for th, tbody in sections(body, r'^### (T-\d+\.\d+): (.*)$'):
            files = re.search(r'^- \*\*Files:\*\*(.*?)(?=^- \*\*|\n\n)', tbody, re.M | re.S)
            level = re.search(r'^- \*\*Level:\*\* *(\w+)', tbody, re.M)
            tasks.append({
                'id': th.group(1), 'title': th.group(2).strip(),
                'files': re.findall(r'`([^`]+)`', files.group(1)) if files else [],
                'level': level.group(1) if level else None,
            })
        milestones.append({
            'n': int(h.group(1)), 'title': h.group(2).strip(),
            'pause': bool(re.search(r'^\*\*Pause:\*\* *yes', body, re.M)),
            'test': ' + '.join(Path(p).stem for p in re.findall(r'\S+\.py', proof.group(1))) if proof else '',
            'tasks': tasks,
        })
    return milestones


def parse_fates(text):
    rows = []
    for title in FATE_TABLES:
        start = text.find(title)
        if start < 0:
            continue
        block = re.split(r'^## ', text[start + len(title):], maxsplit=1, flags=re.M)[0]
        for line in block.splitlines():
            cells = [c.strip() for c in re.split(r'(?<!\\)\|', line)[1:-1]]
            if len(cells) < 4 or cells[0] in ('Check', 'Behavior') or set(cells[0]) <= set('-: '):
                continue
            fate = re.match(r'\W*(moved|adapted|retired)', cells[-2], re.I)
            task = re.search(r'T-(\d+)\.\d+', cells[-1]) or re.search(r'M-(\d+)', cells[-1])
            rows.append((fate.group(1).lower() if fate else None, int(task.group(1)) if task else None))
    return rows


def parse_decisions(text):
    start = text.find('## Decisions')
    if start < 0:
        return []
    block = re.split(r'^## ', text[start + len('## Decisions'):], maxsplit=1, flags=re.M)[0]
    return [line for line in block.splitlines() if line.startswith('- [ASSUMED')]


def model(levels, level):
    """What a task at this level runs on: a critical task fills on open, at least at the critical effort."""
    v = levels['open' if level == 'critical' else level]
    effort, floor = v.get('effort'), levels['critical']['effort']
    if level == 'critical' and effort and EFFORTS.index(floor) > EFFORTS.index(effort):
        effort = floor
    return MODEL.get(v['model'], v['model']) + (f' · {effort} effort' if effort else '')


def main(plan_path, narrative_path, out_path):
    text = Path(plan_path).read_text()
    nar = json.loads(Path(narrative_path).read_text())
    levels = json.loads((HERE / 'levels.json').read_text())[resolve()['account']]
    plan = parse_plan(text)
    fates = parse_fates(text)
    recorded = parse_decisions(text)
    errors = []

    shorts = [s['short'] for s in nar['systems']]
    for m in plan:
        w = nar['milestones'].get(str(m['n']))
        if not w or not all(w.get(k) for k in ('short', 'lead', 'does', 'proof')):
            errors.append(f"narrative milestone {m['n']} needs short, lead, does and proof")
        elif w['lead'] not in shorts:
            errors.append(f"milestone {m['n']} lead {w['lead']!r} is not a system short")
        errors += [f"{t['id']} has no level" for t in m['tasks'] if t['level'] not in LEVELS]
    errors += [f"{fate or 'unreadable'} fate row" for fate, _ in fates if fate is None]
    numbers = {m['n'] for m in plan}
    errors += [f'recommended pause M-{n} is not a milestone' for n in nar['pauses']['recommended'] if n not in numbers]
    items = [x for g in (nar.get('decisions') or {}).get('groups', []) for x in g['items']]
    errors += [f"decision tag {x['tag']!r}" for x in items if x['tag'] not in ('kept', 'spec', 'plan', 'check')]
    covered = {n for x in items for n in x.get('covers', [])}
    errors += [f'no decision item covers line {n}: {recorded[n - 1][:90]}' for n in range(1, len(recorded) + 1) if n not in covered]
    errors += [f'decision item covers line {n}, which does not exist' for n in covered if not 1 <= n <= len(recorded)]
    if errors:
        sys.exit('plan-view: ' + '; '.join(sorted(set(errors))))

    milestones = []
    for m in plan:
        w = nar['milestones'][str(m['n'])]
        count = {k: sum(1 for f, n in fates if f == k and n == m['n']) for k in ('moved', 'adapted', 'retired')}
        milestones.append({
            **{k: w.get(k) for k in ('short', 'lead', 'does', 'proof', 'guard', 'you')},
            'n': m['n'], 'test': m['test'], 'tasks': len(m['tasks']),
            'levels': {k[0]: sum(1 for t in m['tasks'] if t['level'] == k) for k in LEVELS},
            'crit': [f"{t['id']} {t['title']}" for t in m['tasks'] if t['level'] == 'critical'],
            'fates': count,
            'touch': {s['short']: sum(1 for t in m['tasks'] if any(f.startswith(tuple(s['homes'])) for f in t['files']))
                      for s in nar['systems']},
        })

    total = {k: sum(1 for f, _ in fates if f == k) for k in ('moved', 'adapted', 'retired')}
    page = {
        **{k: v for k, v in nar.items() if k not in ('milestones', 'stats')},
        'stats': [
            {'n': str(len(plan)), 'label': 'milestones'},
            {'n': str(sum(len(m['tasks']) for m in plan)), 'label': 'worker tasks'},
            *([{'n': f'{len(fates):,}', 'label': "of today's checks and behaviors placed"}] if fates else []),
            *nar.get('stats', []),
        ],
        'milestones': milestones,
        'fates': total,
        'decisionsTotal': len(recorded),
        'levels': {k: model(levels, k) for k in LEVELS},
    }
    data = json.dumps(page, ensure_ascii=False).replace('</', '<\\/')
    out = (HERE.parent / 'templates' / 'plan-view.html').read_text()
    out = out.replace('/*PLAN*/null', data).replace('/*TITLE*/', html.escape(nar['title']))
    Path(out_path).write_text(out)
    print(f"{out_path}: {len(plan)} milestones, {sum(len(m['tasks']) for m in plan)} tasks, {len(fates)} placed rows")


if __name__ == '__main__':
    main(*sys.argv[1:4])
