#!/usr/bin/env python3
"""Mutate the lines a branch changed and list every mutant its contract tests do not kill.

Usage: mutation-sweep.py <base-ref> [--paths P...] [--max-per-line N] [--test-cmd CMD]
                         [--timeout S] [--out FILE] [--list]

Run from the root of the repository under test, on a clean committed HEAD. Mutates the
lines HEAD changed since the merge base with <base-ref>, in Python and shell source only,
and runs the tests once per mutant, in place. Every other changed file outside the tests
and docs prints as `not swept: <path>`. Exit 0: nothing survived, 1: a mutant survived,
2: error, 3: nothing survived but a file was not swept.

Skipped as arid: blank lines, comments, docstrings and other multi-line strings, imports,
def/class/decorator lines, string-only lines, and logging calls (shell: log, echo to stderr).
Operators, in priority order, at most --max-per-line per line: relational, logical,
negation, constant, jump (continue/break), swallow (shell `|| fail*`, `|| exit` to `|| true`), remove
(a simple statement becomes `pass`, or `:` in shell). A mutant must still parse.

Tests: the Contract-Run trailer of the latest test(contract): commit in the range, narrowed
per file to the Contract-Files whose text names it, and checked green unmutated once.
Leading `export`, `;` and NAME=value words of that command set its environment, as in a shell.
"""

import argparse
import ast
import dataclasses
import functools
import io
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time
import tokenize
from collections import Counter
from pathlib import Path

MASK = "\x00"
SKIP_DIRS = {"tests", "test", "docs"}
SHELL_SUFFIXES = {".sh", ".bash", ".zsh"}
SIMPLE_STMTS = (
    ast.Expr, ast.Assign, ast.AugAssign, ast.AnnAssign, ast.Return,
    ast.Raise, ast.Assert, ast.Delete, ast.Global, ast.Nonlocal,
)  # fmt: skip
LOG_NAMES = {"_log", "log", "logger", "logging"}
SH_KEYWORDS = (
    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
    "case", "esac", "function", "{", "}", "(", ")", ";;", "in",
)  # fmt: skip


class SweepError(Exception):
    pass


@dataclasses.dataclass
class Mutant:
    path: str
    line: int
    operator: str
    original: str
    mutated: str
    text: str  # the whole mutated file

    def label(self):
        return f"{self.path}:{self.line}  {self.operator}  {self.original} -> {self.mutated}"


def git(*args, check=True):
    p = subprocess.run(["git", *args], capture_output=True, text=True)
    if check and p.returncode:
        raise SweepError(f"git {' '.join(args)}: {p.stderr.strip()}")
    return p.stdout


def changed_lines(base):
    merge_base = git("merge-base", base, "HEAD").strip()
    diff = git("-c", "core.quotepath=false", "diff", "-U0", merge_base, "HEAD")
    out, path = {}, None
    for row in diff.splitlines():
        if row.startswith("+++ "):
            path = row[6:] if row.startswith("+++ b/") else None
        elif row.startswith("@@") and path:
            m = re.match(r"@@ -\S+ \+(\d+)(?:,(\d+))? @@", row)
            start, n = int(m[1]), int(m[2] if m[2] is not None else 1)
            out.setdefault(path, set()).update(range(start, start + n))
    return merge_base, out


def excluded(path):
    parts = Path(path).parts
    return bool(SKIP_DIRS & set(parts[:-1])) or parts[-1] == "conftest.py" or parts[-1].startswith("test_")


def source_kind(path):
    if excluded(path):
        return None
    name = Path(path).name
    if name.endswith(".py"):
        return "py"
    if Path(path).suffix in SHELL_SUFFIXES:
        return "sh"
    try:
        first = Path(path).open(errors="replace").readline()
    except OSError:
        return None
    return "sh" if re.match(r"#!.*\b(ba)?sh\b", first) else None


