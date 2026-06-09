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
    printf "%-35s | %-50s | %s\n" "Application Name" "Path" "Architecture"
    echo "---------------------------------------------------------------------------------------------------------"

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
                    printf "%-35s | %-50s | %b%s%b\n" "$app_name" "$app_path" "$GREEN" "Universal" "$NC"
                    ;;
                "arm64")
                    printf "%-35s | %-50s | %b%s%b\n" "$app_name" "$app_path" "$CYAN" "Apple Silicon (arm64)" "$NC"
                    ;;
                "x86_64")
                    printf "%-35s | %-50s | %b%s%b\n" "$app_name" "$app_path" "$RED" "Intel Only (x86_64)" "$NC"
                    ;;
                *)
                    printf "%-35s | %-50s | %b%s%b\n" "$app_name" "$app_path" "$YELLOW" "Unknown Architecture" "$NC"
                    ;;
            esac
        else
            # Some apps might contain helper executables but lipo binary is missing
            printf "%-35s | %-50s | %b%s%b\n" "$app_name" "$app_path" "$YELLOW" "Structure Only" "$NC"
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
    
    cat << 'HTML_EOF' > "$HTML_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Mac Architecture Tracker - Audit Report</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{--bg:#070b13;--card:#111827;--card2:#0d1525;--border:#1e293b;--text:#e5e7eb;--dim:#6b7280;--accent:#6366f1;--green:#10b981;--cyan:#06b6d4;--red:#f43f5e;--amber:#f59e0b;--font:'Inter',system-ui,-apple-system,sans-serif;--mono:'SF Mono','Cascadia Code','Consolas',monospace}
