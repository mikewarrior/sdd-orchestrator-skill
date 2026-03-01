#!/bin/bash
#
# configure-sdd.sh - Configure SDD agent models for OpenCode using YAML profiles
#
# Usage:
#   ./configure-sdd.sh                    # Interactive mode (select profile)
#   ./configure-sdd.sh --list             # List all available profiles
#   ./configure-sdd.sh --verify           # Verify YAML configuration
#   ./configure-sdd.sh --config NAME      # Apply profile NAME
#   ./configure-sdd.sh --set-active NAME  # Set profile as active
#   ./configure-sdd.sh --copy-example     # Copy example YAML to sdd-configs.yaml
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Configuration Location Detection
# ============================================================================

detect_config_location() {
    # Check if running from project installation (./.opencode/)
    local project_config="./.opencode"
    local global_config="$HOME/.opencode"
    
    # Check if sdd-configs.yaml exists in project directory
    if [ -f "$project_config/sdd-configs.yaml" ]; then
        CONFIG_DIR="$(cd "$project_config" && pwd)"
        return 0
    fi
    
    # Check if running from global installation
    if [[ "$SCRIPT_DIR" == *"$global_config"* ]]; then
        CONFIG_DIR="$global_config"
        return 0
    fi
    
    # Check if running from project installation
    if [[ "$SCRIPT_DIR" == *"/.opencode/"* ]]; then
        # Extract the .opencode directory from script path
        CONFIG_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
        return 0
    fi
    
    # Check if sdd-configs.yaml exists in global directory
    if [ -f "$global_config/sdd-configs.yaml" ]; then
        CONFIG_DIR="$global_config"
        return 0
    fi
    
    # Default to project directory if it exists, otherwise global
    if [ -d "$project_config" ]; then
        CONFIG_DIR="$(cd "$project_config" 2>/dev/null && pwd)" || echo "$global_config"
    else
        CONFIG_DIR="$global_config"
    fi
}

# Initialize config location
detect_config_location

OPENCODE_JSON="$CONFIG_DIR/opencode.json"
OPENCODE_EXAMPLE="$CONFIG_DIR/opencode.example.json"
SDD_CONFIGS_YAML="$CONFIG_DIR/sdd-configs.yaml"
SDD_CONFIGS_EXAMPLE="$CONFIG_DIR/sdd-configs.example.yaml"

# Fallback: check for example files in script directory (for initial setup)
if [ ! -f "$SDD_CONFIGS_EXAMPLE" ]; then
    SCRIPT_EXAMPLE="$SCRIPT_DIR/../../../sdd-configs.example.yaml"
    if [ -f "$SCRIPT_EXAMPLE" ]; then
        SDD_CONFIGS_EXAMPLE="$SCRIPT_EXAMPLE"
    fi
fi

if [ ! -f "$OPENCODE_EXAMPLE" ]; then
    SCRIPT_OPENCODE_EXAMPLE="$SCRIPT_DIR/../../../opencode.example.json"
    if [ -f "$SCRIPT_OPENCODE_EXAMPLE" ]; then
        OPENCODE_EXAMPLE="$SCRIPT_OPENCODE_EXAMPLE"
    fi
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check for required tools
if ! command -v yq &> /dev/null; then
    printf "${RED}Error: yq is required but not installed.${NC}\n"
    echo "Install with: brew install yq (macOS) or apt-get install yq (Linux)"
    exit 1
fi

print_header() {
    printf "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           SDD Agent Model Configuration                       ║"
    echo "║           Spec-Driven Development for OpenCode                ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    printf "${NC}"
    echo ""
    printf "${BLUE}Config directory: ${NC}$CONFIG_DIR\n"
    echo ""
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --list             List all available profiles"
    echo "  --verify           Verify YAML configuration validity"
    echo "  --config NAME      Apply profile NAME to opencode.json and set as active"
    echo "  --set-active NAME  Set profile NAME as active"
    echo "  --copy-example     Copy sdd-configs.example.yaml to sdd-configs.yaml"
    echo "  --show             Show current opencode.json content"
    echo "  --help, -h         Show this help message"
    echo ""
    echo "Config location: $CONFIG_DIR"
    echo ""
    echo "Examples:"
    echo "  # Interactive mode (select from available profiles)"
    echo "  $0"
    echo ""
    echo "  # List all profiles"
    echo "  $0 --list"
    echo ""
    echo "  # Apply a specific profile"
    echo "  $0 --config cloud"
    echo ""
    echo "  # Copy example config and customize"
    echo "  $0 --copy-example"
    echo ""
    echo "  # Verify YAML configuration"
    echo "  $0 --verify"
}