def mask_python(text, lines):
    masks = [[False] * len(line) for line in lines]
    quoted = {tokenize.STRING, tokenize.COMMENT}
    for name in ("FSTRING_START", "FSTRING_MIDDLE", "FSTRING_END", "TSTRING_START", "TSTRING_MIDDLE", "TSTRING_END"):
        if hasattr(tokenize, name):
            quoted.add(getattr(tokenize, name))
    for tok in tokenize.generate_tokens(io.StringIO(text).readline):
        if tok.type not in quoted:
            continue
        (r1, c1), (r2, c2) = tok.start, tok.end
        for r in range(r1, r2 + 1):
            lo = c1 if r == r1 else 0
            hi = c2 if r == r2 else len(lines[r - 1])
            for c in range(lo, min(hi, len(lines[r - 1]))):
                masks[r - 1][c] = True
    return masks


def python_facts(text, lines):
    """Arid line numbers and the lines holding exactly one removable simple statement."""
    tree = ast.parse(text)
    arid, starts, removable = set(), Counter(), {}
    for node in ast.walk(tree):
        if isinstance(node, ast.stmt):
            starts[node.lineno] += 1
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            arid.update(range(node.lineno, node.end_lineno + 1))
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            for dec in node.decorator_list:
                arid.update(range(dec.lineno, dec.end_lineno + 1))
            arid.update(range(node.lineno, max(node.body[0].lineno, node.lineno + 1)))
        elif isinstance(node, ast.Expr):
            val = node.value
            if isinstance(val, (ast.Constant, ast.JoinedStr)) and not isinstance(getattr(val, "value", ""), (int, float, complex)):
                arid.update(range(node.lineno, node.end_lineno + 1))
            elif isinstance(val, ast.Call) and logging_call(val.func):
                arid.update(range(node.lineno, node.end_lineno + 1))
        if isinstance(node, SIMPLE_STMTS) and node.lineno == node.end_lineno:
            removable[node.lineno] = node
        if isinstance(node, ast.Constant) and isinstance(node.value, (str, bytes)) and node.end_lineno > node.lineno:
            arid.update(range(node.lineno + 1, node.end_lineno + 1))
    removable = {n: node for n, node in removable.items() if starts[n] == 1 and lines[n - 1][: node.col_offset].strip() == ""}
    return arid, removable


def logging_call(func):
    while isinstance(func, ast.Attribute):
        func = func.value
    return isinstance(func, ast.Name) and func.id in LOG_NAMES


def shell_facts(lines):
    """Masks (strings and comments blanked), and the lines inside multi-line strings and heredocs."""
    masks = [[False] * len(line) for line in lines]
    arid, quote, heredocs = set(), None, []
    for i, line in enumerate(lines):
        n = i + 1
        if heredocs:
            arid.add(n)
            masks[i] = [True] * len(line)
            delim, strip = heredocs[0]
            if (line.lstrip("\t") if strip else line).rstrip("\r") == delim:
                heredocs.pop(0)
            continue
        if quote:
            arid.add(n)
        pending, j = [], 0
        while j < len(line):
            ch = line[j]
            if quote:
                masks[i][j] = True
                if ch == "\\" and quote == '"':
                    masks[i][j + 1 : j + 2] = [True]
                    j += 1
                elif ch == quote:
                    quote = None
            elif ch == "\\":
                j += 1
            elif ch in "'\"":
                quote = ch
                masks[i][j] = True
            elif ch == "#" and (j == 0 or line[j - 1] in " \t;"):
                masks[i][j:] = [True] * (len(line) - j)
                break
            elif line.startswith("<<", j) and not line.startswith("<<<", j):
                m = re.match(r"<<(-?)\s*(['\"]?)([A-Za-z_]\w*)\2", line[j:])
                if m:
                    pending.append((m[3], bool(m[1])))
                    j += m.end() - 1
            j += 1
        heredocs.extend(pending)
    return masks, arid


def masked(line, mask):
    return "".join(MASK if m else c for c, m in zip(line, mask))


def splice(line, start, end, repl):
    return line[:start] + repl + line[end:]


def swap(table, pattern, line, code):
    return [
        (f"{m[0]}->{table[m[0]]}", splice(line, m.start(), m.end(), table[m[0]]))
        for m in re.finditer(pattern, code)
    ]  # fmt: skip


