# SummonCircle

Deploy and manage autonomous coding agents in Docker containers with persistent storage and iterative development sessions.


## Installation

### Development

You need:

- Ruby (see `.ruby-version`)
- SQLite
- Docker
- Git
- OpenSSL
- LibYAML


```bash
bin/setup
bin/dev
```

Access the app at http://localhost:3000

### Production

You need:
- Docker compose
- Docker
- Openssl

You can run locally or on a remote server.
To use the development build feature on a remote server, allowing you to test the app the agent is building, you will need a wildcard domain pointing to your server.
The server doesn't need to be accessible to the internet, it could be on a tailscale network for example. It just need a wild card domain to map the tasks to subdomains to proxy the requests to the right container.
This wildcard domain doesn't need to be the same you use to access the app (useful if you run the app in a private network).
If the TLD_DOMAIN env is set int he secrets file and the server is accessible to the internet, the setup will attempt to create a let's encrypt certificate automatically.


```bash
git clone https://github.com/JoeDupuis/summoncircle.git
cd summoncircle/deploy
./generate_secrets.sh
```

Take a look to secrets.env and edit if needed

```bash
docker compose up -d
docker compose exec web bin/rails db:seed
```

The `generate_secrets.sh` script will ask a few questions about your deployment type before generating the secrets file required by the docker-compose.
**Do not lose** this file, it will contain a few keys that are required to run the app. Without the keys, the app won't boot.

If you hit some invalid certificate errors after deploying remotely, try restarting your browser.

## Configuration

## Github token / SSH key

You'll likely want to add a github token in your user settings with access to read and write to the repository and optionally open PRs.
Cloning happens before the agent is invoked and there is a setting in the task view to auto push commits. Therefore, you can opt out of giving the agent access to the token.

Support for gitlab is coming.

You can opt to use an SSH key instead, but you can't opt out of giving access to the agent.

## Git configuration

If you want the agent to commit as yourself, you'll need to enter a git configuration too.

Something like:

```
[user]
  name = Joé Dupuis
  email = cheesecakefactoryisgreatandyoucantconvincemeotherwise@gmail.com
```

## Global Agent instructions

This maps to your ~/.claude/CLAUDE.md
Put your instructions here.

## Task naming agent

Haiku is configured in text mode and set as the task naming agent by default. If you prefer to not have the agent auto name your tasks to save the tokens, unset it.

## Projects

You do not have to setup a repo on a project, the agent can pull and work on multiple repos, but certain features of the app won't work. I am planning on adding multi repo support at some point.

### Dev build (PREVIEW)

You can give a path from the repo to the development build dockerfile and a build & run container will appear in your tasks.
Be aware that I released this is a bit early and kind of buggy.

## Agents

Depending on if you chose an API key or the OAuth config (Claude Pro/Max) when you generated the secrets and seeded your database, your agents will either have a secret env variable for the Anthropic key, or a Docker volume attached and an OAuth Configuration section.

The volume stores the OAuth credentials. The OAuth configuration will have you go through the OAuth sign-in flow just like you would in the terminal. You'll have to copy the code Anthropic gives you into the text field.

## Prompting

You can interupt a prompt by repormpting.

It is not yet possible to switch from one agent to another without starting a new task.

## Troubleshooting

Check `/jobs` to see if any background jobs failed.


## Roadmap

- Plan mode
- Refactor & Performance enhancements
- Multi-repo per projects
- Multi user support
- Gitlab tokens
- Support for codex-cli and Gemini-client
- Allow switching agent per prompt instead of per task
- Attaching a local shell to a task
- Amazon Bedrock support
- Make tool calls collapsable and various readability/QoL improvements
- MCP support
