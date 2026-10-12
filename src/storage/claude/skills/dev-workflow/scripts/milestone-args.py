"""Build a milestone's workflow from the plan, read where it stopped, and rebuild it for the resume.

    python3 milestone-args.py start <plan> <n> --epic E --spec S --tree T --project-base B --out DIR
    python3 milestone-args.py show <workflow output file>
    python3 milestone-args.py resume DIR/<E>-M<n>.json <workflow output file> [--decide KEY TEXT]... [--settle ID TEXT]...

start writes DIR/<E>-M<n>.json, the workflow's args, and DIR/<E>-M<n>.workflow.js, milestone.workflow.js with
those args inlined so no launch or resume carries them through a tool call. Launch that file by scriptPath.

show prints where a run stopped: the stage, the key to decide, its question, and each task's status.

resume settles every finished task, adds each decision under its key (after any earlier one), and rewrites both
files; the milestone itself is never touched. --settle closes a task whose question the parent answered by doing
the work, appending TEXT to its notes. A TEXT starting with @ is read from that file. Relaunch with the same
scriptPath and the first launch's run id as resumeFromRunId.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TIMEOUT = 'Run pytest with `--timeout=900 --timeout-method=thread` every time, so a hung test cannot stall the build.'


def milestone(plan, n):
    text = Path(plan).read_text()
    sec = re.search(rf'^## M-{n}: (.*?)\n(.*?)(?=^## M-|\Z)', text, re.M | re.S)
    if not sec:
        sys.exit(f'no "## M-{n}:" section in {plan}')
    body = sec.group(2)
    tasks = []
    for t in re.finditer(r'^### (T-\d+\.\d+): ([^\n]*)\n(.*?)(?=^### T-|\Z)', body, re.M | re.S):
        card = t.group(3)
        files = re.search(r'^- \*\*Files:\*\*(.*?)(?=^- \*\*|\n\n)', card, re.M | re.S)
        after = re.search(r'^- \*\*After:\*\*([^\n]*)', card, re.M)
        level = re.search(r'^- \*\*Level:\*\* *(\w+)', card, re.M)
        tasks.append({
            'id': t.group(1), 'title': t.group(2).strip(),
            'files': re.findall(r'`([^`]+)`', files.group(1)) if files else [],
            'after': re.findall(r'T-\d+\.\d+', after.group(1)) if after else [],
            'level': level.group(1) if level else None,
            'card': f'Your card is the section "### {t.group(1)}:" of the plan at {plan}: read it whole, '
                    f"and the milestone's Scaffold and Tests paragraphs above it. {TIMEOUT}",
        })
    pointer = lambda k: (f'Read the "**{k}:**" paragraph of section "## M-{n}:" in the plan at {plan}, whole, '
                         f"and the milestone's Proof paragraph. {TIMEOUT}")
    return {'id': f'M-{n}', 'title': sec.group(1).strip(),
            'proof': re.search(r'^\*\*Proof:\*\* `([^`]*)`', body, re.M).group(1),
            'scaffold': pointer('Scaffold'), 'tests': pointer('Tests'), 'tasks': tasks}


def brief(plan, spec):
    """The decider's big picture: the spec whole, then the plan at one line per task with its recorded decisions."""
    lines = []
    for sec in re.finditer(r'^## M-(\d+): ([^\n]*)\n(.*?)(?=^## M-|\Z)', Path(plan).read_text(), re.M | re.S):
        proof = re.search(r'^\*\*Proof:\*\* `([^`]*)`', sec.group(3), re.M)
        lines.append(f'M-{sec.group(1)}: {sec.group(2).strip()} | proof: {proof.group(1) if proof else "none"}')
        for t in re.finditer(r'^### (T-\d+\.\d+): ([^\n]*)\n(.*?)(?=^### T-|\Z)', sec.group(3), re.M | re.S):
            card = t.group(3)
            files = re.search(r'^- \*\*Files:\*\*(.*?)(?=^- \*\*|\n\n)', card, re.M | re.S)
            after = re.search(r'^- \*\*After:\*\*([^\n]*)', card, re.M)
            level = re.search(r'^- \*\*Level:\*\* *(\w+)', card, re.M)
            ids = ', '.join(re.findall(r'T-\d+\.\d+', after.group(1))) if after else 'none'
            paths = ', '.join(re.findall(r'`([^`]+)`', files.group(1))) if files else 'none'
            lines.append(f'  {t.group(1)} [{level.group(1) if level else "none"}] {t.group(2).strip()} | after: {ids} | files: {paths}')
            lines += ['    decided: ' + ' '.join(d.split()) for d in re.findall(r'^Decided during the build:(.*?)(?=\n\n|\Z)', card, re.M | re.S)]
    return (f"The build's big picture as this run started. The spec, whole:\n\n{Path(spec).read_text()}\n\n"
            f"The plan, one line per task; each task's card in the plan holds its detail:\n\n" + '\n'.join(lines))