PY_REL = {"==": "!=", "!=": "==", "<=": ">", ">=": "<", "<": ">=", ">": "<="}
PY_REL_RE = r"==|!=|<=|>=|(?<![<\-=])<(?![<=])|(?<![>\-=])>(?![>=])"
SH_REL = {"-eq": "-ne", "-ne": "-eq", "-lt": "-ge", "-ge": "-lt", "-gt": "-le", "-le": "-gt",
          "=": "!=", "==": "!=", "!=": "=", "-n": "-z", "-z": "-n"}  # fmt: skip
SH_REL_RE = r"(?<=\s)(?:-eq|-ne|-lt|-ge|-gt|-le|-n|-z|==|=|!=)(?=\s)"
BOOLS = {"True": "False", "False": "True"}
JUMPS = {"continue": "break", "break": "continue"}


def py_relational(line, code):
    out = swap(PY_REL, PY_REL_RE, line, code)
    for m in re.finditer(r"\bis\s+not\s+None\b|\bis\s+None\b", code):
        out.append(("is None toggled", splice(line, m.start(), m.end(), "is None" if "not" in m[0] else "is not None")))
    for m in re.finditer(r"\b(not\s+)?in\b", code):
        if re.search(r"\bfor\b", code[: m.start()]):
            continue
        out.append(("in toggled", splice(line, m.start(), m.end(), "in" if m[1] else "not in")))
    return out


def py_logical(line, code):
    return swap({"and": "or", "or": "and"}, r"\b(?:and|or)\b", line, code)


def py_negation(line, code):
    out = []
    for m in re.finditer(r"\bnot\s+(?!in\b)", code):
        if not re.search(r"\bis\s+$", code[: m.start()]):
            out.append(("not removed", splice(line, m.start(), m.end(), "")))
    m = re.match(r"^(\s*)(if|elif|while)\s+(.*\S)\s*:[\s\x00]*$", code)
    if m:
        out.append(("not added", splice(line, m.start(3), m.end(3), f"not ({line[m.start(3) : m.end(3)]})")))
    return out


def py_constant(line, code):
    out = swap(BOOLS, r"\b(?:True|False)\b", line, code)
    for m in re.finditer(r"(?<![\w.$])(\d+)(?![\w.])", code):
        n = int(m[1])
        out.append((f"{n}->{n + 1}", splice(line, m.start(), m.end(), str(n + 1))))
        if n == 1:
            out.append(("1->0", splice(line, m.start(), m.end(), "0")))
    return out


def jump(line, code):
    return swap(JUMPS, r"\b(?:continue|break)\b", line, code)


def sh_relational(line, code):
    return swap(SH_REL, SH_REL_RE, line, code) if "[" in code else []


def sh_logical(line, code):
    return swap({"&&": "||", "||": "&&"}, r"&&|\|\|", line, code)


def sh_negation(line, code):
    out = []
    m = re.match(r"^(\s*)(?:if|elif)\s+(!\s*)", code)
    if m:
        out.append(("! removed", splice(line, m.start(2), m.end(2), "")))
    m = re.match(r"^\s*(?:if|elif)\s+(?!!)", code)
    if m:
        out.append(("! added", splice(line, m.end(), m.end(), "! ")))
    return out


def sh_constant(line, code):
    return [
        (f"{m[1]} {m[2]}", splice(line, m.start(2), m.end(2), "1" if m[2] == "0" else "0"))
        for m in re.finditer(r"\b(exit|return)\s+([01])\b", code)
    ]  # fmt: skip


def sh_swallow(line, code):
    m = re.search(r"\|\|\s*(?:fail\w*|die\w*|exit|return)\b.*?(?=\s*\\?\s*$)", code)
    return [("|| fail/exit -> || true", splice(line, m.start(), m.end(), "|| true"))] if m else []


PY_OPERATORS = [("relational", py_relational), ("logical", py_logical), ("negation", py_negation),
                ("constant", py_constant), ("jump", jump)]  # fmt: skip
SH_OPERATORS = [("relational", sh_relational), ("logical", sh_logical), ("negation", sh_negation),
                ("constant", sh_constant), ("jump", jump), ("swallow", sh_swallow)]  # fmt: skip


