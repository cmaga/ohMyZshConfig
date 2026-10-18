"""Render the milestone build's plan view: templates/plan-view.html filled from the plan,
a narrative file and the spec.

    python3 plan-view.py <milestones.md> <narrative.json> <spec> <out.html>

Every count on the page is computed here from the plan. Every M-N section of the plan
needs a **Touches:** line naming the spec's part ids that milestone changes (C-2, X-1).

When <spec> is an HTML page holding an <svg data-diagram="containers">, the page reuses
that diagram: once in full under The target, then on every milestone card with the
parts on its Touches line lit and every other data-part dimmed. The spec's <style>
comes along scoped: its custom properties are renamed --spec-* and stay on :root, so
the spec's own light and dark blocks still switch them, and every other rule applies
only inside the diagram copies. Every Touches id must then be a data-part in that
diagram. Without one (an older markdown spec), the page draws its own diagram from
systems, external and flows, as before.

The narrative carries only the words a reader needs, in plain English, no ticket or
decision codes:

    epic, title, lede               header
    stats: [{n, label}]             extra header figures, after the computed ones
    systems, external, flows        the page's own diagram. systems is required when the
                                    spec has no container diagram; all three are optional
                                    when it has one, and systems given then still fill the
                                    matrix with task counts (without them, the matrix
                                    marks the parts each Touches line names)
    systems: [{short, name, lines, homes, at}]
                                    homes: path prefixes a task's files must start with
                                    to count as touching it; at: [col, row] in the diagram
    external: [{name, lines, at}]   boxes outside the build, such as the venue
    flows: [{from, to, label, dashed?, bend?, labelAt?}]
                                    from/to name a system's short or an external's name;
                                    arrows run straight, and bend (about -3 to 3) curves
                                    one around a box in its way; labelAt (0-1, default 0.5)
                                    slides a label along its arrow off a crossing
    archTitle?, archNote?, fatesNote?, levelNotes?: {critical, open, pinned}
    retiring?: {name, removedAt}    the old system and the milestone that removes it
    milestones: {"<n>": {short, lead, does, proof, undo, guard?, you?}}
                                    lead: a part id on the milestone's Touches line when
                                    the spec has a container diagram, else a system short;
                                    proof: the proof in plain words; undo: what undoing
                                    this milestone would cost, in plain words
    lessons?: {title?, items: [{then, at, now}]}
                                    only when an earlier attempt failed
    decisions?: {intro, groups: [{name, items: [{tag, text, why?, rejected?, covers}]}]}
                                    tag: kept (today's behavior), spec (a spec change),
                                    plan (a build-order call) or check (one to look at);
                                    why: the reason for the call; rejected: what it was
                                    chosen over. When any item has either, every item
                                    reads as decision / why / rejected.
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
SCOPE = '.specd'
DIAGRAM = re.compile(r'''<svg\b(?:[^>"']|"[^"]*"|'[^']*')*?\sdata-diagram\s*=\s*["']containers["'].*?</svg>''', re.S | re.I)
ROOT = re.compile(r'(:root(?:\[[^\]]*\]|:not\([^)]*\))*)\s*(.*)', re.S)


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
        touches = re.search(r'^\*\*Touches:\*\*(.*?)(?=\n\s*\n|\n\*\*|\Z)', body, re.M | re.S)
        tasks = []
        for th, tbody in sections(body, r'^### (T-\d+\.\d+[a-z]?): (.*)$'):
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
            'touches': list(dict.fromkeys(re.findall(r'\b[A-Za-z]+-\d+\b', touches.group(1)))) if touches else [],
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


def scope_css(css):
    """The spec's CSS made safe to share the plan page: custom properties renamed --spec-*
    and kept on :root (only them, so the page's own root is untouched), every other rule
    confined to SCOPE."""
    css = re.sub(r'/\*.*?\*/|@(?:import|charset|namespace)[^;]*;', '', css, flags=re.S)
    out = []
    for head, body in re.findall(r'([^{}]+)\{((?:[^{}]|\{[^{}]*\})*)\}', css):
        head = head.strip()
        if head.startswith('@'):
            if head.startswith(('@media', '@supports')):
                out.append(head + '{' + scope_css(body) + '}')
            continue
        body = re.sub(r'(?<![\w-])--(?=[\w-])', '--spec-', body)
        root, inner = [], []
        for sel in filter(None, (s.strip() for s in re.split(r',(?![^(]*\))', head))):
            m = ROOT.fullmatch(sel)
            if m and not m.group(2):
                root.append(m.group(1))
            else:
                inner.append(f'{m.group(1)} {SCOPE} {m.group(2)}' if m else f'{SCOPE} {sel}')
        if root:
            out.append(','.join(root) + '{' + ';'.join(d for d in body.split(';') if d.strip().startswith('--')) + '}')
        if inner:
            out.append(','.join(inner) + '{' + body + '}')
    return '\n'.join(out)


def spec_diagram(path):
    """The spec's container diagram, its scoped CSS and its part ids, or None when the spec has none."""
    p = Path(path)
    if not p.is_file():
        sys.exit(f'plan-view: no spec at {path}')
    if p.suffix.lower() not in ('.html', '.htm'):
        return None
    text = re.sub(r'<!--.*?-->', '', p.read_text(encoding='utf-8'), flags=re.S)
    found = DIAGRAM.search(text)
    if not found:
        return None
    svg = re.sub(r'<(style|script)\b.*?</\1\s*>', '', found.group(0), flags=re.S | re.I)
    return {
        'svg': re.sub(r'var\(\s*--', 'var(--spec-', svg),
        'style': scope_css('\n'.join(re.findall(r'<style\b[^>]*>(.*?)</style\s*>', text, re.S | re.I))),
        'parts': list(dict.fromkeys(re.findall(r'''\sdata-part\s*=\s*["']([^"']+)["']''', svg))),
    }


def main(plan_path, narrative_path, spec_path, out_path):
    text = Path(plan_path).read_text(encoding='utf-8')
    nar = json.loads(Path(narrative_path).read_text(encoding='utf-8'))
    levels = json.loads((HERE / 'levels.json').read_text(encoding='utf-8'))[resolve()['account']]
    spec = spec_diagram(spec_path)
    plan = parse_plan(text)
    fates = parse_fates(text)
    recorded = parse_decisions(text)
    errors = []

    systems = nar.get('systems') or []
    shorts = [s['short'] for s in systems]
    if not spec and not systems:
        errors.append('narrative needs systems: the spec has no container diagram')
    for m in plan:
        w = nar['milestones'].get(str(m['n']))
        if not m['touches']:
            errors.append(f"M-{m['n']} has no Touches line naming the parts it changes")
        elif spec:
            errors += [f"M-{m['n']} touches {p}, which is not a data-part in the spec's container diagram"
                       for p in m['touches'] if p not in spec['parts']]
        if not w or not all(w.get(k) for k in ('short', 'lead', 'does', 'proof', 'undo')):
            errors.append(f"narrative milestone {m['n']} needs short, lead, does, proof and undo")
        elif spec and w['lead'] not in m['touches']:
            errors.append(f"milestone {m['n']} lead {w['lead']!r} is not a part on its Touches line")
        elif not spec and w['lead'] not in shorts:
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
            **{k: w.get(k) for k in ('short', 'lead', 'does', 'proof', 'undo', 'guard', 'you')},
            'n': m['n'], 'test': m['test'], 'tasks': len(m['tasks']), 'touches': m['touches'],
            'levels': {k[0]: sum(1 for t in m['tasks'] if t['level'] == k) for k in LEVELS},
            'crit': [f"{t['id']} {t['title']}" for t in m['tasks'] if t['level'] == 'critical'],
            'fates': count,
            'touch': {s['short']: sum(1 for t in m['tasks'] if any(f.startswith(tuple(s.get('homes', ()))) for f in t['files']))
                      for s in systems},
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
    if spec:
        page.update(specDiagram=spec['svg'], specStyle=spec['style'])
    data = json.dumps(page, ensure_ascii=False).replace('</', '<\\/')
    out = (HERE.parent / 'templates' / 'plan-view.html').read_text(encoding='utf-8')
    out = out.replace('/*PLAN*/null', data).replace('/*TITLE*/', html.escape(nar['title']))
    Path(out_path).write_text(out, encoding='utf-8')
    diagram = f"spec diagram with {len(spec['parts'])} parts" if spec else 'no spec diagram'
    print(f"{out_path}: {len(plan)} milestones, {sum(len(m['tasks']) for m in plan)} tasks, {len(fates)} placed rows, {diagram}")


if __name__ == '__main__':
    if len(sys.argv) != 5:
        sys.exit('usage: plan-view.py <milestones.md> <narrative.json> <spec> <out.html>')
    main(*sys.argv[1:])