body{background:var(--bg);color:var(--text);font-family:var(--font);min-height:100vh;line-height:1.5}
::-webkit-scrollbar{width:6px}::-webkit-scrollbar-track{background:#111827}::-webkit-scrollbar-thumb{background:#374151;border-radius:3px}

.container{max-width:1200px;margin:0 auto;padding:1.5rem}

/* Header */
.header{display:flex;align-items:center;justify-content:space-between;padding:1rem 0;border-bottom:1px solid var(--border);margin-bottom:1.5rem}
.header h1{font-size:1.25rem;font-weight:700;color:#fff}
.header .subtitle{font-size:0.7rem;color:var(--dim);font-family:var(--mono)}
.header .back-btn{font-size:0.75rem;background:var(--card);border:1px solid var(--border);color:var(--dim);padding:0.375rem 0.75rem;border-radius:6px;cursor:pointer;font-family:var(--mono);transition:all 0.15s}
.header .back-btn:hover{background:#1a2332;color:#fff}

/* Metrics Grid */
.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:1rem;margin-bottom:1.5rem}
.metric-card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:1rem;position:relative;overflow:hidden}
.metric-card .label{font-size:0.65rem;font-family:var(--mono);text-transform:uppercase;letter-spacing:0.05em;color:var(--dim);margin-bottom:0.5rem;display:flex;align-items:center;justify-content:space-between}
.metric-card .value{font-size:2rem;font-weight:800;color:#fff;line-height:1}
.metric-card .sub{font-size:0.6rem;color:var(--dim);font-family:var(--mono);margin-top:0.5rem}
.metric-card.grade{text-align:center;display:flex;flex-direction:column;align-items:center;justify-content:center}
.metric-card.grade .value{font-size:2.5rem}
.grade-a{border-color:rgba(16,185,129,0.3);background:rgba(16,185,129,0.05)}
.grade-a .value{color:var(--green)}
.grade-b{border-color:rgba(6,182,212,0.3);background:rgba(6,182,212,0.05)}
.grade-b .value{color:var(--cyan)}
.grade-c{border-color:rgba(245,158,11,0.3);background:rgba(245,158,11,0.05)}
.grade-c .value{color:var(--amber)}
.grade-f{border-color:rgba(244,63,94,0.3);background:rgba(244,63,94,0.05)}
.grade-f .value{color:var(--red)}

/* Ratio Bar */
.ratio-bar{height:8px;background:#1f2937;border-radius:4px;overflow:hidden;margin-top:0.5rem}
.ratio-fill{height:100%;border-radius:4px;transition:width 0.6s ease}

/* Charts Row */
.charts-row{display:grid;grid-template-columns:7fr 5fr;gap:1rem;margin-bottom:1.5rem}
.chart-card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:1.25rem}
.chart-card .card-title{font-size:0.7rem;font-family:var(--mono);text-transform:uppercase;letter-spacing:0.05em;color:var(--dim);margin-bottom:0.75rem;font-weight:600}

/* Reasons */
.reasons{max-height:180px;overflow-y:auto;display:flex;flex-direction:column;gap:0.5rem}
.reason-item{display:flex;gap:0.625rem;align-items:flex-start;padding:0.625rem;border-radius:8px;background:rgba(0,0,0,0.3);border:1px solid rgba(30,41,59,0.5);font-size:0.7rem;color:#d1d5db;line-height:1.5}
.reason-icon{flex-shrink:0;width:16px;height:16px;margin-top:1px}
.reason-icon.ok{color:var(--green)}
.reason-icon.warn{color:var(--accent)}

/* Pie Chart */
.pie-wrap{display:flex;flex-direction:column;align-items:center;gap:0.75rem}
.pie-legend{display:flex;flex-wrap:wrap;gap:0.5rem;justify-content:center}
.pie-legend-item{display:flex;align-items:center;gap:0.375rem;font-size:0.6rem;color:var(--dim);font-family:var(--mono)}
.pie-legend-dot{width:8px;height:8px;border-radius:50%}

/* Controls */
.controls{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:1rem;display:flex;align-items:center;justify-content:space-between;gap:1rem;margin-bottom:1.5rem;flex-wrap:wrap}
.filter-pills{display:flex;gap:0.5rem;flex-wrap:wrap}
.pill{padding:0.25rem 0.75rem;border-radius:9999px;font-size:0.65rem;font-family:var(--mono);font-weight:500;border:1px solid var(--border);background:var(--bg);color:var(--dim);cursor:pointer;transition:all 0.15s;white-space:nowrap}
.pill:hover{border-color:#374151;color:#fff}
.pill.active{background:var(--accent);color:#fff;border-color:transparent}
.pill.active-cyan{background:rgba(6,182,212,0.15);color:var(--cyan);border-color:rgba(6,182,212,0.3)}
.pill.active-amber{background:rgba(245,158,11,0.15);color:var(--amber);border-color:rgba(245,158,11,0.3)}
.pill.active-indigo{background:rgba(99,102,241,0.15);color:#818cf8;border-color:rgba(99,102,241,0.3)}
.search-box{position:relative;width:220px}
.search-box input{width:100%;padding:0.375rem 0.75rem 0.375rem 2rem;background:var(--bg);border:1px solid var(--border);border-radius:8px;color:var(--text);font-size:0.7rem;font-family:var(--mono);outline:none;transition:border-color 0.15s}
.search-box input:focus{border-color:var(--accent)}
.search-box svg{position:absolute;left:0.625rem;top:50%;transform:translateY(-50%);width:14px;height:14px;color:var(--dim)}

/* Issue Cards */
.issues-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:0.75rem}
.issues-header h3{font-size:0.75rem;font-family:var(--mono);text-transform:uppercase;letter-spacing:0.05em;color:var(--dim);font-weight:600}
.issues-header span{font-size:0.6rem;color:#4b5563;font-family:var(--mono)}
.issue-list{display:flex;flex-direction:column;gap:0.625rem}
.issue-card{background:var(--card);border:1px solid var(--border);border-radius:8px;overflow:hidden;cursor:pointer;transition:all 0.15s}
.issue-card:hover{border-color:#374151;background:#151c2e}
.issue-card.expanded{border-color:var(--accent);box-shadow:0 0 20px rgba(99,102,241,0.1)}
.issue-header{display:flex;align-items:center;gap:0.75rem;padding:1rem}
.issue-badge{padding:0.5rem;border-radius:6px;background:rgba(0,0,0,0.4);border:1px solid var(--border);font-family:var(--mono);font-size:0.7rem;font-weight:700;color:var(--red);flex-shrink:0}
.issue-info{flex:1;min-width:0}
.issue-name{font-weight:600;font-size:0.8rem;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.issue-tag{display:inline-flex;align-items:center;gap:0.25rem;font-size:0.6rem;font-family:var(--mono);font-weight:500;padding:0.125rem 0.5rem;border-radius:9999px;margin-top:0.25rem}
.tag-app{background:rgba(99,102,241,0.1);color:#a5b4fc;border:1px solid rgba(99,102,241,0.2)}
.tag-brew{background:rgba(6,182,212,0.1);color:var(--cyan);border:1px solid rgba(6,182,212,0.2)}
.tag-npm{background:rgba(245,158,11,0.1);color:var(--amber);border:1px solid rgba(245,158,11,0.2)}
.issue-desc{font-size:0.65rem;color:var(--dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:0.25rem}
.issue-path{font-size:0.6rem;color:#4b5563;font-family:var(--mono);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:0.125rem}
.issue-chevron{flex-shrink:0;color:var(--dim);transition:transform 0.15s}
.issue-card.expanded .issue-chevron{transform:rotate(180deg)}
.issue-body{display:none;padding:1rem;border-top:1px solid var(--border);background:rgba(0,0,0,0.2);cursor:default}
.issue-card.expanded .issue-body{display:block}
.diag-label{font-size:0.65rem;font-family:var(--mono);font-weight:600;color:var(--red);margin-bottom:0.25rem}
.diag-text{font-size:0.7rem;color:#d1d5db;line-height:1.6;margin-bottom:0.75rem}
.path-label{font-size:0.65rem;font-family:var(--mono);font-weight:600;color:var(--dim);margin-bottom:0.25rem}
.path-value{font-size:0.7rem;color:var(--cyan);font-family:var(--mono);background:rgba(0,0,0,0.4);padding:0.25rem 0.5rem;border-radius:4px;display:inline-block;margin-bottom:0.75rem;word-break:break-all}
.remedy-label{font-size:0.65rem;font-family:var(--mono);font-weight:600;color:var(--green);margin-bottom:0.25rem}
.remedy-code{display:flex;align-items:center;background:rgba(0,0,0,0.8);border:1px solid var(--border);border-radius:6px;overflow:hidden;margin-bottom:0.75rem}
.remedy-code code{flex:1;padding:0.625rem;font-family:var(--mono);font-size:0.65rem;color:var(--amber);white-space:pre-wrap;word-break:break-all}
.remedy-code .copy-btn{padding:0.625rem;color:var(--dim);border-left:1px solid var(--border);cursor:pointer;background:transparent;transition:all 0.15s}
.remedy-code .copy-btn:hover{background:rgba(255,255,255,0.05);color:#fff}
.info-box{display:flex;gap:0.5rem;align-items:flex-start;padding:0.625rem;border-radius:6px;background:rgba(99,102,241,0.05);border:1px solid rgba(99,102,241,0.15);font-size:0.6rem;color:#818cf8;line-height:1.5}
.info-box svg{flex-shrink:0;width:14px;height:14px;margin-top:1px}

/* Log Editor */
.log-editor{background:var(--card);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin-top:1.5rem}
.log-editor-header{display:flex;align-items:center;justify-content:space-between;padding:0.75rem 1.25rem;background:var(--card2);border-bottom:1px solid var(--border);cursor:pointer;user-select:none}
.log-editor-header h3{font-size:0.75rem;font-family:var(--mono);text-transform:uppercase;letter-spacing:0.05em;color:var(--dim);font-weight:600;display:flex;align-items:center;gap:0.5rem}
.log-editor-header .toggle{font-size:0.65rem;color:#4b5563;font-family:var(--mono);transition:transform 0.15s}
.log-editor-body{display:none;padding:1.25rem}
.log-editor-body.open{display:block}
.log-editor-body textarea{width:100%;min-height:200px;background:var(--bg);border:1px solid var(--border);border-radius:8px;padding:1rem;font-family:var(--mono);font-size:0.65rem;color:var(--text);resize:vertical;outline:none;line-height:1.6}
.log-editor-body textarea:focus{border-color:var(--accent)}
.log-editor-actions{display:flex;gap:0.75rem;margin-top:0.75rem;align-items:center}
.btn{padding:0.5rem 1.25rem;border-radius:8px;font-size:0.75rem;font-weight:600;font-family:var(--mono);cursor:pointer;transition:all 0.15s;border:none}
.btn-primary{background:var(--accent);color:#fff}
.btn-primary:hover{background:#4f46e5}
.btn-secondary{background:var(--bg);color:var(--dim);border:1px solid var(--border)}
.btn-secondary:hover{border-color:#374151;color:#fff}
.log-status{font-size:0.65rem;color:var(--dim);font-family:var(--mono)}

/* Empty State */
.empty-state{text-align:center;padding:3rem;color:var(--dim)}
.empty-state svg{width:40px;height:40px;margin:0 auto 0.75rem;color:var(--green)}
.empty-state p{font-size:0.8rem;font-weight:600;color:var(--text)}
.empty-state .sub{font-size:0.65rem;color:var(--dim);margin-top:0.25rem}

/* Footer */
.footer{border-top:1px solid var(--border);padding:2rem 0;text-align:center;margin-top:2rem}
.footer p{font-size:0.65rem;color:var(--dim);font-family:var(--mono)}

@media(max-width:768px){.metrics{grid-template-columns:repeat(2,1fr)}.charts-row{grid-template-columns:1fr}.controls{flex-direction:column;align-items:stretch}.search-box{width:100%}}
@media(max-width:480px){.metrics{grid-template-columns:1fr}}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <div>
      <h1>Mac Architecture Tracker</h1>
      <div class="subtitle">Offline Audit Report</div>
    </div>
    <button class="back-btn" onclick="window.location.href='https://GAM3RG33K.github.io/apple-arch-tracker/'">&larr; Full Dashboard</button>
  </div>

  <div id="metrics"></div>
  <div id="charts" class="charts-row"></div>
  <div id="controls"></div>
  <div id="issues"></div>

  <div class="log-editor">
    <div class="log-editor-header" onclick="toggleLogEditor()">
      <h3>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
        Replace Log Data
      </h3>
      <span class="toggle" id="logToggle">&#9660;</span>
    </div>
    <div class="log-editor-body" id="logEditorBody">
      <textarea id="logInput" placeholder="Paste your arch-tracker log output here..."></textarea>
      <div class="log-editor-actions">
        <button class="btn btn-primary" onclick="applyNewLog()">Apply &amp; Refresh</button>
        <button class="btn btn-secondary" onclick="resetLog()">Reset to Original</button>
        <span class="log-status" id="logStatus"></span>
      </div>
    </div>
  </div>

  <div class="footer">
    <p>Generated by Mac Architecture Tracker &mdash; Open Source on <a href="https://github.com/GAM3RG33K/apple-arch-tracker" style="color:#818cf8;text-decoration:none">GitHub</a></p>
  </div>
</div>

<script>
(function(){
  var B64_DATA = "HTML_B64_PLACEHOLDER";
  var originalLog = "";
  var currentLog = "";
  var parsed = null;
  var filter = "all";
  var search = "";

  function init(){
    try {
      originalLog = decodeURIComponent(escape(atob(B64_DATA)));
    } catch(e) {
      originalLog = B64_DATA;
    }
    currentLog = originalLog;
    document.getElementById("logInput").value = originalLog;
    render();
  }

  function parseLog(log){
    var items = [];
    var module = null;
    var lines = log.split("\n");
    var stats = {universal:0,arm64:0,intel:0,jsOnly:0,unknown:0};

    for(var i=0;i<lines.length;i++){
      var line = lines[i].trim();
      if(line.indexOf("MODULE 1:")!==-1){module="applications";continue}
      if(line.indexOf("MODULE 2:")!==-1){module="homebrew";continue}
      if(line.indexOf("MODULE 3:")!==-1){module="npm";continue}
      if(!line||line.charAt(0)==="="||line.charAt(0)==="-")continue;
      if(line.indexOf("Application Name")!==-1||line.indexOf("Command/Service Name")!==-1||line.indexOf("Package Name")!==-1)continue;

      if(line.indexOf("|")!==-1){
        var parts=line.split("|");
        if(parts.length<2)continue;
        var name,arch,itemPath;
        if(parts.length===3){
          name=parts[0].trim();itemPath=parts[1].trim();arch=parts[2].trim();
        } else {
          name=parts[0].trim();arch=parts[1].trim();itemPath=null;
        }
        if(!name||!arch)continue;

        var type="application";
        if(module==="homebrew"){
          type=name.indexOf("(Service)")!==-1?"brew-service":"brew-binary";
        } else if(module==="npm"){
          type=name.indexOf("[")!==-1?"npm-native-addon":"application";
        }

        var al=arch.toLowerCase();
        if(al.indexOf("universal")!==-1)stats.universal++;
        else if(al.indexOf("apple silicon")!==-1||al.indexOf("arm64")!==-1)stats.arm64++;
        else if(al.indexOf("intel")!==-1||al.indexOf("x86_64")!==-1)stats.intel++;
        else if(al.indexOf("javascript")!==-1||al.indexOf("agnostic")!==-1)stats.jsOnly++;
        else stats.unknown++;

        if(al.indexOf("intel")!==-1||al.indexOf("x86_64")!==-1){
          var rec=getRec(name,type);
          items.push({name:name,path:itemPath,type:type,issue:rec.issue,recommendation:rec.recommendation});
        }
      }
    }

    var nativeCount=stats.universal+stats.arm64+stats.jsOnly;
    var total=nativeCount+stats.intel;
    var ratio=total>0?nativeCount/total:1;
    var rating="A+";
    if(stats.intel===0)rating="A+";
    else if(ratio>=0.9)rating="A-";
    else if(ratio>=0.75)rating="B";
    else if(ratio>=0.5)rating="C";
    else rating="F";

    return{stats:stats,total:total,ratio:ratio,rating:rating,items:items};
  }

  function getRec(name,type){
    var n=name.replace(/\.app$/i,"").toLowerCase();
    if(type==="application"){
      var recs={
        discord:{i:"Running legacy Intel version of Discord via Rosetta 2.",r:"Download the Apple Silicon build from discord.com"},
        spotify:{i:"Spotify running on Intel emulation, higher RAM usage.",r:"Get the Apple Silicon version from spotify.com/download/mac/"},
        slack:{i:"Slack running in x86_64 simulation mode.",r:"Download Universal/Apple Silicon Slack from slack.com or Mac App Store."},
        zoom:{i:"Zoom Intel client drains battery during video calls.",r:"Download 'Zoom for IT Admins - Apple Silicon' from zoom.us/download."},
        teams:{i:"Legacy Microsoft Teams running on Intel emulation.",r:"Install the new rebuilt Microsoft Teams with native Apple Silicon support."},
        "virtualbox":{i:"VirtualBox has limited Apple Silicon support.",r:"Migrate to UTM (free, mac.getutm.app) or OrbStack (orbstack.dev)."}
      };
      if(recs[n])return{issue:recs[n].i,recommendation:recs[n].r};
      return{issue:"Running "+name+" under Intel emulation. Demands extra processing power.",recommendation:"Check the software maker's site for an Apple Silicon or Universal macOS build."};
    }
    if(type==="brew-binary"||type==="brew-service"){
      return{issue:name+" is compiled for x86_64. Homebrew may be installed under Rosetta.",recommendation:"Reinstall in a native terminal: brew reinstall "+name.split(" ")[0]};
    }
    if(type==="npm-native-addon"){
      return{issue:"Native C++ addon binaries in '"+name+"' compiled for x86_64.",recommendation:"Rebuild: npm rebuild "+name.split(" ")[0]+" --global"};
    }
    return{issue:"Running under Rosetta emulation.",recommendation:"Reinstall using a native terminal window."};
  }

  function render(){
    parsed=parseLog(currentLog);
    renderMetrics();
    renderCharts();
    renderControls();
    renderIssues();
  }

  function renderMetrics(){
    var s=parsed.stats;
    var g=parsed.rating;
    var gc=g.charAt(0)==="A"?"grade-a":g.charAt(0)==="B"?"grade-b":g.charAt(0)==="C"?"grade-f":"grade-f";
    var pct=(parsed.ratio*100).toFixed(0);
    var barColor=parsed.ratio>0.85?"var(--green)":parsed.ratio>0.6?"var(--cyan)":"var(--red)";

    document.getElementById("metrics").innerHTML='<div class="metrics">'+
      '<div class="metric-card grade '+gc+'"><div class="label">Compliance Grade</div><div class="value">'+g+'</div><div class="sub">'+(s.intel===0?"Full Silicon Pure":s.intel+" Emulated")+'</div></div>'+
      '<div class="metric-card"><div class="label">Native Ratio</div><div class="value">'+pct+'%</div><div class="ratio-bar"><div class="ratio-fill" style="width:'+pct+'%;background:'+barColor+'"></div></div></div>'+
      '<div class="metric-card"><div class="label">Total Audited</div><div class="value">'+parsed.total+'</div><div class="sub">Apps, Packages, Services</div></div>'+
      '<div class="metric-card"><div class="label">Emulated Issues</div><div class="value" style="color:'+(s.intel>0?"var(--red)":"var(--green)")+'">'+s.intel+'</div><div class="sub">Requires native rebuild</div></div>'+
      '</div>';
  }

  function renderCharts(){
    var s=parsed.stats;
    var data=[
      {name:"Universal",value:s.universal,color:"#10b981"},
      {name:"Apple Silicon",value:s.arm64,color:"#06b6d4"},
      {name:"Intel Emulated",value:s.intel,color:"#f43f5e"},
      {name:"JavaScript",value:s.jsOnly,color:"#f59e0b"}
    ].filter(function(d){return d.value>0});

    var reasons=[];
    if(parsed.items.length===0){
      reasons.push('<div class="reason-item"><svg class="reason-icon ok" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg><span>Pristine 100% native environment. Zero Rosetta 2 binaries.</span></div>');
    } else {
      reasons.push('<div class="reason-item"><svg class="reason-icon warn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg><span>Detected '+parsed.items.length+' Intel Only (x86_64) elements running under Rosetta emulation.</span></div>');
      if(parsed.items.length>2)reasons.push('<div class="reason-item"><svg class="reason-icon warn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg><span>Multiple emulated binaries detected. Performance impact is cumulative.</span></div>');
    }

    var pieSvg=buildPie(data,parsed.total);
    document.getElementById("charts").innerHTML=
      '<div class="chart-card"><div class="card-title">Health Check Diagnosis</div><div class="reasons">'+reasons.join("")+'</div></div>'+
      '<div class="chart-card"><div class="card-title">Architecture Allocation</div><div class="pie-wrap">'+pieSvg+'<div class="pie-legend">'+data.map(function(d){return '<div class="pie-legend-item"><div class="pie-legend-dot" style="background:'+d.color+'"></div>'+d.name+' ('+d.value+')</div>'}).join("")+'</div></div></div>';
  }

  function buildPie(data,total){
    if(total===0)return '<svg viewBox="0 0 120 120" width="120" height="120"><circle cx="60" cy="60" r="40" fill="none" stroke="#1f2937" stroke-width="16"/></svg>';
    var cx=60,cy=60,r=40,strokeW=16;
    var cum=0;
    var circ=2*Math.PI*r;
    var segs=data.map(function(d){
      var pct=d.value/total;
      var dash=pct*circ;
      var gap=circ-dash;
      var offset=-cum*circ+circ*0.25;
      cum+=pct;
      return '<circle cx="'+cx+'" cy="'+cy+'" r="'+r+'" fill="none" stroke="'+d.color+'" stroke-width="'+strokeW+'" stroke-dasharray="'+dash+' '+gap+'" stroke-dashoffset="'+offset+'" style="transition:stroke-dasharray 0.6s"/>';
    });
    return '<svg viewBox="0 0 120 120" width="120" height="120">'+segs.join("")+'</svg>';
  }

  function renderControls(){
    var tags={all:"",application:"tag-app","brew-binary":"tag-brew","brew-service":"tag-brew","npm-native-addon":"tag-npm"};
    var labels={all:"All",application:"Applications","brew-binary":"Homebrew","brew-service":"Services","npm-native-addon":"NPM"};
    var pills=["all","application","brew-binary","npm-native-addon"].map(function(f){
      var cls=f===filter?(f==="all"?"pill active":f==="application"?"pill active-indigo":f.indexOf("brew")!==-1?"pill active-cyan":"pill active-amber"):"pill";
      return '<button class="'+cls+'" onclick="setFilter(\''+f+'\')">'+labels[f]+'</button>';
    }).join("");

    document.getElementById("controls").innerHTML='<div class="controls">'+
      '<div class="filter-pills">'+pills+'</div>'+
      '<div class="search-box"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg><input type="text" placeholder="Search..." value="'+search+'" oninput="setSearch(this.value)"></div>'+
      '</div>';
  }

  function renderIssues(){
    var items=parsed.items.filter(function(it){
      if(filter!=="all"){
        if(filter==="brew-binary"&&it.type!=="brew-binary"&&it.type!=="brew-service")return false;
        if(filter!=="brew-binary"&&it.type!==filter)return false;
      }
      if(search){
        var q=search.toLowerCase();
        return it.name.toLowerCase().indexOf(q)!==-1||(it.issue&&it.issue.toLowerCase().indexOf(q)!==-1);
      }
      return true;
    });

    if(items.length===0){
      document.getElementById("issues").innerHTML='<div class="empty-state"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg><p>Compliance Clean!</p><div class="sub">No Intel emulated binaries found.</div></div>';
      return;
    }

    var tagCls={application:"tag-app","brew-binary":"tag-brew","brew-service":"tag-brew","npm-native-addon":"tag-npm"};
    var tagLbl={application:"Application","brew-binary":"Formula Binary","brew-service":"Brew Service","npm-native-addon":"NPM Binary Addon"};

    var cards=items.map(function(it,idx){
      var hasCode=it.recommendation&&(it.recommendation.indexOf("```")!==-1||it.recommendation.indexOf("brew")!==-1||it.recommendation.indexOf("npm")!==-1);
      var cleanRec=it.recommendation?it.recommendation.replace(/```bash\n|```/g,"").trim():"";

      var bodyContent='<div class="diag-label">Emulation Diagnostic:</div><div class="diag-text">'+it.issue+'</div>';
      if(it.path){
        bodyContent+='<div class="path-label">Installation Path:</div><div class="path-value">'+it.path+'</div>';
      }
      if(hasCode&&cleanRec){
        bodyContent+='<div class="remedy-label">Remediation Script:</div><div class="remedy-code"><code>'+cleanRec+'</code><button class="copy-btn" onclick="event.stopPropagation();copyCode(this,\''+cleanRec.replace(/'/g,"\\'")+'\')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg></button></div>';
      } else if(cleanRec){
        bodyContent+='<div class="remedy-label">Recommendation:</div><div class="diag-text">'+cleanRec+'</div>';
      }
      bodyContent+='<div class="info-box"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg><div><strong>Why this matters:</strong> Eliminating emulated code frees processor cycles, reduces launch times, lowers heat, and improves battery life.</div></div>';

      return '<div class="issue-card" id="card-'+idx+'" onclick="toggleCard('+idx+')">'+
        '<div class="issue-header">'+
          '<div class="issue-badge">x86</div>'+
          '<div class="issue-info">'+
            '<div class="issue-name">'+it.name+'</div>'+
            '<div class="issue-tag '+tagCls[it.type]+'">'+tagLbl[it.type]+'</div>'+
            '<div class="issue-desc">'+it.issue+'</div>'+
            (it.path?'<div class="issue-path">'+it.path+'</div>':'')+
          '</div>'+
          '<svg class="issue-chevron" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>'+
        '</div>'+
        '<div class="issue-body">'+bodyContent+'</div>'+
      '</div>';
    }).join("");

    document.getElementById("issues").innerHTML='<div class="issues-header"><h3>Identified Emulation Issues ('+items.length+')</h3><span>Click card to expand</span></div><div class="issue-list">'+cards+'</div>';
  }

  // Global functions
  window.setFilter=function(f){filter=f;renderControls();renderIssues()};
  window.setSearch=function(q){search=q;renderIssues()};
  window.toggleCard=function(idx){
    var card=document.getElementById("card-"+idx);
    if(card)card.classList.toggle("expanded");
  };
  window.copyCode=function(btn,code){
    navigator.clipboard.writeText(code);
    btn.innerHTML='<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>';
    setTimeout(function(){btn.innerHTML='<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>'},2000);
  };
  window.toggleLogEditor=function(){
    var body=document.getElementById("logEditorBody");
    var toggle=document.getElementById("logToggle");
    body.classList.toggle("open");
    toggle.textContent=body.classList.contains("open")?"\u25B2":"\u25BC";
  };
  window.applyNewLog=function(){
    var val=document.getElementById("logInput").value.trim();
    if(!val){document.getElementById("logStatus").textContent="Log cannot be empty";return}
    currentLog=val;
    render();
    document.getElementById("logStatus").textContent="Report refreshed with new log data";
    setTimeout(function(){document.getElementById("logStatus").textContent=""},3000);
  };
  window.resetLog=function(){
    currentLog=originalLog;
    document.getElementById("logInput").value=originalLog;
    render();
    document.getElementById("logStatus").textContent="Reset to original scan data";
    setTimeout(function(){document.getElementById("logStatus").textContent=""},3000);
  };

  init();
})();
</script>
</body>
</html>
HTML_EOF

    # Inject the actual base64 data into the HTML file
    sed -i '' "s|HTML_B64_PLACEHOLDER|${B64_LOG}|g" "$HTML_FILE"

    echo -e "\n${GREEN}Interactive Report Generated: ${BOLD}${HTML_FILE}${NC}"
    echo -e "Open ${HTML_FILE} in your browser to view the full dashboard."
    echo -e "Use the 'Replace Log Data' section at the bottom to update the report with new scan output."
    rm -f "$TMP_LOG"
else
    run_scans
fi

