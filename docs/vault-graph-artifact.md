# Knowledge-vault graph artifact — how it was built

A recipe for turning a `docs/project-knowledge/` wikilink vault into a self-contained, shareable HTML artifact (a Claude Artifact) with three views: a clustered **graph**, a per-note **neighborhood**, and a **health** dashboard. Built as a proof of concept against the Paper Lives / symdocs vault (187 notes, 1,383 links, 9 categories). This is the reproducible method, not the throwaway code.

The design premise (established in discussion, worth keeping): the vault is a **graph, not a folder tree**. Notes are filed flat by kind (`constraints/`, `decisions/`, `components/`…) but the real structure — and the way an agent traverses — is the wikilink mesh radiating from hub notes. So the artifact visualizes the graph and its communities, not the directory layout.

## Pipeline overview

1. Extract the vault to one JSON graph.
2. Render it in a single self-contained HTML file (Canvas + inline data).
3. Three views behind a mode toggle.
4. The "cities" graph layout (the interesting part).
5. Verify browser-free.
6. Publish to a stable URL.

## 1. Extract the graph

A script walks `docs/project-knowledge/**/*.md` and emits one compact JSON. That JSON is the only input the viz ever reads — the vault is never touched again.

Per note, capture:

- **id** — filename without `.md`
- **category** — parent directory
- **title** — first `# ` heading (fallback: id)
- **status** — a `> Status:` banner or frontmatter `status:`
- **has_reusable** — whether a `## Reusable surface` section exists
- **links** — every `[[wikilink]]`, stripping `|alias` and `#anchor`

Then resolve: links to known ids become **edges**; unresolved targets increment a **dangling** counter (these are usually ticket IDs or renamed/stub notes). Derive **in/out degree**, **orphans** (deg 0), **category counts**, and **top-referenced hubs**.

Core of the extractor (Python):

```python
import os, re, json, collections
VAULT = "docs/project-knowledge"
link_re    = re.compile(r"\[\[([^\]]+)\]\]")
h1_re      = re.compile(r"^#\s+(.+)$", re.M)
status_re  = re.compile(r"^>\s*\*{0,2}Status:?\*{0,2}\s*(.+)$", re.M | re.I)
reusable_re = re.compile(r"^##+\s+Reusable surface", re.M | re.I)

notes = {}
for root, dirs, files in os.walk(VAULT):
    dirs[:] = [d for d in dirs if not d.startswith(".")]      # skip .obsidian etc
    for f in files:
        if not f.endswith(".md"): continue
        rel = os.path.relpath(os.path.join(root, f), VAULT)
        category = rel.split(os.sep)[0] if os.sep in rel else "_root"
        text = open(os.path.join(root, f), encoding="utf-8", errors="replace").read()
        links = [m.split("|")[0].split("#")[0].strip() for m in link_re.findall(text)]
        notes[f[:-3]] = {
            "category": category,
            "title": (h1_re.search(text) or [None, f[:-3]])[1] if h1_re.search(text) else f[:-3],
            "status": (status_re.search(text).group(1).strip() if status_re.search(text) else None),
            "has_reusable": bool(reusable_re.search(text)),
            "links": [l for l in links if l],
        }

ids = set(notes)
edges, dangling = [], collections.Counter()
for nid, n in notes.items():
    for tgt in dict.fromkeys(n["links"]):                     # dedup, keep order
        (edges.append([nid, tgt]) if tgt in ids else dangling.update([tgt]))
indeg = collections.Counter(t for _, t in edges)
for nid, n in notes.items():
    n["in_deg"]  = indeg.get(nid, 0)
    n["out_deg"] = len([t for t in dict.fromkeys(n["links"]) if t in ids])
    del n["links"]

out = {
    "total": len(notes),
    "categories": dict(collections.Counter(n["category"] for n in notes.values())),
    "edge_count": len(edges),
    "dangling": dict(dangling.most_common()),
    "orphans": [n for n in notes if notes[n]["in_deg"] == 0 and notes[n]["out_deg"] == 0],
    "top_referenced": [n for n, _ in indeg.most_common(15)],
    "notes": notes, "edges": edges,
}
json.dump(out, open("vault_data.json", "w"))
```

## 2. Self-contained artifact shell

Claude Artifacts run under a strict CSP: no external requests at all (no CDN scripts, webfonts, or remote images). So:

- One HTML file, everything inline. System-font stacks only (no webfont → no silent fallback). Monospace as the characterful face — it's the vernacular of ADR IDs and form hashes.
- **The ~150 KB JSON is embedded inline.** Build trick: keep a template with a `__VAULT_DATA__` placeholder and a one-line inject step (`template.replace("__VAULT_DATA__", data)`) that writes the final file. This keeps the data blob out of the file you hand-edit; re-inject on every change.
- **Canvas** renders the graph (not SVG/DOM — 187 nodes / 1,383 edges pan and zoom cheaply). HTML/CSS renders the chrome: masthead, side rail, legend, note detail card, health panel.
- **Theme-aware:** define the palette as CSS custom properties, redefine them under `@media (prefers-color-scheme)` and `:root[data-theme=...]`, and read them into the canvas at draw time via `getComputedStyle(document.documentElement).getPropertyValue('--x')` so the graph recolors on the viewer's theme toggle (a `MutationObserver` on `data-theme` triggers a redraw).
- One `{scale, tx, ty}` world↔screen transform underpins everything: `toScreen`, `toWorld`, wheel-zoom-to-cursor, drag-to-pan.

