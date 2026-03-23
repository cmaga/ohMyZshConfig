#!/bin/bash
INPUT=$(cat)

# Parse relevant fields
TOOL=$(echo "$INPUT" | jq -r '.preToolUse.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.preToolUse.parameters.path // empty')

# Your logic here
# if [[ "$TOOL" == "write_to_file" && "$FILE_PATH" == *.js ]]; then
#   echo '{"cancel":true,"errorMessage":"Use .ts files instead of .js"}'
#   exit 0
# fi

# Default: allow
echo '{"cancel":false}'
