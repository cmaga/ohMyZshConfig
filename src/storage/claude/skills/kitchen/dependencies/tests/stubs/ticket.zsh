#!/bin/sh
# ticket-provider stand-in: records every call; the ready queue is always empty
printf '%s\n' "$*" >> "$TICKET_LOG"
exit 0
