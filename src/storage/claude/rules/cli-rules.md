# CLI Usage Rules

- For commands that by default respond with a pager (such as git log for example which uses --no-pager) it is CRUCIAL that you find and use the no pager flag for the respective CLI tool because the pager causes a stopping point that needs to be resolved manually by the user. This is very bad, slow and inefficient and should be avoided at all costs.