def shell_removable(code):
    s = code.strip()
    words = s.split()
    if not words or words[0].rstrip(";") in SH_KEYWORDS or s[0] in "{}()":
        return False
    if s.endswith(("\\", "{", "&&", "||", "|", ";;")) or "<<" in s or s.count("(") != s.count(")"):
        return False
    return not re.match(r"^[\w:.-]+\s*\(\)", s)


def shell_arid(code):
    s = code.strip()
    if s.strip(MASK) == "":
        return True
    if re.match(r"(?:source|\.)\s", s) or re.match(r"(?:function\s+\S+|[\w:.-]+\s*\(\))", s):
        return True
    if re.match(r"log\b", s):
        return True
    return bool(re.match(r"(?:echo|printf)\b", s) and re.search(r">&\s*2", s))


def mutants_for_file(path, kind, lines_wanted, per_line):
    raw = Path(path).read_bytes()
    try:
        text = raw.decode()
    except UnicodeDecodeError:
        return []
    lines = text.split("\n")
    crlf = [row.endswith("\r") for row in lines]
    lines = [row.rstrip("\r") for row in lines]
    if kind == "py":
        try:
            arid, removable = python_facts(text, lines)
            masks = mask_python(text, lines)
        except (SyntaxError, tokenize.TokenError) as exc:
            print(f"skip {path}: does not parse ({exc})", file=sys.stderr)
            return []
        operators, parses = PY_OPERATORS, ast_ok
    else:
        masks, arid = shell_facts(lines)
        removable, operators = None, SH_OPERATORS
        interpreter = "zsh" if path.endswith(".zsh") else "bash"

        def parses(t):
            return subprocess.run([interpreter, "-n"], input=t, capture_output=True, text=True).returncode == 0

        if not parses(text):
            print(f"skip {path}: does not parse", file=sys.stderr)
            return []
    out = []
    for n in sorted(lines_wanted):
        if n > len(lines) or n in arid:
            continue
        line = lines[n - 1]
        code = masked(line, masks[n - 1])
        if not line.strip() or code.strip(MASK + " \t") == "":
            continue
        if kind == "sh" and shell_arid(code):
            continue
        candidates = [(name, label, new) for name, fn in operators for label, new in fn(line, code)]
        if kind == "py" and n in removable:
            candidates.append(("remove", "statement -> pass", line[: removable[n].col_offset] + "pass"))
        elif kind == "sh" and shell_removable(code) and not (n >= 2 and lines[n - 2].rstrip().endswith("\\")):
            candidates.append(("remove", "statement -> :", line[: len(line) - len(line.lstrip())] + ":"))
        kept, seen = 0, {line}
        for name, label, new in candidates:
            if kept == per_line:
                break
            if new in seen:
                continue
            seen.add(new)
            rows = lines[:]
            rows[n - 1] = new
            mutated = "\n".join(row + ("\r" if c else "") for row, c in zip(rows, crlf))
            if parses(mutated):
                out.append(Mutant(path, n, name, line.strip(), new.strip(), mutated))
                kept += 1
    return out


def ast_ok(text):
    try:
        ast.parse(text)
    except (SyntaxError, ValueError):
        return False
    return True


def contract(merge_base):
    """The Contract-Run command and Contract-Files of the latest test(contract): commit in range."""
    log = git("log", "--format=%H%x00%s", f"{merge_base}..HEAD").splitlines()
    found = []
    for row in log:
        sha, subject = row.split("\0", 1)
        body = git("log", "-1", "--format=%B", sha)
        run = re.findall(r"^Contract-Run:\s*(.+)$", body, re.M)
        if run:
            files = " ".join(re.findall(r"^Contract-Files:\s*(.+)$", body, re.M)).split()
            found.append((not subject.startswith("test(contract):"), run[-1], files))
    if not found:
        raise SweepError(f"no commit in {merge_base[:9]}..HEAD carries a Contract-Run trailer; pass --test-cmd")
    _, run, files = min(found, key=lambda f: f[0])
    return run, files