## 3. Three views

A single `mode` variable (`graph` | `ego` | `health`) with a `render()` dispatch. Search, the category legend (a color key that also filters), and the detail card are shared. For `health` the canvas is hidden and an HTML dashboard is shown.

- **Graph** — the whole mesh, clustered into cities (below).
- **Neighborhood (ego)** — rooted at one note; its 1-hop neighbors grouped by category as a small rooted tree. Filled dot = the focus links out to it; hollow ring = it references the focus. Click any note to re-root and walk the graph hop by hop — this mirrors how an agent traverses from a hub note.
- **Health** — derived hygiene stats as cards: busiest hubs, dangling references, thinly-connected notes (deg ≤ 2), and component/architecture notes missing a `## Reusable surface`. Every row links into that note's neighborhood.

## 4. The "cities" graph layout

The reusable core. Goal: notes cluster by **community** (which component's world they live in), sized by importance, with the index on top and no overlap.

1. **Community assignment.** Each note joins the city of the component it links to most: count its links (in + out) to `components`-category nodes, take the max (tie-break by that component's degree). Components are their own centers; the index (`_index`) is pinned special; notes with no component link form small `island:<category>` communities (customers, plan, research…).
2. **Size + rank.** City radius `r = 52 + sqrt(memberCount) * 24`. Sort cities by member count descending and **row-pack** them into rows of max width ~1900: biggest cities fill the top rows (nearest the index), smallest cascade to the bottom. Packing reserves `2r + gap` per city, so nothing in a row overlaps and rows are separated by `max(rowHeight) + gap`.
3. **Deterministic placement.** Lay each city's notes in a packed disk (golden-angle spiral) *inside* `0.8 · r`, component at the center: `rad = 0.8r · sqrt((j+0.4)/m)`, `angle = j · 2.39996`. Because every note stays within the reserved disk and cities are spaced by their full radii plus a gap, overlap is **geometrically impossible** — not a settling process that can fail. The index is pinned above the top row; its edges fan down to everything it references.
4. **Node size.** Log scale of total degree over the real range (here 2→180): `r = 2.4 + 19 · (ln(deg+1) − ln(dmin+1)) / (ln(dmax+1) − ln(dmin+1))`. Plain `sqrt` compressed the heavy tail and made most dots lookalikes; log gives leaves tiny dots, mid-notes clearly bigger, and hubs (the index, big components) dominant.

Colour encodes **kind** (category); position encodes **community** (which component) — the two orthogonal axes made visual.

### The load-bearing lesson

The first attempt used a **force simulation** with per-community anchors. It reserved the space correctly, then edge springs dragged cross-linked nodes back across city lines until clusters stacked on top of each other. **Force layout is great for organic exploration but fights any hard constraint you impose** (non-overlap, fixed hierarchy). When you need stable, non-overlapping, ranked structure, place deterministically instead. That single switch — force sim → packed disks — is what fixed the overlap for good.

## 5. Verify browser-free

The real browser was unavailable the whole build (locked by another session), so verification was:

- `node --check` on the extracted `<script>` for syntax.
- A **headless DOM + Canvas stub** (~80 lines) that defines just enough `document`, `window`, `canvas.getContext('2d')`, `getComputedStyle`, `requestAnimationFrame`, and `MutationObserver` to `eval` the whole script, then fires each mode-switch button, a search, and pointer events. This executes every code path and catches runtime errors (undefined refs, bad property access) that a syntax check misses. It proves the code *runs*; it does not verify pixels.
- The layout math was validated separately in Python: replicate the row-packing and assert the expected number of rows and zero horizontal overlaps before publishing.

## 6. Publish

Use the Artifact tool pointed at the final HTML file. Redeploying the **same file path** re-publishes to the **same URL**, so every iteration keeps one stable link. Set a stable `<title>` and favicon; keep them constant across redeploys so the artifact reads as the same page.

## Techniques worth reaching for again

- **Placeholder-inject** for large embedded data in a self-contained page.
- **Canvas + CSS-variable colours** = theme-aware generative graphics.
- **Deterministic clustering** (community → size-rank → row-pack → disk) over a force sim whenever overlap or a fixed hierarchy is required.
- **Log sizing** for heavy-tailed degree distributions.
- **Headless script execution** as a smoke test when you can't render.
- **Colour for kind, position for community** — encode two axes at once instead of collapsing them.
