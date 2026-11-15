# Stands in for the aliases file kitchen.zsh sources before it starts a session. The mode file
# $OC_MODE says how the fake session behaves: line 1 the mode, line 2 its text or argument.
oc() {
  local -a ml=( exit )
  [[ -f $OC_MODE ]] && ml=( "${(@f)$(<$OC_MODE)}" )
  local -a w=( ${=2} )
  local i=${w[(i)/kitchen]} key
  if [[ ${w[i+1]} == taste ]]; then key=${w[i+3]}; else key=${w[i+2]}; fi
  print -r -- "$PWD"$'\t'"${CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS-unset}"$'\t'"${(pj:\t:)@}" >> $OC_CALLS
  if [[ ${ml[1]} == (pr|verdict) ]]; then
    # fire records the pid after it starts the session; a handoff before that would be overwritten
    zmodload zsh/zselect
    local -a of=( $KITCHEN_BOOK/*/orders/$key.json ) 
    local n=0
    until (( $(jq -r '.pid // 0' $of[1]) > 0 || n++ > 200 )); do zselect -t 3 || :; done
  fi
  case ${ml[1]} in
    exit) ;;
    say) print -r -- "${ml[2]}" ;;
    hang) while :; do sleep 1; done ;;
    stubborn) trap '' TERM; while :; do sleep 1; done ;;
    pr) zsh $KITCHEN_SCRIPT order pr $key ${ml[2]} >/dev/null ;;
    verdict) zsh $KITCHEN_SCRIPT order verdict $key PASS ok >/dev/null ;;
  esac
  return 0
}
