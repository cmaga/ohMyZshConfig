#!/usr/bin/env node
import fs from "node:fs";
import process from "node:process";

const RULE =
	"Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.";
const LANES = /Ten lanes on `[^`<>]+` at the PR head/;
const SUB_BLOCKS = [
	"Depends on.",
	"Files.",
	"Build.",
	"You see.",
	"Verify, unit.",
	"Verify, live.",
	"Verify, perf.",
	"Review gate.",
	"Merge.",
];
const PROGRAM_H3 = ["File the tickets", "PR mechanics", "Verdict and merge", "Boot recipe"];
const PROGRAM_MARKERS = ["`ticket-provider` skill", "is blocked by", "Open no order"];
const HOW_TO_READ_MARKERS = [
	"One box is one unit of work",
	"names the evidence",
	"Check a box only when its evidence exists",
	"one ticket and one order",
	RULE,
];
const PERF_ITEMS = ["Metric.", "Probe.", "Baseline.", "Rule."];
const BOX = /^\s*- \[[ x]\] (.*)$/;

const file = process.argv[2];
const specFile = process.argv[3];
if (!file) {
	console.error("Usage: node check-plan.mjs <plan.md> [<spec.md>]");
	process.exit(2);
}

const problems = [];
const fail = (line, message) => problems.push(`${file}:${line}: ${message}`);

const openingFence = (text) => {
	const match = text.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
	if (!match || (match[1][0] === "`" && match[2].includes("`"))) return null;
	return { char: match[1][0], length: match[1].length };
};
const closingFence = (text, opening) => {
	const match = text.match(/^ {0,3}(`+|~+)[ \t]*$/);
	return Boolean(
		match &&
		match[1][0] === opening.char &&
		match[1].length >= opening.length,
	);
};
const readLines = (path) => {
	const raw = fs.readFileSync(path, "utf8").split(/\r?\n/);
	let start = 0;
	if (raw[0] === "---") {
		start = raw.indexOf("---", 1) + 1;
	}
	const out = [];
	let fence = null;
	for (let i = start; i < raw.length; i++) {
		const text = raw[i];
		let code = Boolean(fence);
		if (fence && closingFence(text, fence)) {
			code = false;
			fence = null;
		} else if (!fence) {
			fence = openingFence(text);
			code = Boolean(fence);
		}
		out.push({ n: i + 1, text, code });
	}
	return out;
};

// Drops code lines and HTML comments, leaving the lines a plan's markup lives in.
const stripComments = (all) => {
	const out = [];
	let open = false;
	for (const l of all) {
		if (l.code) continue;
		let rest = l.text;
		let kept = "";
		while (rest) {
			if (open) {
				const end = rest.indexOf("-->");
				open = end === -1;
				rest = end === -1 ? "" : rest.slice(end + 3);
			} else {
				const at = rest.indexOf("<!--");
				kept += at === -1 ? rest : rest.slice(0, at);
				open = at !== -1;
				rest = at === -1 ? "" : rest.slice(at + 4);
			}
		}
		out.push({ n: l.n, text: kept });
	}
	return out;
};

const IMPLEMENTATION_TITLE = /: implementation plan$/;
const DEPLOYMENT_FIELDS = ["Forced by", "Proof", "Touches", "Recipe"];
const RECIPES = ["feature", "refactor", "bug-fix", "perf"];
const TASK_FIELDS = ["Depends on", "Files", "Consumes", "Produces", "Decisions", "Work"];
const FIELD = /^- \*\*([^*]+?):\*\*\s*(.*)$/;
const TASK_ID = /^D(\d+)\.P(\d+)\.T(\d+)$/;
const TABLE_SECTIONS = new Map([
	["Coverage", false],
	["Checks today's code performs", true],
	["Behavior in code the build deletes or rewrites", true],
]);
const SPEC_ID = /\*\*((?:FR|NFR)-\d+|[CX]-\d+\.T?\d+):\*\*/g;

const list = (value) => value.split(",").map((v) => v.trim());
const decsIn = (text) => text.match(/DEC-\d+/g) ?? [];
const tableCells = (text) => text.replace(/^\s*\||\|\s*$/g, "").split("|").map((c) => c.trim());

