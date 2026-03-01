---
name: sdd-orchestrator
description: >
  Project-specific SDD orchestrator configuration with per-phase agent assignments.
  Trigger: When starting SDD workflow, running SDD commands, or coordinating SDD phases.
license: MIT
metadata:
  author: mrueda
  version: "2.0"
  scope: [root]
  auto_invoke:
    - "Starting SDD workflow"
    - "Running SDD commands"
    - "Coordinating SDD phases"
---

## When to Use

Use this skill when:

- Starting or coordinating SDD (Spec-Driven Development) workflow
- Running SDD commands like `/sdd:init`, `/sdd:new`, `/sdd:apply`, etc.
- Determining which agent type to use for each SDD phase
- Configuring models for SDD agents

---

## Critical Patterns

### Pattern 1: Per-Phase Agent Mapping

The SDD orchestrator must use specific agent types for each phase:

| SDD Phase | Agent Type | Reason |
|-----------|------------|--------|
| `sdd-init` | `general` | Bootstrap and coordination |
| `sdd-explore` | `explore` | Investigation and analysis |
| `sdd-propose` | `plan` | Structured proposals |
| `sdd-spec` | `plan` | Requirements and scenarios |
| `sdd-design` | `plan` | Architecture decisions |
| `sdd-tasks` | `general` | Task breakdown |
| `sdd-apply` | `build` | Code implementation |
| `sdd-verify` | `explore` | Quality gate verification |
| `sdd-archive` | `general` | Archive and cleanup |

### Pattern 2: Sub-Agent Launch

```javascript
Task(
  description: '{phase} for {change-name}',
  subagent_type: '{agent-type-from-table}',
  prompt: 'You are an SDD sub-agent. Read the skill file at <skill-path>/{phase}/SKILL.md FIRST...'
)
```

The skill path depends on installation:
- **Global**: `~/.opencode/skill/`
- **Project**: `./.opencode/skill/`
- **Custom**: Your configured path

### Pattern 3: Model Configuration Separation

- **Agent type mapping** → Lives in this skill (which agent for which phase)
- **Model assignment** → Lives in `opencode.json` (which model for which agent)

---

## Decision Tree

```
Running SDD phase?
├── sdd-init / sdd-tasks / sdd-archive → subagent_type: 'general'
├── sdd-explore / sdd-verify            → subagent_type: 'explore'
├── sdd-propose / sdd-spec / sdd-design → subagent_type: 'plan'
└── sdd-apply                           → subagent_type: 'build'

Need to configure models?
├── Edit sdd-configs.yaml in your OpenCode config directory
├── Run: <config-dir>/skill/sdd-orchestrator/assets/configure-sdd.sh --verify
└── Apply profile: <config-dir>/skill/sdd-orchestrator/assets/configure-sdd.sh --config <name>
```

---

## Code Examples

### Example 1: Launch spec sub-agent

```javascript
Task(
  description: 'spec for add-dark-mode',
  subagent_type: 'plan',
  prompt: 'You are an SDD sub-agent. Read the skill file for sdd-spec FIRST, then follow its instructions exactly.

CONTEXT:
- Project: /path/to/project
- Change: add-dark-mode
- Artifact store mode: engram

TASK:
Write delta specs for the add-dark-mode change.

Return structured output with: status, executive_summary, artifacts, next_recommended.'
)
```

### Example 2: Launch apply sub-agent

```javascript
Task(
  description: 'apply for add-dark-mode',
  subagent_type: 'build',
  prompt: 'You are an SDD sub-agent. Read the skill file for sdd-apply FIRST...

TASK:
Implement Phase 1, tasks 1.1-1.3 from tasks.md.'
)
```

---

## Configuration

SDD uses a YAML-based configuration system. Define multiple profiles in `sdd-configs.yaml` and switch between them.

### Config Location

The configuration script automatically detects where to look:

1. **Project-local** (priority): `./.opencode/` in current working directory
2. **Global**: `~/.opencode/` (or custom path if configured)

### YAML Structure

```yaml
configs:
  - name: "default"
    active: true
    models:
      plan: "provider/model-id"
      build: "provider/model-id"
      explore: "provider/model-id"
      general: "provider/model-id"

  - name: "reasoning-heavy"
    active: false
    models:
      plan:
        model: "provider/reasoning-model"
        temperature: 0.7
        steps: 15
      build: "provider/code-model"
      explore: "provider/reasoning-model"
      general: "provider/fast-model"
```

**Rules:**
- Exactly one profile must have `active: true`
- All four model keys (plan, build, explore, general) are required for each profile
- Profile names must be unique
- Models can be strings or objects with settings

### Commands

```bash
# Interactive mode - select from available profiles
./configure-sdd.sh

# List all available profiles
./configure-sdd.sh --list

# Verify YAML configuration validity
./configure-sdd.sh --verify

# Apply a specific profile to opencode.json
./configure-sdd.sh --config <profile-name>

# Set a profile as active in YAML
./configure-sdd.sh --set-active <profile-name>

# Show current opencode.json configuration
./configure-sdd.sh --show

# Copy example config to sdd-configs.yaml
./configure-sdd.sh --copy-example
```

---

## Resources

- **Configuration Script**: `assets/configure-sdd.sh` — for model configuration
- **YAML Config**: `sdd-configs.yaml` in your OpenCode config directory
- **Example Config**: `sdd-configs.example.yaml` — template for new configurations
- **OpenCode Agents Docs**: https://opencode.ai/docs/agents

## Requirements

- **yq** — YAML processor
  - macOS: `brew install yq`
  - Linux: `apt-get install yq` or `snap install yq`
  - Windows: `choco install yq` or `scoop install yq`
- **agent-teams-lite** (recommended) — Base SDD skills
  - https://github.com/Gentleman-Programming/agent-teams-lite
