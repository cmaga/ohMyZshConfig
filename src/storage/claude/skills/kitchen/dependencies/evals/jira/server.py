#!/usr/bin/env python3
"""A stand-in Jira for eval runs, so `jira` behaves like the real thing without reaching a real Jira.

The run's shell is sandboxed and cannot open a socket, so bin/jira inside it drops each call into
<state>/spool, and this process, started outside the sandbox by session-start.sh, runs the real
jira-cli on it. jira-cli reaches this server as its HTTP proxy, so every byte the run sees is real
jira-cli output over the issues in <state>/issues.json. The process exits once the run's home is
gone, since nothing tells it the run ended.

Usage: server.py <state dir> <jira-cli config>
"""
import json
import os
import re
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

STATE, CONFIG = sys.argv[1], sys.argv[2]
SPOOL = os.path.join(STATE, "spool")
LOCK = threading.Lock()
DB = json.load(open(os.path.join(STATE, "issues.json")))
USERS = {u["email"]: u for u in DB["users"]}
ME = USERS[DB["me"]]
STATUSES = ["To Do", "In Progress", "In Review", "Done"]
LINK_TYPES = [("Blocks", "is blocked by", "blocks"), ("Cloners", "is cloned by", "clones"),
              ("Duplicate", "is duplicated by", "duplicates"), ("Relates", "relates to", "relates to")]
PRIORITIES = ["Highest", "High", "Medium", "Low", "Lowest"]


# --- documents: issues keep descriptions and comments as ADF, the format Jira Cloud stores ---

def inline(text):
    """`code` spans become code marks; everything else is plain text."""
    nodes = []
    for i, part in enumerate(re.split(r"`([^`]*)`", text)):
        if part:
            node = {"type": "text", "text": part}
            if i % 2:
                node["marks"] = [{"type": "code"}]
            nodes.append(node)
    return nodes


def to_adf(text):
    """Fixture text to ADF: blank-line paragraphs, `- ` bullet lists, ``` code blocks."""
    content = []
    for block in re.split(r"\n\s*\n", text.strip()):
        lines = block.split("\n")
        if lines[0].startswith("```"):
            body = "\n".join(lines[1:-1] if lines[-1].startswith("```") else lines[1:])
            content.append({"type": "codeBlock", "attrs": {}, "content": [{"type": "text", "text": body}]})
        elif all(l.startswith("- ") for l in lines):
            content.append({"type": "bulletList", "content": [
                {"type": "listItem", "content": [{"type": "paragraph", "content": inline(l[2:])}]} for l in lines]})
        else:
            para = []
            for j, l in enumerate(lines):
                if j:
                    para.append({"type": "hardBreak"})
                para += inline(l)
            content.append({"type": "paragraph", "content": para})
    return {"version": 1, "type": "doc", "content": content}


def wiki_inline(text):
    """Jira wiki markup spans: {{code}}, *strong*, _emphasis_; the rest is plain text."""
    nodes = []
    for m in re.finditer(r"\{\{(.+?)\}\}|(?<![\w*])\*(\S(?:.*?\S)?)\*(?![\w*])|(?<![\w_])_(\S(?:.*?\S)?)_(?![\w_])|([^{*_]+|.)", text):
        code, strong, em, rest = m.groups()
        mark = "code" if code else "strong" if strong else "em" if em else None
        piece = code or strong or em or rest
        if nodes and mark is None and "marks" not in nodes[-1]:
            nodes[-1]["text"] += piece
        else:
            nodes.append({"type": "text", "text": piece, **({"marks": [{"type": mark}]} if mark else {})})
    return nodes