const parseImplementation = (content) => {
	const plan = { decisions: [], deployments: [], tables: [], sections: new Map() };
	let section = null;
	let dep = null;
	let phase = null;
	let task = null;
	let table = null;
	for (const { n, text } of content) {
		let m;
		if (text.startsWith("## ")) {
			section = text.slice(3).trim();
			plan.sections.set(section, n);
			dep = phase = task = table = null;
			if ((m = section.match(/^Deployment (\d+): \S/))) {
				dep = { n, num: Number(m[1]), phases: [], fields: new Map() };
				plan.deployments.push(dep);
			} else if (/^Deployment\b/.test(section)) {
				fail(n, `deployment heading "## ${section}" is not "## Deployment N: <title>"`);
			}
			continue;
		}
		if (dep && text.startsWith("### ")) {
			task = null;
			if ((m = text.match(/^### Phase (\d+): (\S.*)$/))) {
				phase = { n, num: Number(m[1]), name: m[2].trim(), tasks: [], fields: new Map() };
				dep.phases.push(phase);
			} else {
				phase = null;
				fail(n, `phase heading "${text}" is not "### Phase N: <name>"`);
			}
			continue;
		}
		if (dep && text.startsWith("#### ")) {
			if (phase && (m = text.match(/^#### (D(\d+)\.P(\d+)\.T(\d+)): \S/))) {
				task = { n, id: m[1], d: Number(m[2]), p: Number(m[3]), dep, phase, fields: new Map() };
				phase.tasks.push(task);
			} else {
				task = null;
				fail(n, `task heading "${text}" is not "#### D<n>.P<n>.T<n>: <title>" inside a phase`);
			}
			continue;
		}
		if ((m = text.match(FIELD))) {
			const target = task ?? phase ?? dep;
			if (target) target.fields.set(m[1], { n, value: m[2].trim() });
			else if (section === "Decisions") plan.decisions.push({ n, id: m[1] });
			continue;
		}
		if (!dep && text.startsWith("|")) {
			const cells = tableCells(text);
			if (!table) {
				table = { section, n, header: cells, rows: [] };
				plan.tables.push(table);
			} else if (!cells.every((c) => /^:?-+:?$/.test(c))) {
				table.rows.push({ n, cells });
			}
		} else {
			table = null;
		}
	}
	return plan;
};

const overlaps = (a, b) => {
	const x = a.replace(/\/$/, "");
	const y = b.replace(/\/$/, "");
	return x === y || x.startsWith(`${y}/`) || y.startsWith(`${x}/`);
};

const checkImplementation = (plan, spec) => {
	const tasks = plan.deployments.flatMap((dep) => dep.phases.flatMap((phase) => phase.tasks));
	const taskById = new Map(tasks.map((t) => [t.id, t]));
	const listed = new Set(plan.decisions.map((d) => d.id));
	const field = (owner, name) => owner.fields.get(name);
	const missing = (owner, name) => !field(owner, name)?.value;

	plan.deployments.forEach((dep, i) => {
		const label = `Deployment ${dep.num}`;
		if (dep.num !== i + 1) fail(dep.n, `${label} is number ${i + 1} in the plan`);
		for (const name of DEPLOYMENT_FIELDS) {
			if (missing(dep, name)) fail(dep.n, `${label} lacks a "- **${name}:**" line`);
		}
		const recipe = field(dep, "Recipe");
		if (recipe?.value && !RECIPES.includes(recipe.value)) {
			fail(recipe.n, `${label} Recipe "${recipe.value}" is not one of ${RECIPES.join(", ")}`);
		}
		const first = dep.phases[0];
		if (!first || first.num !== 1 || first.name.toLowerCase() !== "skeleton") {
			fail(first?.n ?? dep.n, `${label} Phase 1 is not named Skeleton`);
		} else if (first.tasks.length !== 1) {
			fail(first.n, `${label} Phase 1 holds ${first.tasks.length} tasks, not exactly one`);
		}
	});

	plan.deployments.forEach((dep, di) => {
		dep.phases.forEach((phase, pi) => {
			const where = `Deployment ${dep.num} Phase ${phase.num}`;
			if (phase.num !== pi + 1) fail(phase.n, `${where} is phase ${pi + 1} of its deployment`);
			if (phase.tasks.length > 1 && !field(phase, "Fan-out")?.value) {
				fail(phase.n, `${where} holds ${phase.tasks.length} tasks and has no "- **Fan-out:**" line`);
			}
			if (phase.tasks.length > 3) fail(phase.n, `${where} holds ${phase.tasks.length} tasks, more than three`);

			for (const t of phase.tasks) {
				if (t.d !== dep.num || t.p !== phase.num) fail(t.n, `${t.id} sits under Deployment ${dep.num} Phase ${phase.num}`);
				for (const name of TASK_FIELDS) {
					if (missing(t, name)) fail(t.n, `${t.id} lacks a "- **${name}:**" line`);
				}
				for (const name of ["Depends on", "Consumes", "Produces"]) {
					const f = field(t, name);
					if (f?.value && f.value !== "none" && list(f.value).includes("")) {
						fail(f.n, `${t.id} ${name} is not "none" or a comma-separated list`);
					}
				}
				const files = field(t, "Files");
				if (files?.value && !list(files.value).every((p) => /^`[^`\s]+`$/.test(p))) {
					fail(files.n, `${t.id} Files is not a comma-separated list of backticked paths`);
				}
				const depends = field(t, "Depends on");
				if (depends?.value && depends.value !== "none") {
					for (const id of list(depends.value)) {
						const target = taskById.get(id);
						if (!target) fail(depends.n, `${t.id} depends on ${id}, which does not exist`);
						else if (!(di > plan.deployments.indexOf(target.dep) || (target.dep === dep && pi > dep.phases.indexOf(target.phase)))) {
							fail(depends.n, `${t.id} depends on ${id}, in its own phase or a later one`);
						}
					}
				}
				for (const name of TASK_FIELDS) {
					for (const id of decsIn(field(t, name)?.value ?? "")) {
						if (!listed.has(id)) fail(field(t, name).n, `${t.id} cites ${id}, which is not listed under Decisions`);
					}
				}
			}

			const filesOf = (t) => (field(t, "Files")?.value ?? "").split(",").map((p) => p.trim().replace(/`/g, "")).filter(Boolean);
			phase.tasks.forEach((a, i) => {
				for (const b of phase.tasks.slice(i + 1)) {
					const shared = filesOf(a).flatMap((x) => filesOf(b).filter((y) => overlaps(x, y)).map((y) => (x === y ? x : `${x} and ${y}`)));
					if (shared.length) fail(b.n, `${a.id} and ${b.id} share a file in one phase: ${shared[0]}`);
					for (const id of decsIn(field(a, "Produces")?.value ?? "")) {
						if (decsIn(field(b, "Consumes")?.value ?? "").includes(id)) fail(b.n, `${a.id} produces ${id}, which ${b.id} consumes in the same phase`);
					}
					for (const id of decsIn(field(b, "Produces")?.value ?? "")) {
						if (decsIn(field(a, "Consumes")?.value ?? "").includes(id)) fail(b.n, `${b.id} produces ${id}, which ${a.id} consumes in the same phase`);
					}
				}
			});
		});
	});

	const column = (table, name) => {
		const at = table.header.indexOf(name);
		if (at === -1) fail(table.n, `${table.section} table has no ${name} column`);
		return at;
	};
	for (const table of plan.tables) {
		for (const row of table.rows) {
			for (const id of decsIn(row.cells.join(" "))) {
				if (!listed.has(id)) fail(row.n, `${table.section} row cites ${id}, which is not listed under Decisions`);
			}
		}
		if (!TABLE_SECTIONS.has(table.section)) continue;
		const at = column(table, "Task");
		if (at === -1) continue;
		for (const row of table.rows) {
			for (const id of list(row.cells[at] ?? "")) {
				if (id === "-" && TABLE_SECTIONS.get(table.section)) continue;
				if (!taskById.has(id)) fail(row.n, `${table.section} row names task "${id}", which does not exist`);
			}
		}
	}

	if (spec) {
		const coverage = plan.tables.find((t) => t.section === "Coverage");
		const at = coverage ? column(coverage, "Spec item") : -1;
		const covered = new Set(coverage && at !== -1 ? coverage.rows.flatMap((r) => list(r.cells[at] ?? "")) : []);
		const line = plan.sections.get("Coverage") ?? 1;
		for (const { text } of spec) {
			for (const m of text.matchAll(SPEC_ID)) {
				if (!covered.has(m[1])) fail(line, `spec id ${m[1]} is missing from the Coverage table`);
			}
		}
	}
};

const lines = readLines(file);
const content = stripComments(lines);
const title = content.find((l) => l.text.startsWith("# "));
if (title && IMPLEMENTATION_TITLE.test(title.text.trim())) {
	checkImplementation(parseImplementation(content), specFile && stripComments(readLines(specFile)));
	for (const p of problems) console.error(p);
	process.exit(problems.length ? 1 : 0);
}

for (const l of lines) {
	if (l.code) continue;
	const prose = l.text
		.replace(/(?<!`)(`+)(?!`)(.*?)(?<!`)\1(?!`)/g, "`")
		.replace(/!\[[^\]]*\]\([^)]*\)/g, "")
		.replace(/\]\([^)]*\)/g, "]");
	if (/[–—]/.test(prose)) fail(l.n, "long dash");
	if (/[‘’“”]/.test(prose)) fail(l.n, "curly quote");
	if (/: \S/.test(prose)) fail(l.n, "mid-sentence colon");
}

const h2 = (l) => (!l.code && l.text.startsWith("## ") ? l.text.slice(3).trim() : null);
const sections = [];
for (const l of lines) {
	const title = h2(l);
	if (title !== null) sections.push({ title, n: l.n, body: [] });
	else if (sections.length) sections.at(-1).body.push(l);
}
const find = (title) => sections.find((s) => s.title === title);
const bodyText = (s) => s.body.map((l) => l.text).join("\n");
const boxes = (ls) => ls.filter((l) => !l.code && BOX.test(l.text)).map((l) => ({ n: l.n, text: l.text.match(BOX)[1] }));

const h1 = lines.findIndex((l) => !l.code && l.text.startsWith("# "));
if (h1 === -1) fail(1, "no H1 title");
const howToRead = find("How to read this");
if (!howToRead) fail(1, 'no "## How to read this" section');
if (h1 !== -1 && howToRead) {
	const intro = lines.slice(h1 + 1).filter((l) => l.n < howToRead.n && l.text.trim() !== "");
	if (intro.length >= 10) fail(lines[h1].n, `intro is ${intro.length} lines, under ten required`);
	for (const marker of HOW_TO_READ_MARKERS) {
		if (!bodyText(howToRead).includes(marker)) fail(howToRead.n, `How to read this lacks "${marker}"`);
	}
}

const program = find("Program checklist");
if (!program) fail(1, 'no "## Program checklist" section');
else {
	const h3s = program.body.filter((l) => !l.code && l.text.startsWith("### ")).map((l) => l.text.slice(4).trim());
	let cursor = 0;
	for (const name of PROGRAM_H3) {
		const at = h3s.findIndex((t, i) => i >= cursor && t.startsWith(name));
		if (at === -1) fail(program.n, `Program checklist lacks "### ${name}" in order`);
		else cursor = at + 1;
	}
	for (const marker of PROGRAM_MARKERS) {
		if (!bodyText(program).includes(marker)) fail(program.n, `Program checklist lacks "${marker}"`);
	}
}

const close = find("Close the program");
if (!close) fail(1, 'no "## Close the program" section');
const programIndex = sections.indexOf(program);
const closeIndex = sections.indexOf(close);
const prSections = programIndex === -1 || closeIndex === -1 ? [] : sections.slice(programIndex + 1, closeIndex);
if (prSections.length === 0) fail(1, "no PR sections between Program checklist and Close the program");

const report = [];
for (const pr of prSections) {
	const heads = [];
	for (const l of pr.body) {
		if (l.code) continue;
		const m = l.text.match(/^\*\*([^*]+)\*\*(.*)$/);
		if (m && SUB_BLOCKS.includes(m[1])) heads.push({ name: m[1], n: l.n, rest: m[2].trim(), lines: [] });
		else if (heads.length) heads.at(-1).lines.push(l);
	}
	const names = heads.map((h) => h.name);
	if (names.join("|") !== SUB_BLOCKS.join("|")) {
		fail(pr.n, `${pr.title}: sub-blocks are [${names.join(", ")}], expected [${SUB_BLOCKS.join(", ")}]`);
	}
	const block = (name) => heads.find((h) => h.name === name);
	const counts = {};
	for (const h of heads) counts[h.name] = boxes(h.lines).length;

	const depends = block("Depends on.");
	if (depends && depends.rest === "") fail(depends.n, `${pr.title}: Depends on names nothing`);
	for (const name of ["Files.", "Build.", "You see.", "Verify, unit.", "Merge."]) {
		const b = block(name);
		if (b && boxes(b.lines).length === 0) fail(b.n, `${pr.title}: ${name} has no box`);
	}
	for (const name of ["Verify, unit.", "Verify, live.", "Verify, perf."]) {
		const b = block(name);
		if (b && !b.rest.startsWith(RULE)) fail(b.n, `${pr.title}: ${name} does not open with the rule`);
	}

	const live = block("Verify, live.");
	if (live) {
		if (!LANES.test(live.rest)) fail(live.n, `${pr.title}: Verify, live lacks "Ten lanes on \`<verify role model>\` at the PR head" with the model filled in`);
		const lanes = boxes(live.lines).map((b) => ({ ...b, m: b.text.match(/^Lane (\d+)\. /) }));
		const numbers = lanes.filter((b) => b.m).map((b) => Number(b.m[1])).sort((a, b) => a - b);
		if (numbers.join(",") !== "1,2,3,4,5,6,7,8,9,10") fail(live.n, `${pr.title}: lanes are [${numbers.join(",")}], expected 1 to 10`);
		for (const lane of lanes) {
			if (!lane.m) fail(lane.n, `${pr.title}: live box is not a lane`);
			else if (!/Save `[^`]+`/.test(lane.text)) fail(lane.n, `${pr.title}: lane ${lane.m[1]} names no screenshot`);
			else if (!lane.text.includes("Pass when")) fail(lane.n, `${pr.title}: lane ${lane.m[1]} has no pass predicate`);
		}
	}

	const perf = block("Verify, perf.");
	if (perf) {
		const items = boxes(perf.lines).map((b) => b.text.split(" ")[0]);
		if (items.join("|") !== PERF_ITEMS.join("|")) fail(perf.n, `${pr.title}: perf boxes are [${items.join(", ")}], expected [${PERF_ITEMS.join(", ")}]`);
	}

	const gate = block("Review gate.");
	if (gate) {
		const gateBoxes = boxes(gate.lines);
		if (gate.rest.startsWith("None.")) {
			if (gateBoxes.length) fail(gate.n, `${pr.title}: Review gate says None but has boxes`);
		} else {
			const text = gate.lines.map((l) => l.text).join("\n");
			if (gateBoxes.length === 0) fail(gate.n, `${pr.title}: Review gate has no box`);
			for (const word of ["screenshot", "video", "user"]) {
				if (!text.includes(word)) fail(gate.n, `${pr.title}: Review gate lacks "${word}"`);
			}
		}
	}

	const total = boxes(pr.body).length;
	const cells = SUB_BLOCKS.filter((s) => s !== "Depends on.").map((s) => `${s.replace(/[ ,.]+/g, "-").replace(/-$/, "").toLowerCase()}=${counts[s] ?? 0}`);
	report.push(`${pr.title}  boxes=${total}  ${cells.join(" ")}`);
}

if (closeIndex !== -1) {
	const tail = sections.slice(closeIndex + 1);
	for (const s of tail) {
		if (!s.title.startsWith("Appendix")) fail(s.n, `"## ${s.title}" after Close the program is not an appendix`);
	}
	if (!tail.some((s) => s.title.includes("Prototype evidence"))) fail(close.n, 'no "## Appendix ... Prototype evidence" section');
}

for (const line of report) console.log(line);
console.log(`${prSections.length} PR sections, ${problems.length} problems`);
for (const p of problems) console.error(p);
process.exit(problems.length ? 1 : 0);