def write(path, args):
    args['brief'] = brief(args['plan'], args['spec'])
    path.write_text(json.dumps(args, indent=1))
    src = (HERE / 'milestone.workflow.js').read_text()
    if src.count('} = args\n') != 1:
        sys.exit('milestone.workflow.js no longer destructures args in one place')
    src = src.replace('} = args\n', '} = __ARGS\n')
    cut = src.index('\n}\n', src.index('export const meta')) + 3
    script = path.parent / f'{path.stem}.workflow.js'
    script.write_text(f'{src[:cut]}const __ARGS = {json.dumps(args)}\n{src[cut:]}')
    print(script)


def stop_of(output):
    result = json.loads(Path(output).read_text())['result']
    return json.loads(result) if isinstance(result, str) else result


def last_layer(tasks):
    """Each task's id, mapped to whether the workflow ran it in its last layer, where a red report counts as stuck."""
    done, pending, last = set(), list(tasks), {}
    while pending:
        layer = [t for t in pending if all(a in done for a in t['after'])]
        if not layer:
            break
        last.update({t['id']: len(layer) == len(pending) for t in layer})
        done |= {t['id'] for t in layer}
        pending = [t for t in pending if t not in layer]
    return last


def text(value):
    return Path(value[1:]).read_text().strip() if value.startswith('@') else value


def start(o):
    args = {
        'epic': o.epic, 'spec': o.spec, 'plan': str(Path(o.plan).resolve()), 'tree': o.tree,
        'base': subprocess.check_output(['git', '-C', o.tree, 'rev-parse', 'HEAD'], text=True).strip(),
        'projectBase': o.project_base, 'scripts': str(HERE),
        'levels': json.loads((HERE / 'levels.json').read_text()),
        'milestone': milestone(o.plan, o.n), 'decisions': {}, 'settled': {},
    }
    unlevelled = [t['id'] for t in args['milestone']['tasks'] if t['level'] not in args['levels']]
    if unlevelled:
        sys.exit(f'no level on {", ".join(unlevelled)}')
    write(Path(o.out) / f'{o.epic}-M{o.n}.json', args)


def show(o):
    r = stop_of(o.output)
    if not r.get('stopped'):
        print(f'finished; usage {json.dumps(r.get("usage"))}')
        for d in r.get('decided', []):
            print(f'  decided in the run, {d["key"]}: {d["decision"]}')
        return
    report = r.get('report') or {}
    print(f'stopped at {r["stopped"]} on {r["key"]}; usage {json.dumps(r.get("usage"))}')
    print(f'redesign: {report["redesign"]}' if report.get('redesign') else
          f'question: {report.get("question") or r.get("reason") or report.get("gate") or "(none; read the report)"}')
    for d in r.get('decided', []):
        print(f'  decided in the run, {d["key"]}: {d["decision"]}')
    for b in r.get('built', []):
        print(f'  {b["id"]}: {b.get("status", "no report")}, green={b.get("green")}, level={b.get("level")}'
              f'{", promoted" if "first" in b else ""}')


def resume(o):
    path = Path(o.args)
    args = json.loads(path.read_text())
    r = stop_of(o.output)
    if not r.get('stopped'):
        sys.exit('the run finished; there is nothing to resume')
    last = last_layer(args['milestone']['tasks'])
    answered = {i: text(t) for i, t in o.settle}
    for b in r.get('built', []):
        report = {k: v for k, v in b.items() if k not in ('id', 'first')}
        if b['id'] in answered:
            report['status'] = 'done'
            report['notes'] = f"{report.get('notes', '')}\n\nThe parent: {answered.pop(b['id'])}".strip()
        elif report.get('status') != 'done' or (last.get(b['id']) and report.get('green') is False):
            continue
        args['settled'][b['id']] = report
    if answered:
        sys.exit(f'no report in the run to settle for {", ".join(answered)}')
    for key, t in o.decide:
        earlier = args['decisions'].get(key)
        args['decisions'][key] = f'{earlier}\n\n{text(t)}' if earlier else text(t)
    write(path, args)
    print(f'settled {len(args["settled"])} of {len(args["milestone"]["tasks"])}; decisions on {", ".join(args["decisions"]) or "nothing"}')


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest='command', required=True)
    s = sub.add_parser('start')
    s.add_argument('plan')
    s.add_argument('n')
    for flag in ('--epic', '--spec', '--tree', '--project-base', '--out'):
        s.add_argument(flag, required=True)
    sub.add_parser('show').add_argument('output')
    r = sub.add_parser('resume')
    r.add_argument('args')
    r.add_argument('output')
    r.add_argument('--decide', nargs=2, action='append', default=[], metavar=('KEY', 'TEXT'))
    r.add_argument('--settle', nargs=2, action='append', default=[], metavar=('ID', 'TEXT'))
    o = p.parse_args()
    {'start': start, 'show': show, 'resume': resume}[o.command](o)


if __name__ == '__main__':
    main()
