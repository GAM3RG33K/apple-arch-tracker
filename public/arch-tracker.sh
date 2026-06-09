#!/bin/bash

# =================================================================================
# Mac Architecture Tracker (arch-tracker.sh) - v1.1
# A lightweight, dependency-free CLI tool to audit macOS apps, Homebrew formulas,
# services, and global NPM modules for native Apple Silicon (arm64) support.
# =================================================================================

# Color variables using ANSI escape codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default scan options
SCAN_APPS=false
SCAN_BREW=false
SCAN_NPM=false
OUTPUT_REPORT=false
CUSTOM_PATH=""

# Determine default behavior (if no flags are specified, scan everything)
parse_arguments() {
    # If no flags are passed, toggle all modules to true
    if [ $# -eq 0 ]; then
        SCAN_APPS=true
        SCAN_BREW=true
        SCAN_NPM=true
        return
    fi

    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -a|--apps)
                SCAN_APPS=true
                shift
                ;;
            -b|--brew)
                SCAN_BREW=true
                shift
                ;;
            -n|--npm)
                SCAN_NPM=true
                shift
                ;;
            -r|--report)
                OUTPUT_REPORT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                # If it's a path and not starting with a hyphen
                if [[ ! "$key" =~ ^- ]]; then
                    CUSTOM_PATH="$key"
                else
                    echo -e "${RED}Error: Unknown option $key${NC}"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # If flags were passed but they were specific path parameters or all false, check
    if [ "$SCAN_APPS" = false ] && [ "$SCAN_BREW" = false ] && [ "$SCAN_NPM" = false ]; then
        if [ -n "$CUSTOM_PATH" ]; then
            # If only a custom path was specified, analyze APPS in that path
            SCAN_APPS=true
        else
            SCAN_APPS=true
            SCAN_BREW=true
            SCAN_NPM=true
        fi
    fi
}

show_help() {
    echo -e "${BOLD}Mac Architecture Tracker v1.1${NC}"
    echo -e "Usage: $0 [options] [custom_applications_path]"
    echo ""
    echo "Options:"
    echo "  -a, --apps         Scan macOS Application bundles only."
    echo "  -b, --brew         Scan Homebrew formulae, casks, and background services."
    echo "  -n, --npm          Scan globally installed NPM packages for binary addons."
    echo "  -r, --report       Generate a standalone HTML dashboard bridge."
    echo "  -h, --help         Display this help message."
    echo ""
    echo "Examples:"
    echo "  $0                 Full audit of Apps, Homebrew, and NPM modules."
    echo "  $0 --report        Generate standalone visualizer report."
    echo "  $0 --apps          Only inspect files inside /Applications."
    echo "  $0 /Users/username/Applications"
}

# General header helper
print_section_header() {
    local title="$1"
    echo "================================================================================="
    echo -e "${BOLD}${title}${NC}"
    echo "================================================================================="
}

# Helper to format output table rows
print_row() {
    local col1="$1"
    local col2="$2"
    local color="$3"
    printf "%-55s | %b%s%b\n" "$col1" "$color" "$col2" "$NC"
}

# Check architecture of a binary file using lipo
get_binary_arch() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "Missing"
        return
    fi
    
    # Run lipo to check architectures
    local lipo_out
    lipo_out=$(lipo -info "$file_path" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$lipo_out" ]; then
        # Check if file command provides hints
        local file_out
        file_out=$(file "$file_path" 2>/dev/null)
        if [[ "$file_out" =~ "arm64" && "$file_out" =~ "x86_64" ]]; then
            echo "Universal"
        elif [[ "$file_out" =~ "arm64" ]]; then
            echo "arm64"
        elif [[ "$file_out" =~ "x86_64" ]]; then
            echo "x86_64"
        else
            echo "Unknown"
        fi
        return
    fi
    
    # Analyze lipo -info output
    # Format of lipo -info: "Architectures in the fat file: <file> are: x86_64 arm64" or "Non-fat file: <file> is architecture: arm64"
    if [[ "$lipo_out" =~ "x86_64" && "$lipo_out" =~ "arm64" ]]; then
        echo "Universal"
    elif [[ "$lipo_out" =~ "arm64" ]]; then
        echo "arm64"
    elif [[ "$lipo_out" =~ "x86_64" ]]; then
        echo "x86_64"
    else
        echo "Unknown"
    fi
}