# Copy example config
copy_example_config() {
    if [ ! -f "$SDD_CONFIGS_EXAMPLE" ]; then
        printf "${RED}Error: Example file not found: $SDD_CONFIGS_EXAMPLE${NC}\n"
        exit 1
    fi
    
    if [ -f "$SDD_CONFIGS_YAML" ]; then
        printf "${YELLOW}Warning: sdd-configs.yaml already exists.${NC}\n"
        printf "Overwrite? (y/N): "
        read response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            printf "${BLUE}Cancelled.${NC}\n"
            exit 0
        fi
    fi
    
    cp "$SDD_CONFIGS_EXAMPLE" "$SDD_CONFIGS_YAML"
    printf "${GREEN}✓ Copied example config to: $SDD_CONFIGS_YAML${NC}\n"
    printf "${BLUE}Customize this file, then run: $0 --verify${NC}\n"
}

# Get model value from config (handles both string and object format)
get_model_value() {
    local profile_idx=$1
    local agent_type=$2
    local field=$3
    
    local agent_kind
    agent_kind=$(yq ".configs[$profile_idx].models.$agent_type | kind" "$SDD_CONFIGS_YAML" 2>/dev/null || echo "null")
    
    if [ "$agent_kind" = "null" ]; then
        echo "null"
        return
    fi
    
    if [ "$agent_kind" = "string" ] || [ "$agent_kind" = "scalar" ]; then
        yq ".configs[$profile_idx].models.$agent_type" "$SDD_CONFIGS_YAML"
    else
        if [ -z "$field" ] || [ "$field" = "model" ]; then
            yq ".configs[$profile_idx].models.$agent_type.model // null" "$SDD_CONFIGS_YAML"
        else
            yq ".configs[$profile_idx].models.$agent_type.$field // null" "$SDD_CONFIGS_YAML"
        fi
    fi
}

