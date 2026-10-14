#!/usr/bin/env bash
# Claude Code status line - based on half-life zsh theme

input=$(cat)

# One jq invocation — read all fields at once with bash builtins.
{
  IFS= read -r cwd
  IFS= read -r used_pct
  IFS= read -r limit_pct
  IFS= read -r limit_reset
  IFS= read -r model_name
} < <(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "", .context_window.used_percentage // "", .rate_limits.five_hour.used_percentage // "", .rate_limits.five_hour.resets_at // "", .model.display_name // .model.id // ""')

# ANSI colors matching half-life theme
purple='\033[38;5;135m'
limegreen='\033[38;5;118m'
turquoise='\033[38;5;81m'
orange='\033[38;5;166m'
hotpink='\033[38;5;161m'
reset='\033[0m'

# Parent repo basename via --git-common-dir, so worktrees show the parent repo.
# Also detect worktree by comparing --git-dir to --git-common-dir.
repo_name=""
wt_prefix=""
{
  IFS= read -r common_dir
  IFS= read -r git_dir
} < <(git -C "${cwd:-$PWD}" --no-optional-locks rev-parse --path-format=absolute --git-common-dir --git-dir 2>/dev/null)
if [ -n "$common_dir" ]; then
  repo_name=$(basename "$(dirname "$common_dir")")
  [ -n "$git_dir" ] && [ "$common_dir" != "$git_dir" ] && wt_prefix="${hotpink}[wt]${reset} "
fi

# Git info from one `git status --porcelain=v2 --branch` call, parsed in-shell.
# Replaces 5 git + 3 wc + 3 tr spawns with 1 git spawn.
git_branch=""
git_status=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)
if [ -n "$git_status" ]; then
  branch=""
  oid=""
  staged=0
  unstaged=0
  untracked=0
  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*) branch="${line#\# branch.head }" ;;
      '# branch.oid '*)  oid="${line#\# branch.oid }" ;;
      '1 '*|'2 '*)
        xy="${line:2:2}"
        [ "${xy:0:1}" != "." ] && staged=$((staged + 1))
        [ "${xy:1:1}" != "." ] && unstaged=$((unstaged + 1))
        ;;
      'u '*) unstaged=$((unstaged + 1)) ;;
      '? '*) untracked=$((untracked + 1)) ;;
    esac
  done <<< "$git_status"

  # Detached HEAD: porcelain v2 reports "(detached)" — fall back to short oid.
  [ "$branch" = "(detached)" ] && branch="${oid:0:7}"

  if [ -n "$branch" ]; then
    # Status dots. Literal UTF-8 bullet (●) — bash 3.2 printf %b doesn't expand \u escapes.
    dots=""
    [ "$staged" -gt 0 ]    && dots="${dots} \033[38;5;118m●"
    [ "$unstaged" -gt 0 ]  && dots="${dots} \033[38;5;166m●"
    [ "$untracked" -gt 0 ] && dots="${dots} \033[38;5;161m●"

    git_branch=" on ${turquoise}${branch}${dots}${reset}"
  fi
fi

# syspolicyd health — flags code-signing saturation that causes terminal hangs.
# See docs/terminal-hangs.md in ohMyZshConfig. Thresholds picked from empirical
# observation: idle <5%, busy 20–60%, self-sustaining feedback loop 70%+.
# One `ps` call, no pipes — keeps status-line refresh cheap.
sp_info=""
sp_cpu=$(ps -axco pid,pcpu,comm 2>/dev/null | awk '$3=="syspolicyd"{print $2; exit}')
if [ -n "$sp_cpu" ]; then
  sp_int=${sp_cpu%.*}
  [ -z "$sp_int" ] && sp_int=0
  if [ "$sp_int" -ge 70 ]; then
    # Red + warning glyph — likely in the self-sustaining loop; reboot is the fix.
    sp_info=" ${hotpink}⚠ sp:${sp_int}%${reset}"
  elif [ "$sp_int" -ge 30 ]; then
    # Orange dot — elevated but not saturated; reduce spawn pressure.
    sp_info=" ${orange}● sp:${sp_int}%${reset}"
  elif [ "$sp_int" -ge 5 ]; then
    # Green dot — mildly busy, still healthy.
    sp_info=" ${limegreen}● sp:${sp_int}%${reset}"
  fi
  # Under 5% → hide so the bar stays quiet at idle.
fi

# Current model — reflects live session state, including mid-session /model switches.
model_info=""
[ -n "$model_name" ] && model_info=" ${purple}${model_name}${reset}"

# Context usage indicator
ctx_info=""
if [ -n "$used_pct" ]; then
  printf -v used_int '%.0f' "$used_pct"
  ctx_info=" [ctx:${used_int}%]"
fi

# 5h session limit: "<reset-hour-rounded-up>:<pct>%". Hidden when rate_limits absent.
session_info=""
if [ -n "$limit_pct" ] && [ -n "$limit_reset" ]; then
  printf -v limit_int '%.0f' "$limit_pct"
  remainder=$(( limit_reset % 3600 ))
  if [ "$remainder" -gt 0 ]; then
    rounded=$(( limit_reset - remainder + 3600 ))
  else
    rounded=$limit_reset
  fi
  # BSD date takes an epoch with -r; GNU date (Linux, Git Bash) needs -d @epoch.
  reset_raw=$(date -r "$rounded" +'%I%p' 2>/dev/null || date -d "@$rounded" +'%I%p' 2>/dev/null)
  reset_raw="${reset_raw#0}"
  reset_label=$(printf '%s' "$reset_raw" | tr 'A-Z' 'a-z')
  [ -n "$reset_label" ] && session_info=" ${reset_label}:${limit_int}%"
fi

printf "%b${limegreen}%s${reset}%b%b${orange}%s%s${reset}%b\n" \
  "$wt_prefix" \
  "$repo_name" \
  "$git_branch" \
  "$model_info" \
  "$ctx_info" \
  "$session_info" \
  "$sp_info"
