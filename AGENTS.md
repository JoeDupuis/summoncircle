# Project
This project allow the user to launch autonomous coding agents in a docker container.
You can find more details in `agents/project_description.md`

# Stack
This is a rails project using the default stack:
- sqlite,
- solid queue/cable/cache
- hotwired (stimulus, turbo)

# Commands
- Run linter with `bundle exec rubocop -A`
- Run test with `bin/rails t`
- Run security static analysis with `bin/brakeman --no-pager`
