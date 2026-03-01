# SDD Orchestrator Skill

**SDD Orchestrator** is an extension for [`agent-teams-lite`](https://github.com/Gentleman-Programming/agent-teams-lite) that enables **model-aware orchestration** of agents across Software Development Lifecycle phases.

It allows you to attach specific models to specific agents and map them to defined SDD phases — giving you full control over *which model is used at which stage of development*.

---

## Why SDD Orchestrator?

When working with multi-agent systems, not all phases of software development require the same reasoning capabilities:

- **Requirement analysis** may benefit from a high-reasoning model
- **Architecture design** might need strong structured output capabilities  
- **Code generation** could prioritize speed and cost efficiency
- **Testing and validation** may require deterministic behavior

Instead of using a single model across all phases, **SDD Orchestrator gives you precise control**.

---

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/mrueda/sdd-orchestrator-skill/main/install.sh | bash

# Or clone and run
git clone https://github.com/mrueda/sdd-orchestrator-skill.git
cd sdd-orchestrator-skill
./install.sh
```

---

## Requirements

- **yq** - YAML processor (required for configure script)
  - macOS: `brew install yq`
  - Linux: `apt-get install yq` or `snap install yq`
  - Windows: `choco install yq` or `scoop install yq`

- **agent-teams-lite** (recommended, optional)
  - Provides the base SDD skills this orchestrator coordinates
  - Install from: https://github.com/Gentleman-Programming/agent-teams-lite

---

## Installation

### Option 1: One-line Install

```bash
curl -fsSL https://raw.githubusercontent.com/mrueda/sdd-orchestrator-skill/main/install.sh | bash
```

### Option 2: Clone and Install

```bash
git clone https://github.com/mrueda/sdd-orchestrator-skill.git
cd sdd-orchestrator-skill
./install.sh
```

### Installation Targets

The installer supports three targets:

| Target | Path | Description |
|--------|------|-------------|
| **Global** | `~/.opencode/` | Available in all projects |
| **Project** | `./.opencode/` | Project-specific configuration |
| **Custom** | Your path | Any directory you choose |

### What Gets Installed

```
~/.opencode/                          # (or your chosen path)
├── opencode.json                     # Agent configuration (created from example)
├── opencode.json.backup-TIMESTAMP    # Backup of existing config (if any)
├── sdd-configs.yaml                  # Model profiles (created from example)
└── skill/
    └── sdd-orchestrator/
        ├── SKILL.md                  # Orchestrator skill
        └── assets/
            └── configure-sdd.sh      # Configuration script
```

### Post-Install

1. Edit `sdd-configs.yaml` to define your model profiles
2. Run `configure-sdd.sh` to apply a profile
3. In OpenCode, select the appropriate agent for each SDD phase

---

## Usage

### Overview

SDD Orchestrator uses two components working together:

1. **YAML Configuration** (`sdd-configs.yaml`) — Define model profiles with different settings
2. **Configure Script** (`configure-sdd.sh`) — Apply profiles to your `opencode.json`

```
sdd-configs.yaml  →  configure-sdd.sh  →  opencode.json
   (edit profiles)    (apply profile)     (agents configured)
```

---

### The YAML Configuration (`sdd-configs.yaml`)

#### What It Does

Defines multiple model profiles, each specifying which AI model to use for each agent type (plan, build, explore, general).

#### Structure

```yaml
configs:
  - name: "profile-name"
    active: true/false
    models:
      plan: "provider/model-id"      # For spec, design, propose phases
      build: "provider/model-id"     # For apply (implementation) phase
      explore: "provider/model-id"   # For explore, verify phases
      general: "provider/model-id"   # For init, tasks, archive phases
```

#### Simple Format (String)

Just the model identifier:

```yaml
configs:
  - name: "cloud"
    active: true
    models:
      plan: "opencode-go/minimax-m2.5"
      build: "opencode-go/kimi-k2.5"
      explore: "opencode-go/glm-5"
      general: "opencode-go/glm-5"
```

#### Advanced Format (Object with Settings)

Include model-specific parameters:

```yaml
configs:
  - name: "local"
    active: false
    models:
      plan:
        model: "local/nemotron3-nano"
        temperature: 0.2
        top_p: 0.9
        steps: 10
        mode: "primary"
      build:
        model: "local/devstral-small-2"
        temperature: 0.3
        steps: 5
      explore: "local/nanbeige4.1"
      general: "local/nemotron3-nano"
```

#### Available Settings

| Setting | Type | Description |
|---------|------|-------------|
| `model` | string | **Required** — Model identifier (e.g., `provider/model-id`) |
| `temperature` | number | Sampling temperature (0.0-2.0) |
| `top_p` | number | Nucleus sampling threshold (0.0-1.0) |
| `steps` | number | Max agent iterations before text-only response |
| `mode` | string | Agent mode: `primary`, `subagent`, or `all` |
| `variant` | string | Model variant (e.g., `thinking`) |
| `prompt` | string | Custom system prompt |
| `color` | string | Hex color (`#RRGGBB`) or theme color |
| `disable` | boolean | Set to `true` to disable this agent |
| `hidden` | boolean | Hide from `@` autocomplete |
| `options` | object | Provider-specific options |

#### Example Profiles

```yaml
configs:
  # Cloud-based models (default)
  - name: "cloud"
    active: true
    models:
      plan: "opencode-go/minimax-m2.5"
      build: "opencode-go/kimi-k2.5"
      explore: "opencode-go/glm-5"
      general: "opencode-go/glm-5"

  # Local models via Ollama/LM Studio
  - name: "local"
    active: false
    models:
      plan:
        model: "local/nemotron3-nano"
        temperature: 0.2
        steps: 10
      build:
        model: "local/devstral-small-2"
        temperature: 0.3
        steps: 5
      explore: "local/nanbeige4.1"
      general: "local/nemotron3-nano"

  # High-reasoning for complex projects
  - name: "reasoning-heavy"
    active: false
    models:
      plan:
        model: "anthropic/claude-sonnet-4-20250514"
        temperature: 0.7
        steps: 15
      build:
        model: "openai/gpt-4.1"
        variant: "thinking"
        temperature: 0.3
      explore: "anthropic/claude-sonnet-4-20250514"
      general: "opencode-go/glm-5"
```

---

### The Configure Script (`configure-sdd.sh`)

#### What It Does

Reads profiles from `sdd-configs.yaml` and generates/updates `opencode.json` with the selected model configuration.

#### Commands

| Command | Description |
|---------|-------------|
| `./configure-sdd.sh` | **Interactive mode** — Select profile from menu |
| `./configure-sdd.sh --list` | List all available profiles |
| `./configure-sdd.sh --verify` | Validate YAML configuration |
| `./configure-sdd.sh --config <name>` | Apply specific profile by name |
| `./configure-sdd.sh --set-active <name>` | Set profile as active in YAML |
| `./configure-sdd.sh --show` | Display current `opencode.json` |
| `./configure-sdd.sh --copy-example` | Copy example YAML to `sdd-configs.yaml` |

#### Common Workflows

**Initial Setup:**

```bash
# Navigate to the assets directory
cd ~/.opencode/skill/sdd-orchestrator/assets

# Create config from example
./configure-sdd.sh --copy-example

# Edit with your model preferences
# (open sdd-configs.yaml in your editor)

# Validate your changes
./configure-sdd.sh --verify

# Select and apply a profile
./configure-sdd.sh
```

**Switch Between Profiles:**

```bash
# List available profiles
./configure-sdd.sh --list

# Switch to "local" profile
./configure-sdd.sh --config local
```

**Validate Before Applying:**

```bash
# Check for errors in YAML
./configure-sdd.sh --verify

# Output:
# ✓ YAML syntax is valid
# ✓ Found 3 configuration(s)
# ✓ Active configuration: 'cloud'
```

---

### SDD Phase → Agent → Model Mapping

| SDD Phase | Agent Type | Typical Model Choice | Why |
|-----------|------------|---------------------|-----|
| `sdd-init` | `general` | Fast, cheap | Bootstrap and coordination |
| `sdd-explore` | `explore` | Balanced | Codebase investigation |
| `sdd-propose` | `plan` | High reasoning | Structured proposals |
| `sdd-spec` | `plan` | High reasoning | Requirements and scenarios |
| `sdd-design` | `plan` | High reasoning | Architecture decisions |
| `sdd-tasks` | `general` | Fast, cheap | Task breakdown |
| `sdd-apply` | `build` | Code-focused | Implementation |
| `sdd-verify` | `explore` | Deterministic | Quality gate verification |
| `sdd-archive` | `general` | Fast, cheap | Archive and cleanup |

---

### Tips

- **Cost optimization**: Use expensive reasoning models only for `plan` phase, cheaper models for `build` and `general`
- **Local development**: Create a `local` profile with Ollama/LM Studio models for offline work
- **Multiple profiles**: Keep several profiles (cloud/local/reasoning-heavy) and switch as needed
- **Always verify**: Run `--verify` after editing YAML to catch syntax errors
- **Backups**: The installer creates backups of `opencode.json` before modifications

---

## How It Works

### Core Concept

```
SDD Phase → Agent Type → Model
```

This enables:

- **Phase-aware execution** — Different agents for different SDD phases
- **Model specialization** — Best model for each task type
- **Cost-performance optimization** — Expensive models only where needed
- **Clear separation of responsibilities** — Each agent has a focused role

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  ORCHESTRATOR (sdd-orchestrator skill)                   │
│                                                          │
│  • Detects SDD phase being executed                      │
│  • Determines correct agent type for phase               │
│  • Sub-agent uses model configured for that agent        │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│  AGENT TYPES (configured in opencode.json)               │
│                                                          │
│  plan     → High-reasoning model (specs, design)         │
│  build    → Code-focused model (implementation)          │
│  explore  → Review model (verification, analysis)        │
│  general  → Coordinator model (init, tasks, archive)     │
└──────────────────────────────────────────────────────────┘
```

---

## Examples

### Example: Cloud Profile with Custom Settings

```yaml
configs:
  - name: "production"
    active: true
    models:
      plan:
        model: "anthropic/claude-sonnet-4-20250514"
        temperature: 0.7
        steps: 15
        mode: "primary"
      build:
        model: "openai/gpt-4.1"
        temperature: 0.3
        steps: 8
      explore:
        model: "anthropic/claude-sonnet-4-20250514"
        steps: 5
      general:
        model: "opencode-go/glm-5"
        steps: 5
```

### Example: Local-Only Profile

```yaml
configs:
  - name: "offline"
    active: false
    models:
      plan: "local/llama3.1-70b"
      build: "local/codestral"
      explore: "local/llama3.1-70b"
      general: "local/llama3.1-8b"
```

---

## Use Cases

- AI-assisted software development pipelines
- Teams experimenting with multiple LLM providers
- Cost-optimized agent orchestration
- Structured SDD-based development environments
- Research into phase-specialized model performance

---

## Vision

SDD Orchestrator promotes a new way of thinking about AI-assisted development:

> Not just multi-agent systems — but **lifecycle-aware, model-specialized orchestration**.

It encourages intentional model usage instead of treating all LLMs as interchangeable tools.

---

## Contributing

Contributions, experiments, and feedback are welcome.

**To improve the orchestrator:**
1. Edit `sdd-orchestrator/SKILL.md`
2. Test in a real project
3. Submit PR with before/after examples

---

## License

MIT License — See [LICENSE](LICENSE) for details.
