"""Build a milestone's workflow from the plan, read where it stopped, and rebuild it for the resume.

    python3 milestone-args.py start <plan> <n> --epic E --spec S --tree T --project-base B --out DIR
    python3 milestone-args.py show <workflow output file>
    python3 milestone-args.py bed DIR/<E>-M<n>.json <workflow output file>
    python3 milestone-args.py fix DIR/<E>-M<n>.json <failures file>
    python3 milestone-args.py resume DIR/<E>-M<n>.json <workflow output file> [--decide KEY TEXT]... [--settle ID TEXT]...

start writes DIR/<E>-M<n>.json, the workflow's args, and DIR/<E>-M<n>.workflow.js, milestone.workflow.js with
those args inlined so no launch or resume carries them through a tool call. Launch that file by scriptPath.

show prints where a run stopped: the stage, the key to decide, its question, and each task's status.

bed prints the milestone's one end-to-end run: the test writer's tests and the proofs of this and every earlier
milestone, in one pytest command.

fix prints the prompt of the one worker that fixes the end-to-end run's failures, which the failures file names.

resume settles every finished task, a finished review and each finished fold group, adds each decision under its key (after any earlier
one), and rewrites both files; the milestone itself is never touched. A finished run never resumes: a resume
replays only the unbroken prefix of calls in their first order, which a finished fan-out breaks. --settle closes
a task whose question the parent answered by doing the work, appending TEXT to its notes. A TEXT starting with @ is read from that file. Relaunch with the same
scriptPath and the first launch's run id as resumeFromRunId.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'optimize-usage' / 'scripts'))
from levers import resolve
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
    args.setdefault('logs', str(path.parent.resolve()))
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


def text(value):
    return Path(value[1:]).read_text().strip() if value.startswith('@') else value


def start(o):
    args = {
        'epic': o.epic, 'spec': o.spec, 'plan': str(Path(o.plan).resolve()), 'tree': o.tree,
        'base': subprocess.check_output(['git', '-C', o.tree, 'rev-parse', 'HEAD'], text=True).strip(),
        'projectBase': o.project_base, 'scripts': str(HERE),
        'levels': json.loads((HERE / 'levels.json').read_text())[resolve()['account']],
        'milestone': milestone(o.plan, o.n), 'decisions': {}, 'settled': {}, 'logs': str(Path(o.out).resolve()),
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


def bed(o):
    args = json.loads(Path(o.args).read_text())
    r = stop_of(o.output)
    tree = Path(args['tree']).resolve()
    rel = lambda f: str(Path(f).resolve().relative_to(tree)) if Path(f).is_absolute() else f
    paths = [rel(f) for f in (r.get('tests') or {}).get('files', []) if re.match(r'test_.*\.py$|.*_test\.py$', Path(f).name)]
    n = int(args['milestone']['id'].split('-')[1])
    proofs = [re.search(r'^\*\*Proof:\*\* `([^`]*)`', sec.group(2), re.M)
              for sec in re.finditer(r'^## M-(\d+): [^\n]*\n(.*?)(?=^## M-|\Z)', Path(args['plan']).read_text(), re.M | re.S)
              if int(sec.group(1)) <= n]
    for proof in filter(None, proofs):
        paths += [w for w in proof.group(1).split('pytest', 1)[-1].split() if not w.startswith('-')]
    runner = args['milestone']['proof'].split('pytest', 1)[0] + 'pytest'
    print(f"cd {tree} && {runner} {' '.join(dict.fromkeys(paths))} --timeout=900 --timeout-method=thread -ra --durations=0 "
          f"> {args.get('logs') or Path(o.args).resolve().parent}/{args['epic']}-{args['milestone']['id']}-bed.log 2>&1")


def fix(o):
    args = json.loads(Path(o.args).read_text())
    m, tree, logs = args['milestone'], args['tree'], args.get('logs') or str(Path(o.args).resolve().parent)
    print(f"""Spec: {args['spec']} — read the sections this work names. Milestone {m['id']}: {m['title']}. Its proof: `{m['proof']}`.

The milestone's one end-to-end run, made after every task, the review, and the fold, failed: {text('@' + o.failures)}

- Read each failure's output in that log, and the whole path it runs through, before editing; the line a traceback names is often not the defect.
- Fix the code. The bed's harness (its topology, launchers, fixtures and env) is code too; an edit to a test function's assertions is a question.
- While fixing, rerun only the failed tests your latest fix could change, by node id, and the unit tests of every file you touch. Rerun every failed test once, in one invocation, at the end. Never rerun the whole set. {TIMEOUT} Write that last rerun's whole output to {logs}/{args['epic']}-{m['id']}-rerun.log.
- A failure that passes when rerun alone, and that no code explains, is load: say so and leave it.

Work only in {tree}, by absolute path and `git -C {tree}`. Commit only your own files, naming them: `git -C {tree} commit -m "<subject in the project's commit format; the ticket is {args['epic']}>" -- <your files>`. Never run git reset, checkout --, stash, clean, restore, push, or merge. Do the work yourself; spawn nothing. Leave the session's task list alone: no TaskCreate or TaskUpdate. A decision you cannot make from the code and the spec: fix every failure it does not block first, then return it as a question, saying what you did.

Return only what I act on: green (true when every failed test passes on the last rerun), each commit's sha and one line, each failure you left and why, and any question. Keep the reasoning; I can ask.""")


def resume(o):
    path = Path(o.args)
    args = json.loads(path.read_text())
    r = stop_of(o.output)
    if not r.get('stopped'):
        sys.exit('the run finished and never resumes: send what is left to one worker')
    answered = {i: text(t) for i, t in o.settle}
    for b in r.get('built', []):
        report = {k: v for k, v in b.items() if k not in ('id', 'first')}
        if b['id'] in answered:
            report['status'] = 'done'
            report['notes'] = f"{report.get('notes', '')}\n\nThe parent: {answered.pop(b['id'])}".strip()
        elif report.get('status') != 'done' or report.get('green') is False:
            continue
        args['settled'][b['id']] = report
    if answered:
        sys.exit(f'no report in the run to settle for {", ".join(answered)}')
    if r.get('review'):
        args['reviewed'] = r['review']
    for f in r.get('fold') or []:
        if f.get('status') == 'done':
            args.setdefault('folded', {})[f['key']] = {k: v for k, v in f.items() if k not in ('key', 'findings')}
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
    b = sub.add_parser('bed')
    b.add_argument('args')
    b.add_argument('output')
    f = sub.add_parser('fix')
    f.add_argument('args')
    f.add_argument('failures')
    r = sub.add_parser('resume')
    r.add_argument('args')
    r.add_argument('output')
    r.add_argument('--decide', nargs=2, action='append', default=[], metavar=('KEY', 'TEXT'))
    r.add_argument('--settle', nargs=2, action='append', default=[], metavar=('ID', 'TEXT'))
    o = p.parse_args()
    {'start': start, 'show': show, 'bed': bed, 'fix': fix, 'resume': resume}[o.command](o)


if __name__ == '__main__':
    main()