# MODULE A: macOS Applications
scan_applications() {
    print_section_header "MODULE 1: MAC OBJECTS & APPLICATIONS"
    printf "%-55s | %s\n" "Application Name" "Architecture"
    echo "---------------------------------------------------------------------------------"

    local search_dir="/Applications"
    if [ -n "$CUSTOM_PATH" ]; then
        search_dir="$CUSTOM_PATH"
    fi

    if [ ! -d "$search_dir" ]; then
        echo -e "${RED}Warning: Directory '$search_dir' does not exist. Skipping...${NC}"
        echo ""
        return
    fi

    # Find .app bundles in Applications path, limiting to depth 2 to keep it fast
    find "$search_dir" -maxdepth 2 -name "*.app" -type d 2>/dev/null | sort | while read -r app_path; do
        local app_name
        app_name=$(basename "$app_path")
        
        # Read the Info.plist to find the actual executable name
        local exe_name=""
        if [ -f "$app_path/Contents/Info.plist" ]; then
            # Fast XML plist parse for CFBundleExecutable
            exe_name=$(defaults read "$app_path/Contents/Info" CFBundleExecutable 2>/dev/null)
        fi
        
        # If no custom executable was declared in plist, try the app's base name
        if [ -z "$exe_name" ]; then
            exe_name="${app_name%.app}"
        fi
        
        local exe_path="$app_path/Contents/MacOS/$exe_name"
        
        if [ -f "$exe_path" ]; then
            local arch
            arch=$(get_binary_arch "$exe_path")
            
            case "$arch" in
                "Universal")
                    print_row "$app_name" "Universal" "$GREEN"
                    ;;
                "arm64")
                    print_row "$app_name" "Apple Silicon (arm64)" "$CYAN"
                    ;;
                "x86_64")
                    print_row "$app_name" "Intel Only (x86_64)" "$RED"
                    ;;
                *)
                    print_row "$app_name" "Unknown Architecture" "$YELLOW"
                    ;;
            esac
        else
            # Some apps might contain helper executables but lipo binary is missing
            print_row "$app_name" "Structure Only" "$YELLOW"
        fi
    done
    echo ""
}