# Verify YAML configuration
verify_yaml() {
    local errors=0
    
    printf "${CYAN}Verifying YAML configuration...${NC}\n"
    printf "${BLUE}Config file: $SDD_CONFIGS_YAML${NC}\n"
    echo ""
    
    if [ ! -f "$SDD_CONFIGS_YAML" ]; then
        printf "${RED}✗ Configuration file not found: $SDD_CONFIGS_YAML${NC}\n"
        printf "${BLUE}Run: $0 --copy-example${NC}\n"
        return 1
    fi
    
    if ! yq '.' "$SDD_CONFIGS_YAML" > /dev/null 2>&1; then
        printf "${RED}✗ Invalid YAML syntax${NC}\n"
        return 1
    fi
    
    printf "${GREEN}✓ YAML syntax is valid${NC}\n"
    
    local configs_count
    configs_count=$(yq '.configs | length' "$SDD_CONFIGS_YAML")
    
    if [ "$configs_count" = "0" ] || [ -z "$configs_count" ]; then
        printf "${RED}✗ No configurations found (configs array is empty)${NC}\n"
        return 1
    fi
    
    printf "${GREEN}✓ Found $configs_count configuration(s)${NC}\n"
    
    local valid_agent_fields="model temperature top_p steps maxSteps mode variant prompt color disable hidden options"
    
    local i=0
    while [ "$i" -lt "$configs_count" ]; do
        local name
        name=$(yq ".configs[$i].name" "$SDD_CONFIGS_YAML")
        
        if [ "$name" = "null" ] || [ -z "$name" ]; then
            printf "${RED}✗ Config $i: Missing 'name' field${NC}\n"
            errors=$((errors + 1))
        else
            printf "${BLUE}Checking '$name'...${NC}\n"
            
            for agent_type in plan build explore general; do
                local agent_kind
                agent_kind=$(yq ".configs[$i].models.$agent_type | kind" "$SDD_CONFIGS_YAML" 2>/dev/null || echo "null")
                
                if [ "$agent_kind" = "null" ]; then
                    printf "${RED}  ✗ Missing models.$agent_type${NC}\n"
                    errors=$((errors + 1))
                elif [ "$agent_kind" = "string" ] || [ "$agent_kind" = "scalar" ]; then
                    local model_val
                    model_val=$(yq ".configs[$i].models.$agent_type" "$SDD_CONFIGS_YAML")
                    printf "${GREEN}  ✓ models.$agent_type: $model_val${NC}\n"
                elif [ "$agent_kind" = "map" ] || [ "$agent_kind" = "object" ]; then
                    local model_val
                    model_val=$(yq ".configs[$i].models.$agent_type.model // null" "$SDD_CONFIGS_YAML")
                    
                    if [ "$model_val" = "null" ]; then
                        printf "${RED}  ✗ models.$agent_type: Missing 'model' field in object format${NC}\n"
                        errors=$((errors + 1))
                    else
                        local extra_fields
                        extra_fields=$(yq ".configs[$i].models.$agent_type | keys | .[]" "$SDD_CONFIGS_YAML" 2>/dev/null || echo "")
                        
                        printf "${GREEN}  ✓ models.$agent_type: $model_val${NC}\n"
                        
                        for field in $extra_fields; do
                            if [ "$field" != "model" ]; then
                                local field_val
                                field_val=$(yq ".configs[$i].models.$agent_type.$field" "$SDD_CONFIGS_YAML")
                                if [ "$field_val" != "null" ]; then
                                    printf "      - $field: $field_val\n"
                                fi
                            fi
                        done
                    fi
                else
                    printf "${RED}  ✗ models.$agent_type: Invalid format (must be string or object)${NC}\n"
                    errors=$((errors + 1))
                fi
            done
        fi
        
        i=$((i + 1))
    done
    
    local active_count
    active_count=$(yq '.configs[] | select(.active == true) | length' "$SDD_CONFIGS_YAML" | wc -l)
    
    if [ "$active_count" = "0" ]; then
        printf "${YELLOW}⚠ No active configuration found (you'll need to select one)${NC}\n"
    elif [ "$active_count" -gt 1 ]; then
        printf "${RED}✗ Multiple active configurations found ($active_count) - only one allowed${NC}\n"
        errors=$((errors + 1))
    else
        local active_name
        active_name=$(yq '.configs[] | select(.active == true) | .name' "$SDD_CONFIGS_YAML")
        printf "${GREEN}✓ Active configuration: '$active_name'${NC}\n"
    fi
    
    echo ""
    if [ "$errors" -eq 0 ]; then
        printf "${GREEN}✓ Configuration is valid!${NC}\n"
        return 0
    else
        printf "${RED}✗ Configuration has $errors error(s)${NC}\n"
        return 1
    fi
}

# List all profiles
list_profiles() {
    print_header
    
    if [ ! -f "$SDD_CONFIGS_YAML" ]; then
        printf "${RED}Error: Configuration file not found: $SDD_CONFIGS_YAML${NC}\n"
        printf "${BLUE}Run: $0 --copy-example${NC}\n"
        exit 1
    fi
    
    printf "${BLUE}Available profiles:${NC}\n"
    echo ""
    
    local configs_count
    configs_count=$(yq '.configs | length' "$SDD_CONFIGS_YAML")
    
    local i=0
    while [ "$i" -lt "$configs_count" ]; do
        local name active
        name=$(yq ".configs[$i].name" "$SDD_CONFIGS_YAML")
        active=$(yq ".configs[$i].active" "$SDD_CONFIGS_YAML")
        
        if [ "$active" = "true" ]; then
            printf "${GREEN}→ $name (ACTIVE)${NC}\n"
        else
            printf "  $name\n"
        fi
        
        for agent_type in plan build explore general; do
            local agent_kind model_val
            agent_kind=$(yq ".configs[$i].models.$agent_type | kind" "$SDD_CONFIGS_YAML" 2>/dev/null || echo "null")
            
            if [ "$agent_kind" = "string" ] || [ "$agent_kind" = "scalar" ]; then
                model_val=$(yq ".configs[$i].models.$agent_type" "$SDD_CONFIGS_YAML")
                printf "    $agent_type: $model_val\n"
            elif [ "$agent_kind" = "map" ] || [ "$agent_kind" = "object" ]; then
                model_val=$(yq ".configs[$i].models.$agent_type.model" "$SDD_CONFIGS_YAML")
                printf "    $agent_type: $model_val"
                
                local has_settings=false
                for field in temperature top_p steps variant mode; do
                    local field_val
                    field_val=$(yq ".configs[$i].models.$agent_type.$field // null" "$SDD_CONFIGS_YAML")
                    if [ "$field_val" != "null" ] && [ -n "$field_val" ]; then
                        if [ "$has_settings" = false ]; then
                            printf " ("
                            has_settings=true
                        else
                            printf ", "
                        fi
                        printf "$field=$field_val"
                    fi
                done
                
                if [ "$has_settings" = true ]; then
                    printf ")"
                fi
                printf "\n"
            fi
        done
        
        echo ""
        i=$((i + 1))
    done
}

