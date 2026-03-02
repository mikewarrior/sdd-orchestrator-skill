#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# SDD Orchestrator — Install Script
# Model-aware orchestration for SDD phases
# Cross-platform: macOS, Linux, Windows (Git Bash / WSL)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
SKILL_SRC="$REPO_DIR/sdd-orchestrator"
CONFIGS_EXAMPLE="$REPO_DIR/sdd-configs.example.yaml"
OPENCODE_EXAMPLE="$REPO_DIR/opencode.example.json"

# ============================================================================
# OS Detection
# ============================================================================

detect_os() {
    case "$(uname -s)" in
        Darwin)  OS="macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS="wsl"
            else
                OS="linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)  OS="windows" ;;
        *)  OS="unknown" ;;
    esac
}

os_label() {
    case "$OS" in
        macos)   echo "macOS" ;;
        linux)   echo "Linux" ;;
        wsl)     echo "WSL" ;;
        windows) echo "Windows (Git Bash)" ;;
        *)       echo "Unknown" ;;
    esac
}

# ============================================================================
# Color support
# ============================================================================

setup_colors() {
    if [[ "$OS" == "windows" ]] && [[ -z "${WT_SESSION:-}" ]] && [[ -z "${TERM_PROGRAM:-}" ]]; then
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
    else
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        BOLD='\033[1m'
        NC='\033[0m'
    fi
}

# ============================================================================
# Helpers
# ============================================================================

expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      SDD Orchestrator — Installer        ║${NC}"
    echo -e "${CYAN}${BOLD}║    Model-Aware Agent Orchestration       ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Detected:${NC} $(os_label)"
    echo ""
}

print_step() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

show_help() {
    echo "Usage: install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --global          Install to global OpenCode directory"
    echo "  --project         Install to current project"
    echo "  --path DIR        Custom install path"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Default paths:"
    echo "  Global:   ~/.opencode/"
    echo "  Project:  ./.opencode/"
}

check_dependencies() {
    local missing=()
    
    if ! command -v yq &> /dev/null; then
        missing+=("yq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing dependencies:${NC}"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install with:"
        echo "  macOS:   brew install yq"
        echo "  Linux:   apt-get install yq or snap install yq"
        echo "  Windows: choco install yq or scoop install yq"
        echo ""
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_agent_teams_lite() {
    local skill_path="$1"
    local atl_path="$skill_path/sdd-init"
    
    if [ ! -d "$atl_path" ]; then
        echo ""
        echo -e "${YELLOW}Note: agent-teams-lite skills not detected at $skill_path${NC}"
        echo "  SDD Orchestrator works best alongside agent-teams-lite."
        echo "  Install from: https://github.com/Gentleman-Programming/agent-teams-lite"
        echo ""
    fi
}

# ============================================================================
# Installation Functions
# ============================================================================

create_backup() {
    local file="$1"
    local backup_dir
    backup_dir=$(dirname "$file")
    
    if [ -f "$file" ]; then
        local timestamp
        timestamp=$(date +%Y-%m-%d-%H%M%S)
        local backup_file="$file.backup-$timestamp"
        cp "$file" "$backup_file"
        print_step "Backup created: $backup_file"
        echo ""
    fi
}

install_skill() {
    local target_dir="$1"
    local skill_target="$target_dir/skills/sdd-orchestrator"
    
    echo -e "${BLUE}Installing skill...${NC}"
    echo ""
    
    mkdir -p "$skill_target"
    mkdir -p "$skill_target/assets"
    
    cp "$SKILL_SRC/SKILL.md" "$skill_target/SKILL.md"
    print_step "sdd-orchestrator/SKILL.md"
    
    if [ -d "$SKILL_SRC/assets" ]; then
        cp "$SKILL_SRC/assets/"* "$skill_target/assets/" 2>/dev/null || true
        print_step "sdd-orchestrator/assets/"
    fi
    
    echo ""
    print_step "Skill installed → $skill_target"
}

install_configs() {
    local target_dir="$1"
    local configs_yaml="$target_dir/sdd-configs.yaml"
    local opencode_json="$target_dir/opencode.json"
    
    echo ""
    echo -e "${BLUE}Installing configuration files...${NC}"
    echo ""
    
    if [ ! -f "$configs_yaml" ] && [ -f "$CONFIGS_EXAMPLE" ]; then
        cp "$CONFIGS_EXAMPLE" "$configs_yaml"
        print_step "Created: $configs_yaml"
        print_info "Edit this file to configure your model profiles"
    elif [ -f "$configs_yaml" ]; then
        print_warn "sdd-configs.yaml already exists — skipping"
    fi
    
    if [ ! -f "$opencode_json" ] && [ -f "$OPENCODE_EXAMPLE" ]; then
        cp "$OPENCODE_EXAMPLE" "$opencode_json"
        print_step "Created: $opencode_json"
        print_info "Run configure-sdd.sh to apply a model profile"
    elif [ -f "$opencode_json" ]; then
        print_warn "opencode.json already exists — skipping"
    fi
}

print_next_steps() {
    local target_dir="$1"
    local is_global="$2"
    
    echo ""
    echo -e "${CYAN}${BOLD}═════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Next Steps${NC}"
    echo -e "${CYAN}${BOLD}═════════════════════════════════════════${NC}"
    echo ""
    
    if [ "$is_global" = "true" ]; then
        echo -e "  ${BOLD}1.${NC} Edit model profiles:"
        echo "     $target_dir/sdd-configs.yaml"
        echo ""
        echo -e "  ${BOLD}2.${NC} Apply a profile:"
        echo "     $target_dir/skills/sdd-orchestrator/assets/configure-sdd.sh"
        echo ""
        echo -e "  ${BOLD}3.${NC} In OpenCode, select the agent for each SDD phase:"
        echo "     Press Tab → choose architect/build/explore/general"
        echo ""
        echo -e "  ${BOLD}4.${NC} Start using SDD commands:"
        echo "     /sdd-init, /sdd-new, /sdd-apply, etc."
    else
        echo -e "  ${BOLD}1.${NC} Edit model profiles:"
        echo "     $target_dir/sdd-configs.yaml"
        echo ""
        echo -e "  ${BOLD}2.${NC} Apply a profile:"
        echo "     $target_dir/skills/sdd-orchestrator/assets/configure-sdd.sh"
        echo ""
        echo -e "  ${BOLD}3.${NC} Start OpenCode in this project:"
        echo "     opencode ."
        echo ""
        echo -e "  ${BOLD}4.${NC} Start using SDD commands:"
        echo "     /sdd-init, /sdd-new, /sdd-apply, etc."
    fi
    
    echo ""
    echo -e "${YELLOW}Recommended:${NC} Install agent-teams-lite for full SDD workflow"
    echo "  https://github.com/Gentleman-Programming/agent-teams-lite"
    echo ""
}

# ============================================================================
# Interactive Menu
# ============================================================================

get_global_path() {
    local default_path="$HOME/.opencode"
    
    echo -e "${BOLD}Global config path:${NC}"
    echo ""
    echo "  1) Default ($default_path)"
    echo "  2) Custom path"
    echo ""
    read -p "Choice [1-2]: " path_choice
    
    case $path_choice in
        2)
            read -p "Enter custom path: " custom_path
            expand_path "$custom_path"
            ;;
        *)
            echo "$default_path"
            ;;
    esac
}