def wiki_to_adf(text):
    """What jira-cli sends on API v2 (wiki markup) to ADF, as Jira converts it before storing."""
    content = []
    parts = re.split(r"\{(?:code|noformat)(?::[^}]*)?\}(.*?)\{(?:code|noformat)\}", text.strip(), flags=re.S)
    for n, part in enumerate(parts):
        if n % 2:
            content.append({"type": "codeBlock", "attrs": {}, "content": [{"type": "text", "text": part.strip("\n")}]})
            continue
        for block in re.split(r"\n\s*\n", part.strip()):
            lines = [l for l in block.split("\n") if l.strip()]
            if not lines:
                continue
            heading = re.match(r"h([1-6])\.\s+(.*)", lines[0])
            if heading and len(lines) == 1:
                content.append({"type": "heading", "attrs": {"level": int(heading.group(1))}, "content": wiki_inline(heading.group(2))})
            elif all(re.match(r"[*#-]+ ", l) for l in lines):
                kind = "orderedList" if lines[0].startswith("#") else "bulletList"
                content.append({"type": kind, "content": [{"type": "listItem", "content": [
                    {"type": "paragraph", "content": wiki_inline(l.split(" ", 1)[1])}]} for l in lines]})
            else:
                para = []
                for j, l in enumerate(lines):
                    if j:
                        para.append({"type": "hardBreak"})
                    para += wiki_inline(l)
                content.append({"type": "paragraph", "content": para})
    return {"version": 1, "type": "doc", "content": content}


def stored(body):
    """A body as Jira keeps it: ADF as sent on API v3, converted from wiki markup on v2."""
    return wiki_to_adf(body) if isinstance(body, str) else body


def plain(node):
    if isinstance(node, str):
        return node
    if isinstance(node, dict):
        return node.get("text", "") + " ".join(plain(c) for c in node.get("content", []))
    return ""


def stamp(dt=None):
    dt = dt or datetime.now().astimezone()
    return dt.strftime("%Y-%m-%dT%H:%M:%S.000%z")