# MODULE B: Homebrew Packages
scan_homebrew() {
    print_section_header "MODULE 2: HOMEBREW FORMULAE & SERVICES"
    printf "%-55s | %s\n" "Command/Service Name" "Architecture"
    echo "---------------------------------------------------------------------------------"

    # Check if brew exists
    if ! command -v brew &>/dev/null; then
        echo -e "${YELLOW}Warning: Homebrew (brew) is not installed on this host. Skipping Module B.${NC}"
        echo ""
        return
    fi

    local brew_prefix
    brew_prefix=$(brew --prefix 2>/dev/null)
    
    # 1. Active background services
    if command -v brew &>/dev/null; then
        # Run brew services to identify active background launchagents
        local services_list
        services_list=$(brew services list 2>/dev/null | grep "started" | awk '{print $1}')
        
        if [ -n "$services_list" ]; then
            for svc in $services_list; do
                # Determine binary path of service from cellars
                local svc_bin=""
                # Standard locations inside Cellar
                local cellar_matches
                cellar_matches=$(find "$brew_prefix/Cellar/$svc" -maxdepth 3 -type f -perm +111 -name "$svc" 2>/dev/null | head -n 1)
                
                if [ -n "$cellar_matches" ]; then
                    svc_bin="$cellar_matches"
                elif command -v "$svc" &>/dev/null; then
                    svc_bin=$(which "$svc")
                fi
                
                if [ -f "$svc_bin" ]; then
                    local arch
                    arch=$(get_binary_arch "$svc_bin")
                    
                    case "$arch" in
                        "Universal")
                            print_row "$svc (Service)" "Universal" "$GREEN"
                            ;;
                        "arm64")
                            print_row "$svc (Service)" "Apple Silicon (arm64)" "$CYAN"
                            ;;
                        "x86_64")
                            print_row "$svc (Service)" "Intel Only (x86_64)" "$RED"
                            ;;
                        *)
                            print_row "$svc (Service)" "Unknown Architecture" "$YELLOW"
                            ;;
                    esac
                else
                    print_row "$svc (Service)" "Service Running (Active)" "$CYAN"
                fi
            done
        fi
    fi

    # 2. General Brew Formulae (analyzing main binaries)
    brew list --formula 2>/dev/null | sort | while read -r formula; do
        local tool_bin=""
        if [ -x "$brew_prefix/bin/$formula" ]; then
            tool_bin="$brew_prefix/bin/$formula"
        else
            # Try finding an executable file in cellar matching formula name
            local formula_cellar
            formula_cellar=$(find "$brew_prefix/Cellar/$formula" -maxdepth 3 -type f -perm +111 -maxdepth 4 2>/dev/null | head -n 1)
            if [ -n "$formula_cellar" ]; then
                tool_bin="$formula_cellar"
            fi
        fi

        if [ -n "$tool_bin" ] && [ -f "$tool_bin" ]; then
            local arch
            arch=$(get_binary_arch "$tool_bin")
            case "$arch" in
                "Universal")
                    print_row "$formula (Binary)" "Universal" "$GREEN"
                    ;;
                "arm64")
                    print_row "$formula (Binary)" "Apple Silicon (arm64)" "$CYAN"
                    ;;
                "x86_64")
                    print_row "$formula (Binary)" "Intel Only (x86_64)" "$RED"
                    ;;
                *)
                    print_row "$formula (Binary)" "Unknown Architecture" "$YELLOW"
                    ;;
            esac
        else
            print_row "$formula (Formula)" "Meta Package/Script" "$GREEN"
        fi
    done

    # 3. Brew Casks
    brew list --cask 2>/dev/null | sort | while read -r cask; do
        # Most casks install to /Applications or contain target app structures
        # We can find where brew info tells us the metadata points to
        local app_target=""
        app_target=$(find "/Applications" -maxdepth 2 -iname "$cask.app" -type d 2>/dev/null | head -n 1)
        
        if [ -n "$app_target" ] && [ -d "$app_target" ]; then
            # Read Info.plist to find executable
            local exe_name=""
            exe_name=$(defaults read "$app_target/Contents/Info" CFBundleExecutable 2>/dev/null)
            [ -z "$exe_name" ] && exe_name="${cask}"
            
            local exe_path="$app_target/Contents/MacOS/$exe_name"
            if [ -f "$exe_path" ]; then
                local arch
                arch=$(get_binary_arch "$exe_path")
                case "$arch" in
                    "Universal")
                        print_row "$cask (Cask)" "Universal" "$GREEN"
                        ;;
                    "arm64")
                        print_row "$cask (Cask)" "Apple Silicon (arm64)" "$CYAN"
                        ;;
                    "x86_64")
                        print_row "$cask (Cask)" "Intel Only (x86_64)" "$RED"
                        ;;
                    *)
                        print_row "$cask (Cask)" "Unknown Architecture" "$YELLOW"
                        ;;
                esac
                continue
            fi
        fi
        
        # Fallback if no app bundle can be matched, just mark as installed Cask
        print_row "$cask (Cask)" "Installed via Cask" "$GREEN"
    done
    echo ""
}