# Generate opencode.json from profile
generate_config() {
    local profile_name=$1
    local configs_count
    configs_count=$(yq '.configs | length' "$SDD_CONFIGS_YAML")
    
    local profile_idx=-1
    local i=0
    while [ "$i" -lt "$configs_count" ]; do
        local name
        name=$(yq ".configs[$i].name" "$SDD_CONFIGS_YAML")
        if [ "$name" = "$profile_name" ]; then
            profile_idx=$i
            break
        fi
        i=$((i + 1))
    done
    
    if [ "$profile_idx" = "-1" ]; then
        printf "${RED}Error: Profile '$profile_name' not found${NC}\n"
        exit 1
    fi
    
    local json_output
    json_output="{\n"
    json_output+='  "$schema": "https://opencode.ai/config.json",'"\n"
    json_output+='  "agent": {'"\n"
    
    local first_agent=true
    
    for agent_type in plan build explore general; do
        local agent_kind model_val
        agent_kind=$(yq ".configs[$profile_idx].models.$agent_type | kind" "$SDD_CONFIGS_YAML" 2>/dev/null || echo "null")
        
        if [ "$agent_kind" = "null" ]; then
            printf "${RED}Error: Missing $agent_type model configuration${NC}\n"
            exit 1
        fi
        
        if [ "$agent_kind" = "string" ] || [ "$agent_kind" = "scalar" ]; then
            model_val=$(yq ".configs[$profile_idx].models.$agent_type" "$SDD_CONFIGS_YAML")
        else
            model_val=$(yq ".configs[$profile_idx].models.$agent_type.model" "$SDD_CONFIGS_YAML")
        fi
        
        local description=""
        case $agent_type in
            plan)
                description="Spec/Architect agent - for sdd-spec, sdd-design, sdd-propose phases"
                ;;
            build)
                description="Implementer/Coder agent - for sdd-apply phase"
                ;;
            explore)
                description="Reviewer/Quality Gate agent - for sdd-verify, sdd-explore phases"
                ;;
            general)
                description="Lead/Orchestrator agent - for sdd-init, sdd-tasks, sdd-archive phases"
                ;;
        esac
        
        if [ "$first_agent" = true ]; then
            first_agent=false
        else
            json_output+=",""\n"
        fi
        
        json_output+='    "'$agent_type'": {'"\n"
        json_output+='      "model": "'$model_val'"'
        
        if [ "$agent_kind" = "map" ] || [ "$agent_kind" = "object" ]; then
            for setting in temperature top_p steps maxSteps variant prompt color disable hidden; do
                local setting_val
                setting_val=$(yq ".configs[$profile_idx].models.$agent_type.$setting // null" "$SDD_CONFIGS_YAML")
                
                if [ "$setting_val" != "null" ] && [ -n "$setting_val" ]; then
                    if [ "$setting_val" = "true" ] || [ "$setting_val" = "false" ]; then
                        json_output+=",""\n"
                        json_output+='      "'$setting'": '$setting_val
                    elif [[ "$setting_val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        json_output+=",""\n"
                        json_output+='      "'$setting'": '$setting_val
                    else
                        json_output+=",""\n"
                        json_output+='      "'$setting'": "'$setting_val'"'
                    fi
                fi
            done
            
            local mode_val
            mode_val=$(yq ".configs[$profile_idx].models.$agent_type.mode // null" "$SDD_CONFIGS_YAML")
            if [ "$mode_val" != "null" ] && [ -n "$mode_val" ]; then
                json_output+=",""\n"
                json_output+='      "mode": "'$mode_val'"'
            fi
            
            local options_val
            options_val=$(yq -o=json ".configs[$profile_idx].models.$agent_type.options // null" "$SDD_CONFIGS_YAML" 2>/dev/null | tr -d '\n')
            if [ "$options_val" != "null" ] && [ -n "$options_val" ] && [ "$options_val" != "{}" ] && [ "$options_val" != "null" ]; then
                json_output+=",""\n"
                json_output+='      "options": '$options_val
            fi
        fi
        
        json_output+=",""\n"
        json_output+='      "description": "'$description'"'"\n"
        json_output+='    }'
    done
    
    json_output+="\n"
    json_output+='  },'"\n"
    json_output+='  "default_agent": "build"'"\n"
    json_output+="}"
    
    printf "%b" "$json_output" > "$OPENCODE_JSON"
    
    printf "${GREEN}✓ Configuration saved to: $OPENCODE_JSON${NC}\n"
    printf "  Profile: $profile_name\n"
    echo ""
    printf "${BLUE}Models configured:${NC}\n"
    
    for agent_type in plan build explore general; do
        local model_val
        model_val=$(get_model_value "$profile_idx" "$agent_type")
        printf "  $agent_type: $model_val"
        
        local agent_kind
        agent_kind=$(yq ".configs[$profile_idx].models.$agent_type | kind" "$SDD_CONFIGS_YAML" 2>/dev/null || echo "null")
        
        if [ "$agent_kind" = "map" ] || [ "$agent_kind" = "object" ]; then
            local has_settings=false
            for field in temperature top_p steps variant mode; do
                local field_val
                field_val=$(yq ".configs[$profile_idx].models.$agent_type.$field // null" "$SDD_CONFIGS_YAML")
                if [ "$field_val" != "null" ] && [ -n "$field_val" ]; then
                    if [ "$has_settings" = false ]; then
                        printf " ("
                        has_settings=true
                    else
                        printf ", "
                    fi
                    printf "$field=$field_val"
                fi
            done
            if [ "$has_settings" = true ]; then
                printf ")"
            fi
        fi
        printf "\n"
    done
}

# Apply profile to opencode.json
apply_profile() {
    local profile_name=$1
    
    if ! verify_yaml > /dev/null 2>&1; then
        printf "${RED}Error: YAML configuration is invalid. Run --verify for details.${NC}\n"
        exit 1
    fi
    
    local configs_count
    configs_count=$(yq '.configs | length' "$SDD_CONFIGS_YAML")
    
    local found=false
    local i=0
    while [ "$i" -lt "$configs_count" ]; do
        local name
        name=$(yq ".configs[$i].name" "$SDD_CONFIGS_YAML")
        if [ "$name" = "$profile_name" ]; then
            found=true
            break
        fi
        i=$((i + 1))
    done
    
    if [ "$found" != true ]; then
        printf "${RED}Error: Profile '$profile_name' not found in $SDD_CONFIGS_YAML${NC}\n"
        printf "Run --list to see available profiles.\n"
        exit 1
    fi
    
    generate_config "$profile_name"
    
    echo ""
    set_active_profile "$profile_name"
}

# Set profile as active
set_active_profile() {
    local profile_name=$1
    
    if ! verify_yaml > /dev/null 2>&1; then
        printf "${RED}Error: YAML configuration is invalid. Run --verify for details.${NC}\n"
        exit 1
    fi
    
    local configs_count
    configs_count=$(yq '.configs | length' "$SDD_CONFIGS_YAML")
    
    local found=false
    local i=0
    while [ "$i" -lt "$configs_count" ]; do
        local name
        name=$(yq ".configs[$i].name" "$SDD_CONFIGS_YAML")
        if [ "$name" = "$profile_name" ]; then
            found=true
            break
        fi
        i=$((i + 1))
    done
    
    if [ "$found" != true ]; then
        printf "${RED}Error: Profile '$profile_name' not found${NC}\n"
        exit 1
    fi
    
    yq -i '(.. | select(has("active")).active) = false' "$SDD_CONFIGS_YAML"
    yq -i "(.configs[] | select(.name == \"$profile_name\").active) = true" "$SDD_CONFIGS_YAML"
    
    printf "${GREEN}✓ Profile '$profile_name' is now active${NC}\n"
}

# Show current configuration
show_current_config() {
    print_header
    
    if [ -f "$OPENCODE_JSON" ]; then
        printf "${GREEN}Current configuration ($OPENCODE_JSON):${NC}\n"
        echo ""
        cat "$OPENCODE_JSON"
        echo ""
    else
        printf "${YELLOW}No opencode.json found at $OPENCODE_JSON${NC}\n"
        echo ""
    fi
    
    printf "${BLUE}SDD Phase → Agent Type Mapping:${NC}\n"
    echo ""
    echo "  ┌─────────────────┬──────────────┬─────────────────────────────────────────────┐"
    echo "  │ SDD Phase       │ Agent Type   │ Purpose                                     │"
    echo "  ├─────────────────┼──────────────┼─────────────────────────────────────────────┤"
    echo "  │ sdd-init        │ general      │ Bootstrap project structure                 │"
    echo "  │ sdd-explore     │ explore      │ Investigate codebase and options            │"
    echo "  │ sdd-propose     │ plan         │ Create change proposals                     │"
    echo "  │ sdd-spec        │ plan         │ Write specifications                        │"
    echo "  │ sdd-design      │ plan         │ Technical architecture                      │"
    echo "  │ sdd-tasks       │ general      │ Break down implementation tasks             │"
    echo "  │ sdd-apply       │ build        │ Implement code                              │"
    echo "  │ sdd-verify      │ explore      │ Validate implementation                     │"
    echo "  │ sdd-archive     │ general      │ Archive completed changes                   │"
    echo "  └─────────────────┴──────────────┴─────────────────────────────────────────────┘"
    echo ""
}

# Interactive mode
interactive_mode() {
    print_header
    
    if [ ! -f "$SDD_CONFIGS_YAML" ]; then
        printf "${YELLOW}Configuration file not found: $SDD_CONFIGS_YAML${NC}\n"
        printf "${BLUE}Copy example config? (Y/n): ${NC}"
        read response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            copy_example_config
        else
            printf "${RED}Cannot proceed without configuration file.${NC}\n"
            exit 1
        fi
        return
    fi
    
    if ! verify_yaml > /dev/null 2>&1; then
        printf "${RED}Error: Configuration is invalid. Run with --verify for details.${NC}\n"
        exit 1
    fi
    
    printf "${BLUE}Available profiles:${NC}\n"
    echo ""
    
    local configs_count
    configs_count=$(yq '.configs | length' "$SDD_CONFIGS_YAML")
    
    local i=0
    while [ "$i" -lt "$configs_count" ]; do
        local name active
        name=$(yq ".configs[$i].name" "$SDD_CONFIGS_YAML")
        active=$(yq ".configs[$i].active" "$SDD_CONFIGS_YAML")
        
        if [ "$active" = "true" ]; then
            printf "  $((i + 1)). $name ${GREEN}[ACTIVE]${NC}\n"
        else
            printf "  $((i + 1)). $name\n"
        fi
        
        i=$((i + 1))
    done
    
    echo ""
    printf "${CYAN}Select profile to apply (1-$configs_count): ${NC}"
    read selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$configs_count" ]; then
        printf "${RED}Invalid selection${NC}\n"
        exit 1
    fi
    
    local idx=$((selection - 1))
    local selected_name
    selected_name=$(yq ".configs[$idx].name" "$SDD_CONFIGS_YAML")
    
    echo ""
    apply_profile "$selected_name"
}

# Main argument parsing
if [ $# -eq 0 ]; then
    interactive_mode
    exit 0
fi

while [ $# -gt 0 ]; do
    case $1 in
        --list)
            list_profiles
            exit 0
            ;;
        --verify)
            verify_yaml
            exit 0
            ;;
        --config)
            if [ -z "$2" ]; then
                printf "${RED}Error: --config requires a profile name${NC}\n"
                exit 1
            fi
            apply_profile "$2"
            exit 0
            ;;
        --set-active)
            if [ -z "$2" ]; then
                printf "${RED}Error: --set-active requires a profile name${NC}\n"
                exit 1
            fi
            set_active_profile "$2"
            exit 0
            ;;
        --copy-example)
            copy_example_config
            exit 0
            ;;
        --show)
            show_current_config
            exit 0
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            printf "${RED}Unknown option: $1${NC}\n"
            print_usage
            exit 1
            ;;
    esac
    shift
done