def needles(path, kind):
    if kind == "sh":
        return [Path(path).name]
    parts = Path(path).with_suffix("").parts
    if parts[-1] == "__init__":
        parts = parts[:-1]
    tail = parts[-2:]
    return [".".join(tail), " import ".join(tail), path]


def narrow(path, kind, files):
    keys = needles(path, kind)
    hit = []
    for f in files:
        try:
            body = Path(f).read_text(errors="replace")
        except OSError:
            continue
        if any(k in body for k in keys) or (kind != "sh" and binds_module(body, path)):
            hit.append(f)
    return hit or files


def binds_module(body, path):
    """Whether the text imports the module as a name in a `from <pkg> import a, (b as c), ...` list."""
    parts = Path(path).with_suffix("").parts
    if parts[-1] == "__init__":
        parts = parts[:-1]
    if len(parts) < 2:
        return False
    pkg, mod = parts[-2:]
    for names in re.findall(rf"\bfrom\s+(?:[\w.]*\.)?{re.escape(pkg)}\s+import\s+(\([^)]*\)|[^\n]*)", body):
        if re.search(rf"\b{re.escape(mod)}\b", names):
            return True
    return False


def build_command(run, files, test_cmd, narrowed):
    if test_cmd:
        args = shlex.split(test_cmd.replace("{files}", shlex.join(narrowed)))
    else:
        args = shell_words(run)
        in_cmd = [t for t in args if t in set(files)]
        keep = [t for t in narrowed if t in in_cmd] or in_cmd
        if in_cmd:
            at = args.index(in_cmd[0])
            args = [t for t in args[:at] if t not in in_cmd] + keep + [t for t in args[at:] if t not in in_cmd]
    if any(Path(t).name in ("pytest", "py.test") for t in args):
        at = max(i for i, t in enumerate(args) if Path(t).name in ("pytest", "py.test"))
        args = [t for i, t in enumerate(args) if i <= at or t not in ("-v", "-vv", "--verbose")]
        args[at + 1 : at + 1] = [f for f in ("-x", "-q") if f not in args]
        timed = any(t.startswith("--timeout") for t in args)
        if timed and not any(t.startswith("--max-worker-restart") for t in args) and has_xdist(tuple(args[: at + 1])):
            # xdist replaces a worker that a timed-out test killed, and the run never exits.
            args.append("--max-worker-restart=0")
    return args


def shell_words(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars=";")
    lex.whitespace_split = True
    return list(lex)


@functools.cache
def has_xdist(pytest_prefix):
    env, argv = split_env([*pytest_prefix, "--help"])
    p = subprocess.run(argv, capture_output=True, text=True, env=env)
    return "--max-worker-restart" in p.stdout


def split_env(args):
    """The environment with the leading NAME=value words applied, and the rest as argv."""
    n = 0
    while n < len(args) and (args[n] in ("export", ";") or re.fullmatch(r"[A-Za-z_]\w*=.*", args[n], re.S)):
        n += 1
    assigns = [a for a in args[:n] if a not in ("export", ";")]
    return {**os.environ, **dict(shell_assignment(a) for a in assigns)}, list(args[n:])


def shell_assignment(word):
    """NAME=value with the value expanded by bash, as the shell that ran the trailer would."""
    name, value = word.split("=", 1)
    if "$" in value or "`" in value:
        value = subprocess.run(
            ["bash", "-c", 'eval "printf %s \"${1#*=}\""', "_", word], capture_output=True, text=True, check=True
        ).stdout
    return name, value


def run_tests(args, timeout):
    # A stale .pyc from a same-size mutant written in the same second would run the wrong code.
    env, argv = split_env(args)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.Popen(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, env=env)
    try:
        return p.wait(timeout)
    except subprocess.TimeoutExpired:
        kill(p)
        return None
    except BaseException:
        kill(p)
        raise


def kill(p):
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    p.wait()


def on_term(signum, frame):
    raise KeyboardInterrupt


