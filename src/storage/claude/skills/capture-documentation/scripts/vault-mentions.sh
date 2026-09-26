#!/usr/bin/env bash
# vault-mentions.sh - report unlinked mentions of note names (read-only; the scribe converts).
# Usage: vault-mentions.sh VAULT_ROOT [--all]
# Terms per note: ADR-NNN id; filename slug minus bucket prefix (dashes -> spaces);
# H1 title of <=4 words (minus "ADR-NNN:", "Research:", leading "The"); frontmatter aliases
# (accepts both "aliases: [a, b]" and "aliases: a, b").
# Scanned text excludes frontmatter, headings, fenced/inline code, [[...]], and [..](..) links.
# A source note that already links the target anywhere is skipped (one link per note suffices).
# _index.md and glossary.md are skipped as sources (a hub mentioning a note is not a missing
# link the scribe should wrap) and contribute no terms as targets (hubs have no terms).
# Output: TIER<TAB>source:line<TAB>[[target]]<TAB>"term"<TAB>snippet   (HIGH = multiword or ADR id)
# Single-word terms are LOW and suppressed unless --all.
set -u
ROOT="${1:?usage: vault-mentions.sh VAULT_ROOT [--all]}"; ALL="${2:-}"
[ -d "$ROOT" ] || exit 2
find "$ROOT" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.cache/*' -print0 |
  LC_ALL=C sort -z |
  xargs -0 awk -v all="$ALL" '
function slugterm(b,  t){ t=b; sub(/^(architecture|constraint|domain|policy|customer|persona|research)-/,"",t)
  if (t ~ /^ADR-[0-9]+-/) sub(/^ADR-[0-9]+-/,"",t); gsub(/-/," ",t); return tolower(t) }
function addterm(b,t){ t=tolower(t); gsub(/^ +| +$/,"",t); if (length(t)>=4) terms[b SUBSEP t]=1 }
function isw(c){ return c ~ /[a-z0-9_]/ }
{ sub(/\r$/, "") }
FNR==1 { f=FILENAME; files[++nf]=f; b=f; sub(/.*\//,"",b); sub(/\.md$/,"",b); base[f]=b
         fm=($0=="---"); fence=0; h1done=0; ishub=(b=="_index"||b=="glossary")
         if (!ishub) addterm(b, slugterm(b))
         if (!ishub && match(b,/^ADR-[0-9]+/)) addterm(b, substr(b,1,RLENGTH)); if (fm) next }
fm { if ($0=="---") { fm=0; next }
     if ($0 ~ /^aliases:/) { a=$0; sub(/^aliases:[ \t]*\[?/,"",a); sub(/\][ \t]*$/,"",a); n=split(a,al,/,/); for(i=1;i<=n;i++){gsub(/["\x27]/,"",al[i]); if (!ishub) addterm(b,al[i])} }
     next }
/^```/ { fence=!fence; next }
fence { next }
/^# / && !h1done { h1done=1; t=substr($0,3); sub(/^ADR-[0-9]+:[ ]*/,"",t); sub(/^Research:[ ]*/,"",t); sub(/^[Tt]he /,"",t)
                   if (!ishub && split(t,w,/ /)<=4) addterm(b,t); next }
/^#/ { next }
{ line=$0
  while (match(line,/\[\[[^]]+\]\]/)) { t=substr(line,RSTART+2,RLENGTH-4); sub(/\|.*/,"",t); sub(/#.*/,"",t); sub(/.*\//,"",t)
    links[f SUBSEP t]=1; line=substr(line,1,RSTART-1) " " substr(line,RSTART+RLENGTH) }
  l2=line; while (match(l2,/\]\([^)]+\.md[)#]/)) { t=substr(l2,RSTART+2,RLENGTH-3); l2=substr(l2,RSTART+RLENGTH); sub(/.*\//,"",t); sub(/\.md$/,"",t); links[f SUBSEP t]=1 }
  gsub(/`[^`]*`/," ",line); gsub(/\[[^]]*\]\([^)]*\)/," ",line)
  body[f SUBSEP FNR]=tolower(line); lines[f]=FNR; orig[f SUBSEP FNR]=$0 }
END {
  for (k in terms) { split(k,p,SUBSEP); tb=p[1]; term=p[2]
    multi = (term ~ / /) || (term ~ /^adr-[0-9]+$/); if (!multi && all=="") continue
    for (i=1;i<=nf;i++) { f=files[i]; if (base[f]==tb) continue
      if (base[f]=="_index" || base[f]=="glossary") continue
      if ((f SUBSEP tb) in links) continue
      if (tb ~ /^ADR-/) { id=tb; sub(/-[a-z].*/,"",id); if ((f SUBSEP id) in links) continue }
      for (ln=1; ln<=lines[f]; ln++) { s=body[f SUBSEP ln]; if (s=="") continue; off=0
        while ((pos=index(s,term))>0) { pre=substr(s,pos-1,1); post=substr(s,pos+length(term),1)
          if ((pos==1 || !isw(pre)) && !isw(post)) {
            snip=orig[f SUBSEP ln]; if (length(snip)>110) { st=off+pos-40; if (st<1) st=1; snip="..." substr(snip,st,110) "..." }
            key=f SUBSEP tb; if (!(key in seen)) { seen[key]=1
              printf "%s\t%s:%d\t[[%s]]\t\"%s\"\t%s\n", (multi?"HIGH":"LOW"), f, ln, tb, term, snip }
            break }
          off+=pos+length(term)-1; s=substr(s,pos+length(term)) } } } } }' | LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k3,3 -k2,2
