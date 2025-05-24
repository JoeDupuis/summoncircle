# Docker Agent Platform - Project Instructions for LLMs

## Overview

This platform enables users to deploy and manage coding agents via Docker containers. Each agent runs in an isolated environment with persistent storage, allowing for iterative development sessions where work can be resumed at any time.

## Core Concepts

### 1. Agents
An agent is a configured Docker container instance with:
- **Docker Image**: The base container image defining the runtime environment
- **Agent-Level Prompt**: Persistent instructions that guide the agent's behavior across all tasks
- **Initial Prompt Arguments**: Parameters for starting a new conversation/task
- **Continuation Prompt Arguments**: Parameters for resuming or modifying existing work
- **Setup Script**: Initialization script that runs on first prompt

### 2. Projects
Projects provide context and resources for agents:
- **Description/Instructions**: Detailed prompt explaining the project goals and constraints
- **Repository**: GitHub repository URL for version control
- **Setup Script**: Project-specific initialization that runs on first agent interaction
- **Secrets**: Sensitive configuration values (API keys, tokens, etc.)
- **Environment Variables**: Project-specific environment configuration

### 3. Global Configuration
System-wide settings that apply to all projects:
- **Global Prompt/Instructions**: Base instructions injected into all agent interactions
- **Global Secrets**: Shared sensitive values available to all projects
- **Global Environment Variables**: System-wide environment configuration

## Architecture Flow

### Task Lifecycle
1. **Task Creation**: From a project page, user selects an agent and provides initial prompt
2. **Container Initialization**:
   - Docker container spins up with persistent volumes
   - Global configs are loaded
   - Project configs are overlaid
   - Setup scripts execute (if first run)
3. **Agent Execution**: Agent processes the task with full context
4. **Progress Monitoring**: User can view real-time outputs and steps
5. **Iteration**: User can re-prompt for modifications or continuation
6. **Archival**: When complete, user can archive task (deletes volumes)

### Data Persistence
- Each task maintains persistent volumes between sessions
- Work state, code, and environment remain intact
- Allows resuming work exactly where left off

## Agent Capabilities

Agents have access to:
- **Internet connectivity** for research and package installation
- **File system access** within their container
- **Git operations** for version control
- **Extended tools** beyond basic coding (as configured)

## Output Management

Users can:
- **Push to GitHub**: Direct commits to repository
- **Download patches**: Get local copies of changes
- **Create branches**: New branches without PRs
- **Review & comment**: In-app or GitHub-based code review
- **Request modifications**: Iterative improvements through re-prompting

## Configuration Hierarchy

Configuration values cascade in this order:
1. Global configuration (base layer)
2. Project configuration (overrides global)
3. Agent configuration (overrides project)
4. Task-specific prompts (highest priority)

### Environment Variable Precedence
```
FINAL_ENV = merge(
    global_env,
    project_env,
    agent_env,
    task_env
)
```

## Future Capabilities (Planned)

- **Inline Code Commenting**: Direct feedback on specific lines
- **GitHub Issues Integration**: Automatic issue linking
- **Advanced Review Workflows**: Approval chains and automated testing