def main():
    ap = argparse.ArgumentParser(description="Mutate a branch's changed lines and list the mutants its tests do not kill.")
    ap.add_argument("base_ref")
    ap.add_argument("--paths", nargs="+", help="limit to these files or directories")
    ap.add_argument("--max-per-line", type=int, default=2)
    ap.add_argument("--test-cmd", help="test command; {files} becomes the narrowed Contract-Files")
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--out", help="also write the result as JSON")
    ap.add_argument("--list", action="store_true", help="print the mutants and the test runs they need; run nothing")
    opts = ap.parse_args()
    started = time.monotonic()

    if git("status", "--porcelain", "--untracked-files=no").strip():
        raise SweepError("the working tree has tracked changes; commit or restore them first")
    merge_base, changed = changed_lines(opts.base_ref)
    mutants, unswept = [], []
    for path in sorted(changed):
        if excluded(path) or not Path(path).is_file():
            continue
        if opts.paths and not any(path == p.rstrip("/") or path.startswith(p.rstrip("/") + "/") for p in opts.paths):
            continue
        kind = source_kind(path)
        if kind is None:
            unswept.append(path)
            continue
        mutants += mutants_for_file(path, kind, changed[path], opts.max_per_line)

    run, files = None, []
    if mutants:
        try:
            run, files = contract(merge_base)
        except SweepError:
            if not opts.test_cmd:
                raise
    commands = {}
    for m in mutants:
        narrowed = narrow(m.path, source_kind(m.path), files)
        commands[m.path] = build_command(run, files, opts.test_cmd, narrowed)

    if opts.list:
        per_file = Counter(m.path for m in mutants)
        for m in mutants:
            print(m.label())
        for path, n in per_file.items():
            print(f"{path}: {n} mutants -> {shlex.join(commands[path])}")
        baselines = len({tuple(c) for c in commands.values()})
        print(f"{len(mutants)} mutants, {len(mutants) + baselines} test runs ({baselines} baseline)")
        for path in unswept:
            print(f"not swept: {path}")
        return 0

    signal.signal(signal.SIGTERM, on_term)
    signal.signal(signal.SIGHUP, on_term)
    results, checked = [], set()
    try:
        for i, m in enumerate(mutants, 1):
            args = commands[m.path]
            if tuple(args) not in checked:
                print(f"baseline: {shlex.join(args)}", file=sys.stderr)
                if run_tests(args, opts.timeout) != 0:
                    raise SweepError(f"the tests fail or time out unmutated: {shlex.join(args)}")
                checked.add(tuple(args))
            target = Path(m.path)
            original = target.read_bytes()
            t0 = time.monotonic()
            try:
                target.write_bytes(m.text.encode())
                rc = run_tests(args, opts.timeout)
            finally:
                target.write_bytes(original)
            status = "timeout" if rc is None else "survived" if rc == 0 else "killed"
            results.append((m, status))
            print(f"[{i}/{len(mutants)}] {m.path}:{m.line} {m.operator} {status} {time.monotonic() - t0:.0f}s", file=sys.stderr)
    except KeyboardInterrupt:
        print("interrupted; files restored", file=sys.stderr)
        verify_clean()
        return 130
    verify_clean()

    survivors = [m for m, s in results if s == "survived"]
    timed_out = sum(s == "timeout" for _, s in results)
    elapsed = time.monotonic() - started
    summary = (f"mutants {len(results)}, killed {len(results) - len(survivors)}, survived {len(survivors)}, "
               f"timed out {timed_out}; {elapsed:.0f}s")  # fmt: skip
    for m in survivors:
        print(m.label())
    print(summary)
    for path in unswept:
        print(f"not swept: {path}")
    if opts.out:
        Path(opts.out).write_text(json.dumps({
            "base": opts.base_ref, "merge_base": merge_base, "mutants": len(results),
            "killed": len(results) - len(survivors), "survived": len(survivors), "timed_out": timed_out,
            "elapsed_seconds": round(elapsed, 1),
            "survivors": [dict(path=m.path, line=m.line, operator=m.operator, original=m.original, mutated=m.mutated) for m in survivors],
            "not_swept": unswept,
        }, indent=2) + "\n")  # fmt: skip
    return 1 if survivors else 3 if unswept else 0


def verify_clean():
    if subprocess.run(["git", "diff", "--quiet"]).returncode:
        raise SweepError("the working tree differs from HEAD after the sweep; inspect with git diff")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SweepError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