def parse_stamp(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%S.%f%z")


for issue in DB["issues"]:
    issue["description"] = to_adf(issue["description"]) if issue.get("description") else None
    for c in issue.setdefault("comments", []):
        c["body"] = to_adf(c["body"])
    issue.setdefault("links", [])
    issue.setdefault("labels", [])
    issue.setdefault("components", [])
    issue.setdefault("assignee", None)
    issue.setdefault("watchers", 1)
    issue.setdefault("priority", "Medium")
    issue.setdefault("updated", issue["created"])


def find(key):
    key = key.upper()
    return next((i for i in DB["issues"] if i["key"] == key), None)


def reverse(phrase):
    name, inward, outward = next(t for t in LINK_TYPES if phrase in t[1:])
    return inward if phrase == outward else outward


# a fixture names each link once; Jira shows it from both ends
for issue in DB["issues"]:
    for link in issue["links"]:
        other = find(link["key"])
        back = {"type": reverse(link["type"]), "key": issue["key"]}
        if back not in other["links"]:
            other["links"].append(back)


def user_json(email):
    if not email:
        return None
    u = USERS[email]
    return {"accountId": u["accountId"], "displayName": u["name"], "emailAddress": email, "active": True,
            "timeZone": "America/Los_Angeles", "accountType": "atlassian"}


def user_by_account(account_id):
    return next((e for e, u in USERS.items() if u["accountId"] == account_id), None)


def status_json(name):
    cat = {"To Do": ("new", "To Do"), "Done": ("done", "Done")}.get(name, ("indeterminate", "In Progress"))
    return {"name": name, "statusCategory": {"key": cat[0], "name": cat[1]}}


def brief(issue):
    return {"id": issue["key"].split("-")[1], "key": issue["key"], "fields": {
        "summary": issue["summary"], "status": status_json(issue["status"]),
        "priority": {"name": issue["priority"]}, "issuetype": {"name": issue["type"]}}}


def issue_json(issue, api="3"):
    links = []
    for n, link in enumerate(issue["links"]):
        other = find(link["key"])
        name, inward, outward = next(t for t in LINK_TYPES if link["type"] in t)
        entry = {"id": str(1000 + n), "type": {"name": name, "inward": inward, "outward": outward}}
        entry["outwardIssue" if link["type"] == outward else "inwardIssue"] = brief(other)
        links.append(entry)
    desc, comments = issue["description"], issue["comments"]
    if api == "2":
        desc = plain(desc) if desc else None
    return {
        "id": issue["key"].split("-")[1], "key": issue["key"],
        "self": f"{DB['server']}/rest/api/{api}/issue/{issue['key']}",
        "fields": {
            "summary": issue["summary"], "description": desc,
            "issuetype": {"name": issue["type"], "subtask": False},
            "status": status_json(issue["status"]),
            "resolution": {"name": "Done"} if issue["status"] == "Done" else None,
            "priority": {"name": issue["priority"]},
            "reporter": user_json(issue["reporter"]), "assignee": user_json(issue["assignee"]),
            "creator": user_json(issue["reporter"]),
            "labels": issue["labels"], "components": [{"name": c} for c in issue["components"]],
            "project": {"key": DB["project"], "name": DB["project_name"]},
            "created": issue["created"], "updated": issue["updated"],
            "watches": {"isWatching": False, "watchCount": issue["watchers"]},
            "comment": {"comments": [{"id": str(10000 + n), "author": user_json(c["author"]),
                                      "body": plain(c["body"]) if api == "2" else c["body"],
                                      "created": c["created"], "updated": c["created"]}
                                     for n, c in enumerate(comments)],
                        "total": len(comments), "maxResults": len(comments), "startAt": 0},
            "issuelinks": links, "subtasks": [], "parent": None, "fixVersions": [], "versions": [],
        },
    }


# --- JQL: enough of the grammar for what jira-cli builds and what an agent types ---

class JQLError(Exception):
    pass


TOKEN = re.compile(r'\s*(?:(\()|(\))|(,)|("(?:[^"\\]|\\.)*"|\'[^\']*\')|(!=|!~|>=|<=|=|~|>|<)|([\w.\-]+\(\)|[\w.\-*]+))')


def tokenize(jql):
    out, pos = [], 0
    while pos < len(jql):
        if jql[pos:].strip() == "":
            break
        m = TOKEN.match(jql, pos)
        if not m:
            raise JQLError(f"Error in the JQL Query: The character '{jql[pos:].strip()[0]}' is a reserved JQL character.")
        pos = m.end()
        lp, rp, comma, quoted, op, word = m.groups()
        if quoted:
            out.append(("str", quoted[1:-1].replace('\\"', '"')))
        elif op:
            out.append(("op", op))
        elif word:
            out.append(("word", word))
        else:
            out.append(("punct", lp or rp or comma))
    return out


class Parser:
    def __init__(self, tokens):
        self.t, self.i = tokens, 0

    def peek(self, upper=True):
        if self.i >= len(self.t):
            return None
        kind, val = self.t[self.i]
        return val.upper() if upper and kind == "word" else val

    def take(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def expr(self):
        left = self.term()
        while self.peek() == "OR":
            self.take()
            right = self.term()
            left = ("or", left, right)
        return left

    def term(self):
        left = self.factor()
        while self.peek() == "AND":
            self.take()
            right = self.factor()
            left = ("and", left, right)
        return left

    def factor(self):
        if self.peek() == "NOT":
            self.take()
            return ("not", self.factor())
        if self.peek() == "(":
            self.take()
            e = self.expr()
            if self.peek() != ")":
                raise JQLError("Error in the JQL Query: Expecting ')' before the end of the query.")
            self.take()
            return e
        return self.clause()

    def value(self):
        if self.peek() == "(":
            self.take()
            vals = []
            while self.peek() != ")":
                if self.i >= len(self.t):
                    raise JQLError("Error in the JQL Query: Expecting ')' before the end of the query.")
                if self.peek() == ",":
                    self.take()
                    continue
                vals.append(self.take()[1])
            self.take()
            return vals
        if self.i >= len(self.t):
            raise JQLError("Error in the JQL Query: Expecting either a value, list or function but got the end of the query.")
        return self.take()[1]

    def clause(self):
        if self.i >= len(self.t):
            raise JQLError("Error in the JQL Query: Expecting a field name but got the end of the query.")
        field = self.take()[1]
        op = self.peek()
        if op is None:
            raise JQLError("Error in the JQL Query: Expecting operator but got the end of the query.")
        self.take()
        if op == "NOT" and self.peek() == "IN":
            self.take()
            op = "NOT IN"
        elif op == "IS" and self.peek() == "NOT":
            self.take()
            op = "IS NOT"
        if op not in ("=", "!=", "~", "!~", ">", ">=", "<", "<=", "IN", "NOT IN", "IS", "IS NOT", "WAS"):
            raise JQLError(f"Error in the JQL Query: Expecting operator but got '{op}'.")
        return ("clause", field.lower(), op, self.value())


def parse_jql(jql):
    order = None
    m = re.search(r"\border\s+by\s+(.+)$", jql, re.I)
    if m:
        jql = jql[:m.start()]
        first = m.group(1).split(",")[0].split()
        order = (first[0].strip('"').lower(), (first[1].upper() if len(first) > 1 else "ASC"))
    tokens = tokenize(jql)
    if not tokens:
        return None, order
    p = Parser(tokens)
    tree = p.expr()
    if p.i != len(tokens):
        raise JQLError(f"Error in the JQL Query: Expecting either 'OR' or 'AND' but got '{tokens[p.i][1]}'.")
    return tree, order


def relative_date(v):
    m = re.fullmatch(r"(-?\d+)([wdhm])", str(v))
    if m:
        n, unit = int(m.group(1)), m.group(2)
        return datetime.now().astimezone() + timedelta(**{{"w": "weeks", "d": "days", "h": "hours", "m": "minutes"}[unit]: n})
    try:
        return datetime.strptime(str(v)[:10], "%Y-%m-%d").replace(tzinfo=datetime.now().astimezone().tzinfo)
    except ValueError:
        raise JQLError(f"Date value '{v}' for field 'created' is invalid.")


def words(s):
    return re.findall(r"[\w\-./]+", s.lower())


def text_match(haystack, needle):
    hay = " ".join(words(haystack))
    hay_words = set(words(haystack))
    for w in words(needle.replace("*", " ")):
        if w not in hay_words and not any(h.startswith(w) for h in hay_words) and w not in hay:
            return False
    return True


def resolve_user(v):
    v = str(v)
    if v.lower() in ("currentuser()",):
        return ME["email"]
    for email, u in USERS.items():
        if v.lower() in (email.lower(), u["name"].lower(), u["accountId"].lower()):
            return email
    return v


def field_value(issue, field):
    return {
        "project": DB["project"], "key": issue["key"], "issuekey": issue["key"], "issue": issue["key"],
        "id": issue["key"], "status": issue["status"], "type": issue["type"], "issuetype": issue["type"],
        "priority": issue["priority"], "assignee": issue["assignee"], "reporter": issue["reporter"],
        "creator": issue["reporter"],
    }[field]


def status_category(issue):
    return {"To Do": "To Do", "Done": "Done"}.get(issue["status"], "In Progress")


def evaluate(node, issue):
    kind = node[0]
    if kind == "and":
        return evaluate(node[1], issue) and evaluate(node[2], issue)
    if kind == "or":
        return evaluate(node[1], issue) or evaluate(node[2], issue)
    if kind == "not":
        return not evaluate(node[1], issue)
    _, field, op, val = node
    vals = val if isinstance(val, list) else [val]
    empty = [str(v).upper() in ("EMPTY", "NULL") for v in vals]
    if field in ("text", "summary", "description", "comment"):
        hay = {"summary": issue["summary"], "description": plain(issue["description"]),
               "comment": " ".join(plain(c["body"]) for c in issue["comments"])}
        hay["text"] = " ".join(hay.values())
        if op not in ("~", "!~", "IS", "IS NOT"):
            raise JQLError(f"The operator '{op}' is not supported by the '{field}' field.")
        if op in ("IS", "IS NOT"):
            return (not hay[field].strip()) == (op == "IS")
        hit = text_match(hay[field], str(val))
        return hit if op == "~" else not hit
    if field in ("created", "updated", "resolved", "createddate", "updateddate"):
        if field == "resolved":
            return False if op in ("=", ">", ">=", "<", "<=") else True
        when = parse_stamp(issue["created" if field.startswith("created") else "updated"])
        ref = relative_date(val)
        return {">": when > ref, ">=": when >= ref, "<": when < ref, "<=": when <= ref,
                "=": when.date() == ref.date(), "!=": when.date() != ref.date()}.get(op, True)
    if field in ("labels", "label", "component", "components"):
        have = [x.lower() for x in issue["labels" if field.startswith("label") else "components"]]
        if op in ("IS", "IS NOT"):
            return (not have) == (op == "IS")
        hit = any(str(v).lower() in have for v in vals)
        return hit if op in ("=", "IN") else not hit
    if field in ("statuscategory",):
        cat = status_category(issue).lower()
        hit = any(str(v).lower() == cat for v in vals)
        return hit if op in ("=", "IN") else not hit
    if field == "resolution":
        resolved = issue["status"] == "Done"
        if op in ("IS", "IS NOT") or any(str(v).lower() == "unresolved" for v in vals):
            want_unresolved = (op in ("IS", "=") and (all(empty) or str(vals[0]).lower() == "unresolved"))
            return (not resolved) == want_unresolved if op in ("IS", "=") else resolved == want_unresolved
        hit = resolved and any(str(v).lower() == "done" for v in vals)
        return hit if op in ("=", "IN") else not hit
    if field in ("sprint", "parent", "epic link", "fixversion", "affectedversion"):
        return op in ("IS", "!=", "NOT IN")
    if field in ("watcher", "voter"):
        return True
    try:
        have = field_value(issue, field)
    except KeyError:
        raise JQLError(f"Field '{field}' does not exist or you do not have permission to view it.")
    if field in ("assignee", "reporter", "creator"):
        want = [None if e else resolve_user(v) for v, e in zip(vals, empty)]
    else:
        want = [None if e else str(v) for v, e in zip(vals, empty)]
    eq = lambda a, b: (a is None and b is None) or (a is not None and b is not None and str(a).lower() == str(b).lower())
    if field == "project" and not any(eq(have, w) for w in want) and op in ("=", "IN"):
        if not any(str(w).upper() == DB["project"] for w in want):
            raise JQLError(f"The value '{vals[0]}' does not exist for the field 'project'.")
    if field == "status":
        for w in want:
            if w is not None and w.lower() not in [s.lower() for s in STATUSES]:
                raise JQLError(f"The value '{w}' does not exist for the field 'status'.")
    hit = any(eq(have, w) for w in want)
    if op in ("=", "IN", "IS", "WAS"):
        return hit
    if op in ("!=", "NOT IN", "IS NOT"):
        return not hit
    raise JQLError(f"The operator '{op}' is not supported by the '{field}' field.")


def search(jql, limit):
    tree, order = parse_jql(jql)
    hits = [i for i in DB["issues"] if tree is None or evaluate(tree, i)]
    field, direction = order or ("created", "DESC")
    num = lambda i: int(i["key"].split("-")[1])
    keyfn = {"created": lambda i: parse_stamp(i["created"]), "updated": lambda i: parse_stamp(i["updated"]),
             "priority": lambda i: -PRIORITIES.index(i["priority"]), "status": lambda i: STATUSES.index(i["status"]),
             "summary": lambda i: i["summary"].lower()}.get(field, num)
    hits.sort(key=keyfn, reverse=(direction == "DESC"))
    return hits[:limit]


# --- the HTTP side: jira-cli sends absolute URLs because this server is its proxy ---

def touch(issue):
    issue["updated"] = stamp()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        with open(os.path.join(STATE, "requests.log"), "a") as f:
            f.write("%s %s\n" % (datetime.now().strftime("%H:%M:%S"), fmt % args))

    def reply(self, code, obj=None):
        body = b"" if obj is None else json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json;charset=UTF-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def error(self, code, *messages, errors=None):
        self.reply(code, {"errorMessages": list(messages), "errors": errors or {}})

    def payload(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        return json.loads(raw) if raw.strip() else {}

    def route(self, method):
        url = urlparse(self.path)
        path, query = url.path, parse_qs(url.query)
        body = self.payload() if method in ("POST", "PUT") else {}
        with LOCK:
            return self.dispatch(method, path, query, body)

    def dispatch(self, method, path, query, body):
        m = re.fullmatch(r"/rest/api/([23])(/.*)", path)
        if not m:
            return self.error(404, "The requested resource could not be found.")
        api, rest = m.groups()
        if rest in ("/search/jql", "/search"):
            try:
                hits = search(query.get("jql", [""])[0], int(query.get("maxResults", ["50"])[0]))
            except JQLError as e:
                return self.error(400, str(e))
            return self.reply(200, {"issues": [issue_json(i, api) for i in hits], "isLast": True,
                                    "startAt": 0, "maxResults": len(hits), "total": len(hits)})
        if rest == "/issue" and method == "POST":
            return self.create(body)
        if rest == "/issueLinkType":
            return self.reply(200, {"issueLinkTypes": [{"id": str(10000 + n), "name": t[0], "inward": t[1], "outward": t[2]}
                                                       for n, t in enumerate(LINK_TYPES)]})
        if rest == "/issueLink" and method == "POST":
            return self.link(body)
        if rest.startswith("/user/assignable/search") or rest.startswith("/user/search"):
            q = query.get("query", query.get("username", [""]))[0].lower()
            return self.reply(200, [user_json(e) for e, u in USERS.items()
                                    if q in e.lower() or q in u["name"].lower()])
        if rest == "/myself":
            return self.reply(200, user_json(ME["email"]))
        m = re.fullmatch(r"/issue/([A-Za-z]+-\d+)(/[a-z]+)?", rest)
        if not m:
            return self.error(404, "The requested resource could not be found.")
        issue = find(m.group(1))
        if issue is None:
            return self.error(404, "Issue does not exist or you do not have permission to see it.")
        sub = m.group(2) or ""
        if sub == "" and method == "GET":
            return self.reply(200, issue_json(issue, api))
        if sub == "" and method == "PUT":
            return self.edit(issue, body)
        if sub == "/transitions":
            return self.transition(issue, method, body)
        if sub == "/comment" and method == "POST":
            issue["comments"].append({"author": ME["email"], "created": stamp(), "body": stored(body.get("body"))})
            touch(issue)
            return self.reply(201, {"id": str(10000 + len(issue["comments"]))})
        if sub == "/assignee" and method == "PUT":
            account = body.get("accountId") or body.get("name")
            issue["assignee"] = None if account in (None, "-1") else user_by_account(account)
            touch(issue)
            return self.reply(204)
        if sub == "/worklog" and method == "POST":
            return self.reply(201, {"id": "1"})
        if sub == "/watchers":
            return self.reply(204)
        return self.error(404, "The requested resource could not be found.")

    def create(self, body):
        f = body.get("fields", {})
        if f.get("project", {}).get("key", DB["project"]).upper() != DB["project"]:
            return self.error(400, errors={"project": "valid project is required"})
        if not f.get("summary"):
            return self.error(400, errors={"summary": "You must specify a summary of the issue."})
        number = max(int(i["key"].split("-")[1]) for i in DB["issues"]) + 1
        key = f"{DB['project']}-{number}"
        assignee = f.get("assignee") or {}
        DB["issues"].append({
            "key": key, "type": f.get("issuetype", {}).get("name", "Task"), "status": "To Do",
            "priority": (f.get("priority") or {}).get("name", "Medium"), "summary": f["summary"],
            "description": stored(f["description"]) if f.get("description") else None, "reporter": ME["email"],
            "assignee": user_by_account(assignee.get("accountId")),
            "labels": f.get("labels", []), "components": [c.get("name") for c in f.get("components", [])],
            "created": stamp(), "updated": stamp(), "comments": [], "links": [], "watchers": 1,
        })
        return self.reply(201, {"id": str(number), "key": key, "self": f"{DB['server']}/rest/api/3/issue/{number}"})

    def edit(self, issue, body):
        f = body.get("fields", {})
        if "summary" in f:
            issue["summary"] = f["summary"]
        if "description" in f:
            issue["description"] = stored(f["description"]) if f["description"] else None
        if "priority" in f:
            issue["priority"] = f["priority"]["name"]
        for op in body.get("update", {}).get("labels", []):
            if "add" in op and op["add"] not in issue["labels"]:
                issue["labels"].append(op["add"])
            if "remove" in op and op["remove"] in issue["labels"]:
                issue["labels"].remove(op["remove"])
        if "labels" in f:
            issue["labels"] = f["labels"]
        touch(issue)
        return self.reply(204)

    def transition(self, issue, method, body):
        targets = [s for s in STATUSES if s != issue["status"]]
        if method == "GET":
            return self.reply(200, {"expand": "transitions", "transitions": [
                {"id": str(11 + STATUSES.index(s) * 10), "name": s, "isAvailable": True, "hasScreen": False,
                 "to": status_json(s)} for s in targets]})
        tid = str(body.get("transition", {}).get("id"))
        to = next((s for s in targets if str(11 + STATUSES.index(s) * 10) == tid), None)
        if to is None:
            return self.error(400, f"Transition id '{tid}' is not valid for this issue.")
        issue["status"] = to
        for op in body.get("update", {}).get("comment", []):
            if "add" in op:
                issue["comments"].append({"author": ME["email"], "created": stamp(), "body": stored(op["add"]["body"])})
        touch(issue)
        return self.reply(204)

    def link(self, body):
        name = body.get("type", {}).get("name", "")
        t = next((t for t in LINK_TYPES if t[0].lower() == name.lower()), None)
        inward, outward = find(body.get("inwardIssue", {}).get("key", "")), find(body.get("outwardIssue", {}).get("key", ""))
        if t is None or inward is None or outward is None:
            return self.error(404, "No issue link type with name '%s' found." % name if t is None else "Issue does not exist or you do not have permission to see it.")
        inward["links"].append({"type": t[2], "key": outward["key"]})
        outward["links"].append({"type": t[1], "key": inward["key"]})
        touch(inward)
        touch(outward)
        return self.reply(201)

    def do_GET(self):
        self.route("GET")

    def do_POST(self):
        self.route("POST")

    def do_PUT(self):
        self.route("PUT")

    def do_DELETE(self):
        self.reply(204)


# --- the bridge: run the real jira-cli on each call the sandboxed shell spools ---

def run_spooled(proxy):
    env = {"PATH": os.environ["PATH"], "HOME": os.environ["HOME"], "LANG": os.environ.get("LANG", "en_US.UTF-8"),
           "JIRA_CONFIG_FILE": CONFIG, "JIRA_API_TOKEN": "eval-token", "HTTP_PROXY": proxy, "http_proxy": proxy}
    while True:
        for name in sorted(os.listdir(SPOOL)):
            req = os.path.join(SPOOL, name)
            if not name.endswith(".req") or os.path.exists(os.path.join(req, "code")):
                continue
            try:
                answer(req, env)
            except OSError:  # the caller collected its answer and removed the request meanwhile
                pass
        time.sleep(0.05)


def answer(req, env):
    args = open(os.path.join(req, "args"), "rb").read().split(b"\0")[:-1]
    cwd = open(os.path.join(req, "cwd")).read().strip()
    env["TERM"] = open(os.path.join(req, "term")).read().strip() or "dumb"
    stdin_path = os.path.join(req, "stdin")
    stdin = open(stdin_path, "rb") if os.path.exists(stdin_path) else subprocess.DEVNULL
    try:
        p = subprocess.run(["jira"] + [a.decode() for a in args], env=env, stdin=stdin, capture_output=True,
                           cwd=cwd if os.path.isdir(cwd) else os.environ["HOME"], timeout=60)
        out, err, code = p.stdout, p.stderr, p.returncode
    except subprocess.TimeoutExpired:
        out, err, code = b"", b"jira: timed out after 60s\n", 124
    finally:
        if stdin is not subprocess.DEVNULL:
            stdin.close()
    open(os.path.join(req, "out"), "wb").write(out)
    open(os.path.join(req, "err"), "wb").write(err)
    open(os.path.join(req, "code.tmp"), "w").write(str(code))
    os.rename(os.path.join(req, "code.tmp"), os.path.join(req, "code"))


def main():
    os.makedirs(SPOOL, exist_ok=True)
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    threading.Thread(target=run_spooled, args=(f"http://127.0.0.1:{httpd.server_address[1]}",), daemon=True).start()
    deadline = time.time() + 3 * 3600
    while time.time() < deadline:
        try:
            os.stat(STATE)
        except OSError:
            break
        time.sleep(2)


if __name__ == "__main__":
    main()