# MODULE C: Global NPM Packages
scan_npm() {
    print_section_header "MODULE 3: GLOBAL NPM PACKAGES"
    printf "%-55s | %s\n" "Package Name [Binary/Addon]" "Architecture"
    echo "---------------------------------------------------------------------------------"

    # Check if npm is installed
    if ! command -v npm &>/dev/null; then
        echo -e "${YELLOW}Warning: NPM (npm) is not installed on this host. Skipping Module C.${NC}"
        echo ""
        return
    fi

    # Retrieve global node_modules root path
    local npm_global_root
    npm_global_root=$(npm root -g 2>/dev/null)
    
    if [ -z "$npm_global_root" ] || [ ! -d "$npm_global_root" ]; then
        echo -e "${YELLOW}Warning: Unable to locate global NPM folder. Skipping Module C.${NC}"
        echo ""
        return
    fi

    # Read the top-level modules
    npm list -g --depth=0 --json 2>/dev/null | grep -E '"dependencies":' -A 1000 | grep -E '"[^"]+": \{' | awk -F'"' '{print $2}' | sort | while read -r pkg; do
        if [ -z "$pkg" ]; then continue; fi
        
        local pkg_path="$npm_global_root/$pkg"
        if [ ! -d "$pkg_path" ]; then continue; fi

        # Find compiled native binary extensions (.node files)
        local native_addons
        native_addons=$(find "$pkg_path" -name "*.node" -type f 2>/dev/null)

        if [ -n "$native_addons" ]; then
            # The package has native binary compiled bindings! Output architecture for each
            echo "$native_addons" | while read -r addon; do
                local addon_file
                addon_file=$(basename "$addon")
                local arch
                arch=$(get_binary_arch "$addon")
                
                case "$arch" in
                    "Universal")
                        print_row "$pkg [$addon_file]" "Universal" "$GREEN"
                        ;;
                    "arm64")
                        print_row "$pkg [$addon_file]" "Apple Silicon (arm64)" "$CYAN"
                        ;;
                    "x86_64")
                        print_row "$pkg [$addon_file]" "Intel Only (x86_64)" "$RED"
                        ;;
                    *)
                        print_row "$pkg [$addon_file]" "Unknown Architecture" "$YELLOW"
                        ;;
                esac
            done
        else
            # No binary files - standard architecture agnostic JS/TS modules
            print_row "$pkg" "JavaScript (Platform Agnostic)" "$GREEN"
        fi
    done
    echo ""
}

# =================================================================================
# Main script execution
# =================================================================================

parse_arguments "$@"

run_scans() {
    if [ "$SCAN_APPS" = true ]; then scan_applications; fi
    if [ "$SCAN_BREW" = true ]; then scan_homebrew; fi
    if [ "$SCAN_NPM" = true ]; then scan_npm; fi
    echo "================================================================================="
    echo "Audit complete. Run under native terminal sessions to ensure 100% arm64 compliance."
    echo "================================================================================="
}

if [ "$OUTPUT_REPORT" = true ]; then
    REPORT_NAME="mac-arch-report-$(date +%s)"
    TMP_LOG="/tmp/${REPORT_NAME}.log"
    HTML_FILE="${REPORT_NAME}.html"
    
    run_scans | tee "$TMP_LOG"
    
    # Base64 encode removing newlines for safe inline JS
    B64_LOG=$(base64 -i "$TMP_LOG" | tr -d '\n')
    
    cat << HTML_EOF > "$HTML_FILE"
<!DOCTYPE html>
<html>
<head><title>Loading Report...</title></head>
<body style="background:#0b0f19; color:#fff; font-family:monospace; padding: 2rem;">
<h2>Redirecting to Architecture Dashboard...</h2>
<script>
try {
    const rawLog = decodeURIComponent(escape(atob("${B64_LOG}")));
    localStorage.setItem('mac-arch-tracker-raw-log', rawLog);
    // Automatically forwards you to the Github Pages Dashboard Viewer
    window.location.href = 'https://GAM3RG33K.github.io/apple-arch-tracker/';
} catch(e) {
    document.body.innerHTML += '<p style="color:red">Error parsing report data.</p>';
}
</script>
</body>
</html>
HTML_EOF

    echo -e "\n${GREEN}Interactive Report Generated: ${BOLD}${HTML_FILE}${NC}"
    echo -e "Open ${HTML_FILE} in your browser. It will load the UI Dashboard and inject this report locally."
    rm -f "$TMP_LOG"
else
    run_scans
fi

