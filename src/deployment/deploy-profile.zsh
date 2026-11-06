#!/bin/zsh
# Deploy a profile's targets (PROFILE_TARGETS in lib/common.zsh) and record the
# profile in .git/deploy-profile, so update.zsh deploys only those targets.

set -e

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

PROJECT_ROOT="${SCRIPT_DIR:h:h}"
profile=$1
targets=(${=PROFILE_TARGETS[$profile]})
(( ${#targets} )) || error "Unknown profile: $profile"

make --no-print-directory -C "$PROJECT_ROOT" $targets
print -r -- "$profile" > "$(git -C "$PROJECT_ROOT" rev-parse --absolute-git-dir)/deploy-profile"
print_status "success" "Profile $profile recorded, glc deploys only: $targets"
