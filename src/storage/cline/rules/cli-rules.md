# CLI Usage Rules

- For commands that by default respond with a pager (such as git log for example which uses --no-pager) it is CRUCIAL that you find and use the no pager flag for the respective CLI tool because the pager causes a stopping point that needs to be resolved manually by the user. This is very bad, slow and inefficient and should be avoided at all costs.
- Never embed multi-line text or nested quotes directly in shell commands—use because they cause process breaking mangling `write_to_file` tool to create a temp file first, then reference it in the command.
