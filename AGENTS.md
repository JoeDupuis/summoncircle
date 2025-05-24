# Project
This project allow the user to launch autonomous coding agents in a docker container.
You can find more details in `agents/project_description.md`

# Stack
This is a rails project using the default stack:
- sqlite,
- solid queue/cable/cache
- hotwired (stimulus, turbo)
- Vanilla css

# Commands
- Run linter with `bundle exec rubocop -A`
- Run test with `bin/rails t`
- Run security static analysis with `bin/brakeman --no-pager`


# Git
- Never put yourself as co-author.
- Let's start branches for new feature so work is isolated and we can use PRs
- Whenever we start a new tasks lets go back to main to start a new branch

# Github
- On all PRs, if you aree claude add the claude label, if you are codex, add the codex label.