install_global() {
    echo -e "${BOLD}Installing to global OpenCode directory...${NC}"
    echo ""
    
    local target_dir
    target_dir=$(get_global_path)
    
    echo ""
    echo -e "Target: ${CYAN}$target_dir${NC}"
    echo ""
    
    mkdir -p "$target_dir"
    
    check_agent_teams_lite "$target_dir/skills"
    
    create_backup "$target_dir/opencode.json"
    
    install_skill "$target_dir"
    install_configs "$target_dir"
    print_next_steps "$target_dir" "true"
}

install_project() {
    local project_dir="${1:-.}"
    local target_dir
    target_dir="$(cd "$project_dir" && pwd)/.opencode"
    
    echo -e "${BOLD}Installing to project directory...${NC}"
    echo ""
    echo -e "Target: ${CYAN}$target_dir${NC}"
    echo ""
    
    mkdir -p "$target_dir"
    
    check_agent_teams_lite "$target_dir/skills"
    
    install_skill "$target_dir"
    install_configs "$target_dir"
    print_next_steps "$target_dir" "false"
}

install_custom() {
    read -p "Enter target directory: " custom_path
    local target_dir
    target_dir=$(expand_path "$custom_path")
    
    echo ""
    echo -e "Target: ${CYAN}$target_dir${NC}"
    echo ""
    
    mkdir -p "$target_dir"
    
    create_backup "$target_dir/opencode.json"
    
    install_skill "$target_dir"
    install_configs "$target_dir"
    print_next_steps "$target_dir" "true"
}

interactive_menu() {
    print_header
    
    check_dependencies
    
    echo -e "${BOLD}Select installation target:${NC}"
    echo ""
    echo "  1) OpenCode (global)     ~/.opencode/"
    echo "  2) OpenCode (project)    ./.opencode/"
    echo "  3) Custom path"
    echo ""
    read -p "Choice [1-3]: " choice
    
    case $choice in
        1)  install_global ;;
        2)  install_project ;;
        3)  install_custom ;;
        *)  
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# ============================================================================
# Non-interactive Mode
# ============================================================================

non_interactive_install() {
    local mode="$1"
    local custom_path="${2:-}"
    
    print_header
    check_dependencies
    
    case "$mode" in
        global)
            local target_dir="${custom_path:-$HOME/.opencode}"
            echo -e "${BOLD}Installing to global OpenCode directory...${NC}"
            echo ""
            echo -e "Target: ${CYAN}$target_dir${NC}"
            echo ""
            mkdir -p "$target_dir"
            check_agent_teams_lite "$target_dir/skills"
            create_backup "$target_dir/opencode.json"
            install_skill "$target_dir"
            install_configs "$target_dir"
            print_next_steps "$target_dir" "true"
            ;;
        project)
            install_project "${custom_path:-.}"
            ;;
        custom)
            if [ -z "$custom_path" ]; then
                print_error "Custom path required with --path"
                exit 1
            fi
            local target_dir
            target_dir=$(expand_path "$custom_path")
            echo -e "${BOLD}Installing to custom path...${NC}"
            echo ""
            echo -e "Target: ${CYAN}$target_dir${NC}"
            echo ""
            mkdir -p "$target_dir"
            create_backup "$target_dir/opencode.json"
            install_skill "$target_dir"
            install_configs "$target_dir"
            print_next_steps "$target_dir" "true"
            ;;
    esac
}

# ============================================================================
# Main
# ============================================================================

detect_os
setup_colors

MODE=""
CUSTOM_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --global)   MODE="global"; shift ;;
        --project)  MODE="project"; shift ;;
        --path)     CUSTOM_PATH="$2"; shift 2 ;;
        -h|--help)  show_help; exit 0 ;;
        *)  echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

if [[ -n "$MODE" ]]; then
    non_interactive_install "$MODE" "$CUSTOM_PATH"
else
    interactive_menu
fi

echo -e "${GREEN}${BOLD}Done!${NC}"
