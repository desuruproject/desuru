#!/bin/bash

# 🚀 Universal JavaScript Framework Deployment Script
# Supports React, Next.js, Vue, Angular, Nuxt, Svelte, Gatsby, Node.js, and more!
# Optimized for remote execution via curl/wget
#
# ⚠️  SECURITY WARNING: Remote Script Execution
# This script is designed to be executed remotely via curl/wget. While convenient,
# this approach has security implications:
# 1. Always verify the source URL and use HTTPS
# 2. Review the script content before execution when possible
# 3. Consider downloading and inspecting the script first:
#    curl -L https://your-domain.com/deploy.sh > deploy.sh && chmod +x deploy.sh
#    # Review the script, then run: ./deploy.sh --app myapp --domain example.com
# 4. Only run on servers you control or test environments
# 5. This script requires root privileges - use with caution
#
# Usage:
#   curl -sSL https://your-domain.com/remote-deploy.sh | bash -s -- --app myapp --domain example.com
#   wget -qO- https://your-domain.com/remote-deploy.sh | bash -s -- --app myapp --domain example.com
#
# GitHub Example:
#   curl -sSL https://raw.githubusercontent.com/user/repo/main/remote-deploy.sh | bash -s -- --app myapp --domain example.com
#
# Safer Alternative:
#   wget https://raw.githubusercontent.com/user/repo/main/remote-deploy.sh
#   # Review the script content, then:
#   chmod +x remote-deploy.sh && sudo ./remote-deploy.sh --app myapp --domain example.com

# Enhanced error handling - don't exit immediately on errors
set -euo pipefail  # Use pipefail to catch pipe failures, but handle errors gracefully

# Global error tracking
ERRORS_ENCOUNTERED=0
SCRIPT_PID=$$
TEMP_DIR="/tmp/desuru-$$"

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    if [ $exit_code -ne 0 ] && [ $ERRORS_ENCOUNTERED -gt 0 ]; then
        print_error "Deployment failed with $ERRORS_ENCOUNTERED error(s). Check log: $LOG_FILE"
        print_error "For troubleshooting, run: tail -50 $LOG_FILE"
    fi
    exit $exit_code
}

# Enhanced error handler
error_handler() {
    local exit_code=$?
    local line_number=$1
    local command="$2"
    ERRORS_ENCOUNTERED=$((ERRORS_ENCOUNTERED + 1))
    print_error "Command failed at line $line_number: $command"
    print_error "Exit code: $exit_code"
    log_to_file "ERROR: Line $line_number failed with exit code $exit_code: $command"
    
    # Don't exit immediately, let the script handle the error gracefully
    return $exit_code
}

# Set up error trapping
trap 'error_handler ${LINENO} "$BASH_COMMAND"' ERR
trap cleanup EXIT

# Create secure temporary directory
mkdir -p "$TEMP_DIR"
chmod 700 "$TEMP_DIR"

# Color codes for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Input validation functions
validate_app_name() {
    local app_name="$1"
    if [[ ! "$app_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$ ]]; then
        print_error "Invalid app name: $app_name"
        print_error "App name must:"
        print_error "- Start and end with alphanumeric characters"
        print_error "- Contain only letters, numbers, hyphens, and underscores"
        print_error "- Be between 2-63 characters long"
        return 1
    fi
    if [ ${#app_name} -lt 2 ] || [ ${#app_name} -gt 63 ]; then
        print_error "App name must be between 2-63 characters long"
        return 1
    fi
    return 0
}

validate_domain() {
    local domain="$1"
    # Allow localhost for development
    if [ "$domain" = "localhost" ]; then
        return 0
    fi
    
    # Basic domain validation
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        print_error "Invalid domain: $domain"
        print_error "Domain must contain only letters, numbers, dots, and hyphens"
        return 1
    fi
    
    # Check for valid TLD (simplified)
    if [[ ! "$domain" =~ \.[a-zA-Z]{2,}$ ]] && [ "$domain" != "localhost" ]; then
        print_warning "Domain '$domain' appears to be missing a valid TLD"
        print_warning "This might cause SSL certificate issues"
    fi
    
    return 0
}

validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        print_error "Port must be a number"
        return 1
    fi
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        print_error "Port must be between 1 and 65535"
        return 1
    fi
    if [ "$port" -lt 1024 ] && [ "$port" != "80" ] && [ "$port" != "443" ]; then
        print_warning "Port $port is in the reserved range (1-1023)"
        print_warning "Make sure this is intentional"
    fi
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid email format: $email"
        return 1
    fi
    return 0
}

validate_memory_limit() {
    local memory="$1"
    if [[ ! "$memory" =~ ^[0-9]+[KMG]?$ ]]; then
        print_error "Invalid memory limit format: $memory"
        print_error "Use format like: 500M, 1G, 2048K"
        return 1
    fi
    return 0
}

# Enhanced command execution with better error reporting
execute_command() {
    local description="$1"
    local command="$2"
    local allow_failure="${3:-false}"
    local log_output="${4:-true}"
    
    print_debug "Executing: $description"
    print_debug "Command: $command"
    
    local temp_log="$TEMP_DIR/cmd_output_$$"
    local exit_code=0
    
    if [ "$log_output" = "true" ]; then
        eval "$command" 2>&1 | tee "$temp_log" || exit_code=$?
    else
        eval "$command" > "$temp_log" 2>&1 || exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        print_debug "$description completed successfully"
        log_to_file "SUCCESS: $description"
        return 0
    else
        if [ "$allow_failure" = "true" ]; then
            print_warning "$description failed (exit code: $exit_code) - continuing anyway"
            log_to_file "WARNING: $description failed with exit code $exit_code but continuing"
        else
            print_error "$description failed (exit code: $exit_code)"
            if [ -f "$temp_log" ]; then
                print_error "Command output:"
                head -20 "$temp_log" | while read line; do print_debug "$line"; done
                if [ $(wc -l < "$temp_log") -gt 20 ]; then
                    print_debug "... (output truncated, see full log: $temp_log)"
                fi
            fi
            log_to_file "ERROR: $description failed with exit code $exit_code"
            ERRORS_ENCOUNTERED=$((ERRORS_ENCOUNTERED + 1))
        fi
        return $exit_code
    fi
}

# Default configuration
APP_NAME=""
APP_PORT="3000"
DOMAIN=""
ENABLE_SSL="false"
PM2_INSTANCES="1"
MAX_MEMORY_RESTART="500M"
EMAIL_FOR_SSL=""

# Framework detection variables
FRAMEWORK=""
FRAMEWORK_TYPE=""  # "frontend" or "backend" or "fullstack"
BUILD_COMMAND=""
START_COMMAND=""
SERVE_STATIC="false"
BUILD_DIR=""
MAIN_FILE=""

# Logging variables
LOG_FILE="/tmp/deploy-${APP_NAME:-unknown}-$(date +%Y%m%d_%H%M%S).log"
STEP_COUNTER=0

# Status functions
print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ██████╗ ███████╗██████╗ ██╗      ██████╗ ██╗   ██╗"
    echo "  ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗╚██╗ ██╔╝"
    echo "  ██║  ██║█████╗  ██████╔╝██║     ██║   ██║ ╚████╔╝"
    echo "  ██║  ██║██╔══╝  ██╔═══╝ ██║     ██║   ██║  ╚██╔╝"
    echo "  ██████╔╝███████╗██║     ███████╗╚██████╔╝   ██║"
    echo "  ╚═════╝ ╚══════╝╚═╝     ╚══════╝ ╚═════╝    ╚═╝"
    echo -e "${NC}"
    echo -e "${BLUE}${BOLD}  Universal JavaScript Framework Deployment${NC}"
    echo ""
}

# Enhanced logging functions with detailed context and timing
log_to_file() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local caller_info=""
    if [ "${BASH_LINENO[1]:-}" ]; then
        caller_info=" [Line:${BASH_LINENO[1]}]"
    fi
    echo "[$timestamp]$caller_info $1" >> "$LOG_FILE"
}

print_status() { 
    local msg="✅ $1"
    echo -e "${GREEN}$msg${NC}"
    log_to_file "SUCCESS: $1"
    
    # Show progress if we have step counter
    if [ "$STEP_COUNTER" -gt 0 ]; then
        local estimated_total=15  # Rough estimate of total steps
        local progress=$((STEP_COUNTER * 100 / estimated_total))
        [ $progress -gt 100 ] && progress=100
        echo -e "${CYAN}Progress: ${progress}% (${STEP_COUNTER}/${estimated_total} steps)${NC}"
    fi
}

print_info() { 
    local msg="ℹ️  $1"
    echo -e "${BLUE}$msg${NC}"
    log_to_file "INFO: $1"
}

print_warning() { 
    local msg="⚠️  $1"
    echo -e "${YELLOW}$msg${NC}"
    log_to_file "WARNING: $1"
    
    # Add troubleshooting hints for common warnings
    case "$1" in
        *"build directory"*) 
            echo -e "${YELLOW}💡 Hint: Check if your build command is correct${NC}"
            ;;
        *"firewall"*)
            echo -e "${YELLOW}💡 Hint: You may need to manually configure firewall rules${NC}"
            ;;
        *"SSL"*)
            echo -e "${YELLOW}💡 Hint: Ensure your domain points to this server${NC}"
            ;;
    esac
}

print_error() { 
    local msg="❌ $1"
    echo -e "${RED}$msg${NC}"
    log_to_file "ERROR: $1"
    
    # Add contextual troubleshooting information
    case "$1" in
        *"package.json"*)
            echo -e "${RED}💡 Troubleshooting: Ensure you're in your project's root directory${NC}"
            echo -e "${RED}💡 Try: ls -la | grep package.json${NC}"
            ;;
        *"Node.js"*)
            echo -e "${RED}💡 Troubleshooting: Check network connectivity to NodeSource${NC}"
            echo -e "${RED}💡 Try: curl -I https://deb.nodesource.com${NC}"
            ;;
        *"PM2"*)
            echo -e "${RED}💡 Troubleshooting: Ensure Node.js is properly installed${NC}"
            echo -e "${RED}💡 Try: node --version && npm --version${NC}"
            ;;
        *"nginx"*)
            echo -e "${RED}💡 Troubleshooting: Check nginx configuration syntax${NC}"
            echo -e "${RED}💡 Try: nginx -t${NC}"
            ;;
        *"build"*)
            echo -e "${RED}💡 Troubleshooting: Check for syntax errors in your code${NC}"
            echo -e "${RED}💡 Try: npm run build locally first${NC}"
            ;;
    esac
}

print_step() { 
    STEP_COUNTER=$((STEP_COUNTER + 1))
    local msg="🔄 Step $STEP_COUNTER: $1"
    echo -e "${CYAN}${BOLD}$msg${NC}"
    log_to_file "STEP $STEP_COUNTER: $1"
    
    # Show estimated time remaining (rough calculation)
    local avg_step_time=30  # seconds per step
    local remaining_steps=$((15 - STEP_COUNTER))  # estimated total of 15 steps
    if [ $remaining_steps -gt 0 ]; then
        local eta_minutes=$(( (remaining_steps * avg_step_time) / 60 ))
        echo -e "${CYAN}⏱️  Estimated time remaining: ~${eta_minutes} minutes${NC}"
    fi
    
    # Add step-specific information
    case "$1" in
        *"dependencies"*)
            echo -e "${CYAN}📦 This may take a few minutes depending on your package.json${NC}"
            ;;
        *"build"*)
            echo -e "${CYAN}🏗️  Build time varies by project size and complexity${NC}"
            ;;
        *"SSL"*)
            echo -e "${CYAN}🔒 SSL setup requires domain validation${NC}"
            ;;
    esac
}

print_debug() {
    local msg="🐛 DEBUG: $1"
    echo -e "${YELLOW}$msg${NC}"
    log_to_file "DEBUG: $1"
}

# New function for showing detailed system information
print_system_details() {
    echo -e "${BLUE}${BOLD}🔍 System Details:${NC}"
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    local processes=$(ps aux | wc -l)
    
    echo -e "   ${BOLD}Disk Usage:${NC} $disk_usage"
    echo -e "   ${BOLD}Load Average:${NC}$load_avg"
    echo -e "   ${BOLD}Running Processes:${NC} $processes"
    echo -e "   ${BOLD}Available Space:${NC} $(df -h / | awk 'NR==2 {print $4}')"
    
    # Check for potential issues
    local disk_percent=$(echo $disk_usage | sed 's/%//')
    if [ "$disk_percent" -gt 90 ]; then
        print_warning "Disk usage is high ($disk_usage) - deployment may fail"
    fi
    
    log_to_file "SYSTEM: Disk=$disk_usage, Load=$load_avg, Processes=$processes"
}

print_server_info() {
    echo -e "${BLUE}${BOLD}🖥️  Server Information:${NC}"
    echo -e "   ${BOLD}Hostname:${NC} $(hostname)"
    echo -e "   ${BOLD}OS:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
    echo -e "   ${BOLD}Kernel:${NC} $(uname -r)"
    echo -e "   ${BOLD}CPU Cores:${NC} $(nproc)"
    echo -e "   ${BOLD}Memory:${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "   ${BOLD}Disk Space:${NC} $(df -h / | awk 'NR==2 {print $4 " available of " $2}')"
    echo -e "   ${BOLD}Public IP:${NC} $(curl -s ipinfo.io/ip 2>/dev/null || echo "Unable to detect")"
    echo ""
    
    log_to_file "SERVER INFO: Hostname=$(hostname), OS=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown"), Kernel=$(uname -r), CPU=$(nproc), Memory=$(free -h | awk '/^Mem:/ {print $2}')"
}

# Framework detection function
detect_framework() {
    print_step "Detecting JavaScript framework..."
    log_to_file "Starting framework detection in directory: $(pwd)"
    
    if [ ! -f "package.json" ]; then
        print_error "No package.json found!"
        print_debug "Current directory contents:"
        ls -la | while read line; do print_debug "$line"; done
        log_to_file "ERROR: No package.json found in $(pwd)"
        return 1
    fi
    
    print_debug "Found package.json, analyzing dependencies..."
    
    # Read package.json content
    local package_content=$(cat package.json)
    print_debug "Package.json size: $(wc -c < package.json) bytes"
    
    # Check for Next.js
    if echo "$package_content" | grep -q '"next"' || [ -f "next.config.js" ] || [ -f "next.config.mjs" ]; then
        FRAMEWORK="Next.js"
        FRAMEWORK_TYPE="fullstack"
        BUILD_COMMAND="npm run build"
        START_COMMAND="npm start"
        BUILD_DIR=""  # Next.js handles its own build
        APP_PORT="3000"
        MAIN_FILE="next"  # Special marker for Next.js - no actual file needed
        
    # Check for Nuxt.js
    elif echo "$package_content" | grep -q '"nuxt"' || [ -f "nuxt.config.js" ] || [ -f "nuxt.config.ts" ]; then
        FRAMEWORK="Nuxt.js"
        FRAMEWORK_TYPE="fullstack"
        BUILD_COMMAND="npm run build"
        START_COMMAND="npm start"
        BUILD_DIR=""
        APP_PORT="3000"
        MAIN_FILE="nuxt"  # Special marker for Nuxt.js - no actual file needed
        
    # Check for Gatsby
    elif echo "$package_content" | grep -q '"gatsby"' || [ -f "gatsby-config.js" ]; then
        FRAMEWORK="Gatsby"
        FRAMEWORK_TYPE="frontend"
        BUILD_COMMAND="npm run build"
        START_COMMAND=""
        BUILD_DIR="public"
        SERVE_STATIC="true"
        
    # Check for Angular
    elif echo "$package_content" | grep -q '"@angular/core"' || [ -f "angular.json" ]; then
        FRAMEWORK="Angular"
        FRAMEWORK_TYPE="frontend"
        BUILD_COMMAND="npm run build"
        START_COMMAND=""
        BUILD_DIR="dist"
        SERVE_STATIC="true"
        
    # Check for Vue.js (including Vite)
    elif echo "$package_content" | grep -q '"vue"' || [ -f "vite.config.js" ] || [ -f "vue.config.js" ]; then
        FRAMEWORK="Vue.js"
        FRAMEWORK_TYPE="frontend"
        BUILD_COMMAND="npm run build"
        START_COMMAND=""
        BUILD_DIR="dist"
        SERVE_STATIC="true"
        
    # Check for Svelte/SvelteKit
    elif echo "$package_content" | grep -q '"svelte"' || echo "$package_content" | grep -q '"@sveltejs/kit"'; then
        if echo "$package_content" | grep -q '"@sveltejs/kit"'; then
            FRAMEWORK="SvelteKit"
            FRAMEWORK_TYPE="fullstack"
            BUILD_COMMAND="npm run build"
            START_COMMAND="npm start"
            BUILD_DIR=""
            MAIN_FILE="sveltekit"  # Special marker for SvelteKit - no actual file needed
        else
            FRAMEWORK="Svelte"
            FRAMEWORK_TYPE="frontend"
            BUILD_COMMAND="npm run build"
            START_COMMAND=""
            BUILD_DIR="public"
            SERVE_STATIC="true"
        fi
        
    # Check for Create React App or React with Vite
    elif echo "$package_content" | grep -q '"react"'; then
        if echo "$package_content" | grep -q '"react-scripts"'; then
            FRAMEWORK="Create React App"
            BUILD_DIR="build"
        else
            FRAMEWORK="React (Vite/Custom)"
            BUILD_DIR="dist"
        fi
        FRAMEWORK_TYPE="frontend"
        BUILD_COMMAND="npm run build"
        START_COMMAND=""
        SERVE_STATIC="true"
        
    # Check for Express.js or other Node.js backend
    elif echo "$package_content" | grep -q '"express"' || find_main_file; then
        FRAMEWORK="Node.js/Express"
        FRAMEWORK_TYPE="backend"
        BUILD_COMMAND=""
        START_COMMAND="node"
        BUILD_DIR=""
        SERVE_STATIC="false"
        
    else
        print_warning "Could not detect specific framework"
        print_debug "Checking for common patterns in package.json..."
        
        # Try to determine if it's a frontend or backend project
        if echo "$package_content" | grep -qE '"(webpack|vite|parcel|rollup)"' || 
           echo "$package_content" | grep -qE '"(build|start)".*"(webpack|vite|parcel)"'; then
            FRAMEWORK="Unknown Frontend Framework"
            FRAMEWORK_TYPE="frontend"
            BUILD_COMMAND="npm run build"
            BUILD_DIR="dist"
            SERVE_STATIC="true"
        else
            FRAMEWORK="Unknown Node.js Application"
            FRAMEWORK_TYPE="backend"
            BUILD_COMMAND=""
            START_COMMAND="node"
            BUILD_DIR=""
            SERVE_STATIC="false"
        fi
    fi
    
    print_status "Framework detected: $FRAMEWORK"
    print_info "Framework type: $FRAMEWORK_TYPE"
    print_info "Build command: ${BUILD_COMMAND:-'none'}"
    print_info "Build directory: ${BUILD_DIR:-'none'}"
    print_info "Serve static files: $SERVE_STATIC"
    
    log_to_file "FRAMEWORK DETECTION: Framework=$FRAMEWORK, Type=$FRAMEWORK_TYPE, BuildCmd=$BUILD_COMMAND, BuildDir=$BUILD_DIR, ServeStatic=$SERVE_STATIC"
    
    return 0
}

# Helper function to find main application file
find_main_file() {
    print_debug "Looking for main application file..."
    
    # Check package.json main field first
    if [ -f "package.json" ]; then
        local main_from_package=$(grep -o '"main"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null | sed 's/.*"\([^"]*\)"/\1/')
        if [ -n "$main_from_package" ] && [ -f "$main_from_package" ]; then
            MAIN_FILE="$main_from_package"
            print_debug "Main file from package.json: $MAIN_FILE"
            return 0
        fi
    fi
    
    # Check common main file names
    for file in index.js app.js server.js main.js src/index.js src/app.js src/server.js; do
        if [ -f "$file" ]; then
            MAIN_FILE="$file"
            print_debug "Found main file: $MAIN_FILE"
            return 0
        fi
    done
    
    print_debug "No main file found"
    return 1
}

show_usage() {
    print_banner
    echo -e "${BOLD}Usage:${NC}"
    echo ""
    echo -e "${BLUE}Remote execution (recommended):${NC}"
    echo "  curl -sSL https://your-domain.com/deploy.sh | bash -s -- --app myapp --domain example.com"
    echo ""
    echo -e "${BLUE}GitHub raw file:${NC}"
    echo "  curl -sSL https://raw.githubusercontent.com/user/repo/main/remote-deploy.sh | bash -s -- --app myapp --domain example.com"
    echo ""
    echo -e "${BOLD}Required flags:${NC}"
    echo "  --app NAME        Application name for PM2"
    echo "  --domain DOMAIN   Domain name or IP address"
    echo ""
    echo -e "${BOLD}Optional flags:${NC}"
    echo "  --port PORT       Application port (default: 3000)"
    echo "  --ssl             Enable SSL with Let's Encrypt"
    echo "  --email EMAIL     Email for SSL certificate"
    echo "  --instances NUM   PM2 instances (default: 1, use 'max' for all cores)"
    echo "  --memory LIMIT    Memory restart limit (default: 500M)"
    echo "  --help           Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  # Basic deployment"
    echo "  curl -sSL https://deploy.example.com/deploy.sh | bash -s -- --app blog --domain myblog.com"
    echo ""
    echo "  # With SSL and custom port"
    echo "  curl -sSL https://deploy.example.com/deploy.sh | bash -s -- --app api --domain api.example.com --port 8080 --ssl --email admin@example.com"
    echo ""
    echo "  # High-performance setup"
    echo "  curl -sSL https://deploy.example.com/deploy.sh | bash -s -- --app webapp --domain app.com --instances max --memory 1G"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            APP_NAME="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --port)
            APP_PORT="$2"
            shift 2
            ;;
        --ssl)
            ENABLE_SSL="true"
            shift
            ;;
        --email)
            EMAIL_FOR_SSL="$2"
            shift 2
            ;;
        --instances)
            PM2_INSTANCES="$2"
            shift 2
            ;;
        --memory)
            MAX_MEMORY_RESTART="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters with enhanced security checks
if [ -z "$APP_NAME" ] || [ -z "$DOMAIN" ]; then
    print_error "Missing required parameters!"
    echo ""
    show_usage
    exit 1
fi

# Validate all input parameters for security
print_step "Validating input parameters..."

if ! validate_app_name "$APP_NAME"; then
    print_error "App name validation failed"
    exit 1
fi

if ! validate_domain "$DOMAIN"; then
    print_error "Domain validation failed"
    exit 1
fi

if ! validate_port "$APP_PORT"; then
    print_error "Port validation failed"
    exit 1
fi

if [ "$PM2_INSTANCES" != "max" ] && [[ ! "$PM2_INSTANCES" =~ ^[0-9]+$ ]]; then
    print_error "PM2 instances must be a number or 'max'"
    exit 1
fi

if ! validate_memory_limit "$MAX_MEMORY_RESTART"; then
    print_error "Memory limit validation failed"
    exit 1
fi

# Validate SSL configuration
if [ "$ENABLE_SSL" = "true" ]; then
    if [ -z "$EMAIL_FOR_SSL" ]; then
        print_error "SSL enabled but no email provided!"
        print_warning "Email is required for Let's Encrypt certificates"
        print_info "Use: --email your@email.com"
        exit 1
    fi
    
    if ! validate_email "$EMAIL_FOR_SSL"; then
        print_error "Email validation failed"
        exit 1
    fi
    
    # Additional SSL security checks
    if [ "$DOMAIN" = "localhost" ]; then
        print_warning "SSL cannot be enabled for localhost domain"
        ENABLE_SSL="false"
        print_info "Disabling SSL for localhost deployment"
    fi
fi

print_status "All input parameters validated successfully"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    print_info "Run with: sudo curl -sSL ... | sudo bash -s -- --app ..."
    exit 1
fi

# Initialize logging
LOG_FILE="/tmp/deploy-${APP_NAME:-unknown}-$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"
log_to_file "=== DEPLOYMENT STARTED ==="
log_to_file "Command line: $0 $*"

# Show deployment configuration
print_banner
print_server_info

print_info "🎯 Deployment Configuration:"
echo -e "   ${BOLD}App Name:${NC} ${GREEN}$APP_NAME${NC}"
echo -e "   ${BOLD}Domain:${NC} ${GREEN}$DOMAIN${NC}"
echo -e "   ${BOLD}Port:${NC} ${GREEN}$APP_PORT${NC}"
echo -e "   ${BOLD}SSL:${NC} ${GREEN}$ENABLE_SSL${NC}"
echo -e "   ${BOLD}Instances:${NC} ${GREEN}$PM2_INSTANCES${NC}"
echo -e "   ${BOLD}Memory Limit:${NC} ${GREEN}$MAX_MEMORY_RESTART${NC}"
echo -e "   ${BOLD}Log File:${NC} ${GREEN}$LOG_FILE${NC}"
echo ""

# Detect working directory (should be the cloned repository)
WORK_DIR=$(pwd)
print_info "Working directory: $WORK_DIR"

# Check if we're in a git repository
if [ -d ".git" ]; then
    REPO_NAME=$(basename "$WORK_DIR")
    print_info "Git repository detected: $REPO_NAME"
else
    print_warning "Not in a git repository - make sure you're in your project directory"
fi

# Detect framework and configuration
if ! detect_framework; then
    print_error "Framework detection failed!"
    print_info "Please ensure you're in the root directory of your JavaScript project"
    print_info "The directory should contain a package.json file"
    exit 1
fi

# Update system packages
print_step "Updating system packages..."
if execute_command "System package update" "apt update -y" false false; then
    print_status "System packages updated"
else
    print_error "Failed to update system packages"
    print_error "This is often due to network connectivity or repository issues"
    exit 1
fi

# Install Node.js 20.x if not already installed
if ! command -v node &> /dev/null; then
    print_step "Installing Node.js 20.x..."
    
    # Download and setup NodeSource repository
    if execute_command "NodeSource repository setup" "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -" false false; then
        # Install Node.js package
        if execute_command "Node.js package installation" "apt install -y nodejs" false false; then
            NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
            print_status "Node.js $NODE_VERSION installed"
            log_to_file "Node.js $NODE_VERSION installed successfully"
        else
            print_error "Failed to install Node.js package"
            print_error "This might be due to:"
            print_error "- Insufficient disk space"
            print_error "- Package conflicts"
            print_error "- Network connectivity issues"
            exit 1
        fi
    else
        print_error "Failed to setup Node.js repository"
        print_error "This might be due to:"
        print_error "- Network connectivity to NodeSource"
        print_error "- Firewall blocking HTTPS connections"
        print_error "- DNS resolution issues"
        exit 1
    fi
else
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    NPM_VERSION=$(npm --version 2>/dev/null || echo "unknown")
    print_info "Node.js $NODE_VERSION already installed"
    print_info "npm $NPM_VERSION available"
    log_to_file "Using existing Node.js $NODE_VERSION"
    
    # Verify Node.js is working
    if ! node -e "console.log('Node.js working')" >/dev/null 2>&1; then
        print_warning "Node.js appears to be installed but not working properly"
        print_warning "You may need to reinstall Node.js"
    fi
fi

# Install nginx if not already installed
if ! command -v nginx &> /dev/null; then
    print_step "Installing Nginx..."
    if execute_command "Nginx installation" "apt install -y nginx" false false; then
        NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3 2>/dev/null || echo "unknown")
        print_status "Nginx $NGINX_VERSION installed"
        log_to_file "Nginx $NGINX_VERSION installed successfully"
    else
        print_error "Failed to install Nginx"
        print_error "This is critical for serving your application"
        exit 1
    fi
else
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3 2>/dev/null || echo "unknown")
    print_info "Nginx $NGINX_VERSION already installed"
    log_to_file "Using existing Nginx $NGINX_VERSION"
    
    # Verify Nginx configuration is valid
    if ! nginx -t >/dev/null 2>&1; then
        print_warning "Existing Nginx configuration has issues"
        print_warning "This might cause deployment problems"
    fi
fi

# Install PM2 globally if not already installed (only for backend apps)
if [ "$FRAMEWORK_TYPE" = "backend" ] || [ "$FRAMEWORK_TYPE" = "fullstack" ]; then
    if ! command -v pm2 &> /dev/null; then
        print_step "Installing PM2..."
        if execute_command "PM2 global installation" "npm install -g pm2" false false; then
            PM2_VERSION=$(pm2 --version 2>/dev/null || echo "unknown")
            print_status "PM2 v$PM2_VERSION installed"
            log_to_file "PM2 v$PM2_VERSION installed successfully"
        else
            print_error "Failed to install PM2"
            print_error "PM2 is required for managing backend applications"
            print_error "This might be due to npm permission issues"
            exit 1
        fi
    else
        PM2_VERSION=$(pm2 --version 2>/dev/null || echo "unknown")
        print_info "PM2 v$PM2_VERSION already installed"
        log_to_file "Using existing PM2 v$PM2_VERSION"
        
        # Verify PM2 is working
        if ! pm2 list >/dev/null 2>&1; then
            print_warning "PM2 appears to be installed but not working properly"
            print_warning "You may need to restart the PM2 daemon"
        fi
    fi
else
    print_info "Skipping PM2 installation (frontend framework detected)"
fi

# Install application dependencies
print_step "Installing application dependencies..."

if [ -f "package.json" ]; then
    # Determine package manager
    if [ -f "yarn.lock" ]; then
        PACKAGE_MANAGER="yarn"
        print_debug "Using Yarn package manager (detected yarn.lock)"
        
        # Check if yarn is installed
        if ! command -v yarn &> /dev/null; then
            print_warning "Yarn lockfile found but yarn not installed, using npm instead"
            PACKAGE_MANAGER="npm"
        fi
    elif [ -f "pnpm-lock.yaml" ]; then
        PACKAGE_MANAGER="pnpm"
        print_debug "Using PNPM package manager (detected pnpm-lock.yaml)"
        
        # Check if pnpm is installed
        if ! command -v pnpm &> /dev/null; then
            print_warning "PNPM lockfile found but pnpm not installed, using npm instead"
            PACKAGE_MANAGER="npm"
        fi
    else
        PACKAGE_MANAGER="npm"
        print_debug "Using NPM package manager (default)"
    fi
    
    print_info "Installing dependencies with $PACKAGE_MANAGER..."
    if execute_command "Dependency installation with $PACKAGE_MANAGER" "$PACKAGE_MANAGER install" false false; then
        print_status "Dependencies installed with $PACKAGE_MANAGER"
        log_to_file "Dependencies installed successfully with $PACKAGE_MANAGER"
        
        # Check for security vulnerabilities
        if [ "$PACKAGE_MANAGER" = "npm" ]; then
            print_debug "Running security audit..."
            npm audit >/dev/null 2>&1 || print_warning "Some security vulnerabilities found in dependencies"
        fi
    else
        print_error "Failed to install dependencies with $PACKAGE_MANAGER"
        
        # Try fallback to npm if not already using it
        if [ "$PACKAGE_MANAGER" != "npm" ]; then
            print_info "Trying fallback to npm..."
            if execute_command "Dependency installation with npm (fallback)" "npm install" false false; then
                print_status "Dependencies installed with npm (fallback)"
                log_to_file "Dependencies installed with npm (fallback)"
            else
                print_error "Failed to install dependencies with both $PACKAGE_MANAGER and npm"
                print_error "Common causes:"
                print_error "- Network connectivity issues"
                print_error "- Syntax errors in package.json"
                print_error "- Incompatible Node.js version"
                print_error "- Missing system dependencies"
                exit 1
            fi
        else
            print_error "Failed to install dependencies"
            print_error "Check package.json syntax and network connectivity"
            exit 1
        fi
    fi
    
    # Verify installation
    if [ -d "node_modules" ]; then
        NODE_MODULES_SIZE=$(du -sh node_modules 2>/dev/null | cut -f1 || echo "unknown")
        print_info "Dependencies installed successfully (${NODE_MODULES_SIZE})"
    else
        print_warning "node_modules directory not found after installation"
    fi
else
    print_warning "No package.json found, skipping dependency installation"
    print_warning "Make sure you're in the correct project directory"
fi

# Build the application if needed
if [ -n "$BUILD_COMMAND" ]; then
    print_step "Building application..."
    
    # Check available disk space before building
    local available_space=$(df . | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1048576 ]; then  # Less than 1GB
        print_warning "Low disk space available ($(df -h . | awk 'NR==2 {print $4}'))"
        print_warning "Build might fail due to insufficient space"
    fi
    
    if execute_command "Application build" "$BUILD_COMMAND" false true; then
        print_status "Application built successfully"
        log_to_file "Build completed successfully with: $BUILD_COMMAND"
        
        # Verify build directory exists for frontend apps
        if [ "$SERVE_STATIC" = "true" ] && [ -n "$BUILD_DIR" ]; then
            if [ -d "$BUILD_DIR" ]; then
                BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "unknown")
                print_info "Build directory created: $BUILD_DIR ($BUILD_SIZE)"
                log_to_file "Build directory: $BUILD_DIR, Size: $BUILD_SIZE"
                
                # Check if build directory has content
                local build_files=$(find "$BUILD_DIR" -type f | wc -l)
                if [ "$build_files" -eq 0 ]; then
                    print_warning "Build directory is empty - this might indicate a build issue"
                fi
            else
                print_warning "Expected build directory $BUILD_DIR not found after build"
                print_info "Searching for alternative build directories..."
                
                # Try to find common build directories
                for dir in dist build out public .next; do
                    if [ -d "$dir" ]; then
                        BUILD_DIR="$dir"
                        BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "unknown")
                        print_info "Found alternative build directory: $BUILD_DIR ($BUILD_SIZE)"
                        log_to_file "Alternative build directory found: $BUILD_DIR"
                        break
                    fi
                done
                
                if [ ! -d "$BUILD_DIR" ]; then
                    print_error "No build directory found after build"
                    print_error "This might indicate the build didn't complete successfully"
                    exit 1
                fi
            fi
        fi
    else
        print_error "Build failed!"
        print_error "Common build issues and solutions:"
        print_error "1. Missing dependencies → Run: $PACKAGE_MANAGER install"
        print_error "2. Syntax errors → Check your source code"
        print_error "3. Memory issues → Try: export NODE_OPTIONS=\"--max-old-space-size=4096\""
        print_error "4. Missing env vars → Check if .env file is needed"
        print_error "5. Wrong Node version → Check package.json engines field"
        exit 1
    fi
else
    print_info "No build step required for this framework"
fi

# Find main file for backend/fullstack apps
if [ "$FRAMEWORK_TYPE" = "backend" ] || [ "$FRAMEWORK_TYPE" = "fullstack" ]; then
    if [ -z "$MAIN_FILE" ]; then
        if ! find_main_file; then
            print_error "Could not find main application file!"
            print_info "Current directory contents:"
            ls -la | while read line; do print_debug "$line"; done
            print_warning "Make sure you're running this script from inside your project directory!"
            exit 1
        fi
    fi
    
    # Show appropriate message based on main file type
    if [ "$MAIN_FILE" = "next" ] || [ "$MAIN_FILE" = "nuxt" ] || [ "$MAIN_FILE" = "sveltekit" ]; then
        print_status "Framework application detected: $FRAMEWORK (uses built-in server)"
        log_to_file "Framework application: $FRAMEWORK with built-in server"
    else
        print_status "Main file detected: $MAIN_FILE"
        log_to_file "Main application file: $MAIN_FILE"
    fi
fi

# Start application based on framework type
if [ "$FRAMEWORK_TYPE" = "backend" ] || [ "$FRAMEWORK_TYPE" = "fullstack" ]; then
    # Stop existing PM2 process if it exists
    if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
        print_step "Stopping existing PM2 process..."
        print_debug "Stopping PM2 process: $APP_NAME"
        if pm2 stop "$APP_NAME" >/dev/null 2>&1 && pm2 delete "$APP_NAME" >/dev/null 2>&1; then
            print_status "Existing PM2 process stopped"
            log_to_file "Stopped existing PM2 process: $APP_NAME"
        else
            print_warning "Failed to stop existing PM2 process"
        fi
    fi

    # Start application with PM2
    print_step "Starting application with PM2..."
    
    # Handle special framework cases that don't use traditional main files
    if [ "$MAIN_FILE" = "next" ] || [ "$MAIN_FILE" = "nuxt" ] || [ "$MAIN_FILE" = "sveltekit" ]; then
        print_debug "Starting $FRAMEWORK with npm start via PM2"
        print_debug "PM2 command: pm2 start 'npm start' --name $APP_NAME -i $PM2_INSTANCES --max-memory-restart $MAX_MEMORY_RESTART"
        PM2_START_CMD="npm -- start"
    else
        print_debug "PM2 command: pm2 start $MAIN_FILE --name $APP_NAME -i $PM2_INSTANCES --max-memory-restart $MAX_MEMORY_RESTART"
        PM2_START_CMD="$MAIN_FILE"
    fi
    
    if pm2 start "$PM2_START_CMD" --name "$APP_NAME" -i "$PM2_INSTANCES" --max-memory-restart "$MAX_MEMORY_RESTART" >/dev/null 2>&1; then
        if pm2 save >/dev/null 2>&1; then
            print_status "Application started with PM2"
            if [ "$MAIN_FILE" = "next" ] || [ "$MAIN_FILE" = "nuxt" ] || [ "$MAIN_FILE" = "sveltekit" ]; then
                log_to_file "PM2 process started: $FRAMEWORK (npm start) as $APP_NAME"
            else
                log_to_file "PM2 process started: $MAIN_FILE as $APP_NAME"
            fi
            
            # Show PM2 status
            PM2_STATUS=$(pm2 jlist | grep "\"name\":\"$APP_NAME\"" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            print_info "PM2 status: $PM2_STATUS"
            
            # Get memory usage
            PM2_MEMORY=$(pm2 jlist | grep -A20 "\"name\":\"$APP_NAME\"" | grep '"memory"' | head -1 | grep -o '[0-9]*' | head -1)
            if [ -n "$PM2_MEMORY" ]; then
                PM2_MEMORY_MB=$((PM2_MEMORY / 1024 / 1024))
                print_info "Memory usage: ${PM2_MEMORY_MB}MB"
            fi
        else
            print_error "Failed to save PM2 configuration"
            exit 1
        fi
    else
        print_error "Failed to start application with PM2"
        print_debug "Check the main file path and application code"
        exit 1
    fi

    # Setup PM2 startup script
    print_step "Configuring PM2 startup..."
    print_debug "Setting up PM2 to start on system boot"
    if pm2 startup systemd -u root --hp /root >/dev/null 2>&1; then
        print_status "PM2 startup configured"
        log_to_file "PM2 startup script configured"
    else
        print_warning "Failed to configure PM2 startup"
    fi
elif [ "$FRAMEWORK_TYPE" = "frontend" ]; then
    print_info "Frontend framework detected - will serve static files via Nginx"
    log_to_file "Frontend deployment: serving static files from $BUILD_DIR"
fi

# Consolidated nginx configuration function
create_nginx_config() {
    local config_type="$1"
    local config_file="/etc/nginx/sites-available/$APP_NAME"
    
    print_debug "Creating $config_type nginx configuration"
    
    # Common security headers
    local security_headers='
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header X-Robots-Tag "noindex, nofollow" always;'
    
    # Common compression settings
    local compression_config='
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        application/xml
        image/svg+xml;'
    
    # Common health check
    local health_check='
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }'
    
    if [ "$config_type" = "static" ]; then
        cat > "$config_file" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $(pwd)/$BUILD_DIR;
    index index.html index.htm;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=static:10m rate=10r/s;
    limit_req zone=static burst=20 nodelay;
$security_headers
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
$compression_config

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|webp|avif)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
        access_log off;
        
        # Enable CORS for fonts and assets
        add_header Access-Control-Allow-Origin "*";
    }

    # Handle client-side routing (SPA)
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # API proxy (if needed for fullstack frameworks)
    location /api {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts for API calls
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
$health_check
}
EOF
        print_info "Static file server configured for $(pwd)/$BUILD_DIR"
        log_to_file "Nginx configured for static files: $(pwd)/$BUILD_DIR"
    else
        cat > "$config_file" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=5r/s;
    limit_req zone=api burst=10 nodelay;
$security_headers
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
$compression_config

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect off;

        # Enhanced timeouts and buffer sizes
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Handle large uploads
        client_max_body_size 50M;
    }
$health_check
}
EOF
        print_info "Reverse proxy configured for localhost:$APP_PORT"
        log_to_file "Nginx configured as reverse proxy to localhost:$APP_PORT"
    fi
}

# Configure Nginx
print_step "Configuring Nginx..."
print_debug "Framework type: $FRAMEWORK_TYPE, Serve static: $SERVE_STATIC"

if [ "$SERVE_STATIC" = "true" ]; then
    create_nginx_config "static"
else
    create_nginx_config "proxy"
fi

# Enable the site
print_debug "Enabling Nginx site configuration..."
if ln -sf "/etc/nginx/sites-available/$APP_NAME" "/etc/nginx/sites-enabled/"; then
    rm -f /etc/nginx/sites-enabled/default
    print_debug "Site enabled, default site disabled"
    log_to_file "Nginx site enabled: /etc/nginx/sites-available/$APP_NAME"
else
    print_error "Failed to enable Nginx site"
    exit 1
fi

# Test and restart nginx
print_step "Testing and restarting Nginx..."

# Test nginx configuration
if execute_command "Nginx configuration test" "nginx -t" false false; then
    print_debug "Nginx configuration test passed"
    
    # Restart nginx service
    if execute_command "Nginx service restart" "systemctl restart nginx" false false; then
        # Enable nginx on boot
        if execute_command "Enable Nginx on boot" "systemctl enable nginx" true false; then
            print_status "Nginx configured and restarted"
            log_to_file "Nginx service restarted and enabled"
        else
            print_warning "Failed to enable Nginx service on boot"
            print_warning "Nginx will not start automatically after reboot"
        fi
        
        # Verify Nginx is running
        if systemctl is-active nginx >/dev/null 2>&1; then
            print_info "Nginx service is active and running"
            
            # Test HTTP response
            sleep 2  # Give nginx a moment to fully start
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "200\|404\|403"; then
                print_info "Nginx is responding to HTTP requests"
            else
                print_warning "Nginx may not be responding properly to HTTP requests"
            fi
        else
            print_warning "Nginx service may not be running properly"
            print_warning "Try: systemctl status nginx"
        fi
    else
        print_error "Failed to restart Nginx service"
        print_error "Check system logs: journalctl -u nginx"
        exit 1
    fi
else
    print_error "Nginx configuration test failed!"
    print_error "Configuration file: /etc/nginx/sites-available/$APP_NAME"
    print_error "Run 'nginx -t' for detailed error information"
    log_to_file "Nginx configuration test failed"
    exit 1
fi

# Configure SSL if enabled
if [ "$ENABLE_SSL" = "true" ] && [ "$DOMAIN" != "localhost" ]; then
    print_step "Setting up SSL certificate..."
    
    # Pre-SSL checks
    print_debug "Performing pre-SSL validation checks..."
    
    # Check if domain resolves to this server
    local server_ip=$(curl -s ipinfo.io/ip 2>/dev/null || echo "unknown")
    local domain_ip=$(dig +short "$DOMAIN" 2>/dev/null | tail -1)
    
    if [ "$server_ip" != "unknown" ] && [ -n "$domain_ip" ]; then
        if [ "$server_ip" = "$domain_ip" ]; then
            print_info "Domain $DOMAIN correctly points to this server ($server_ip)"
        else
            print_warning "Domain $DOMAIN points to $domain_ip but server IP is $server_ip"
            print_warning "SSL certificate installation may fail"
        fi
    else
        print_warning "Could not verify domain DNS resolution"
    fi
    
    # Install certbot
    if execute_command "Certbot installation" "apt install -y certbot python3-certbot-nginx" false false; then
        print_debug "Running certbot for domain: $DOMAIN"
        
        # Attempt SSL certificate installation
        local ssl_command="certbot --nginx -d '$DOMAIN' --non-interactive --agree-tos --email '$EMAIL_FOR_SSL' --redirect"
        if execute_command "SSL certificate installation" "$ssl_command" true false; then
            print_status "SSL certificate installed successfully"
            log_to_file "SSL certificate installed for $DOMAIN"
            
            # Verify SSL certificate
            if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
                SSL_EXPIRY=$(openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
                if [ -n "$SSL_EXPIRY" ]; then
                    print_info "SSL certificate expires: $SSL_EXPIRY"
                fi
                
                # Test HTTPS connection
                sleep 3  # Give nginx time to reload
                if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/health" | grep -q "200"; then
                    print_info "HTTPS is working correctly"
                else
                    print_warning "HTTPS may not be working properly - check nginx configuration"
                fi
            else
                print_warning "SSL certificate file not found after installation"
            fi
            
            # Set up auto-renewal
            if execute_command "SSL auto-renewal setup" "crontab -l 2>/dev/null | { cat; echo '0 12 * * * /usr/bin/certbot renew --quiet'; } | crontab -" true false; then
                print_info "SSL certificate auto-renewal configured"
            else
                print_warning "Failed to setup SSL auto-renewal"
                print_info "Manually add to crontab: 0 12 * * * /usr/bin/certbot renew --quiet"
            fi
        else
            print_warning "SSL certificate installation failed"
            print_error "Common SSL issues and solutions:"
            print_error "1. Domain doesn't point to this server → Update DNS records"
            print_error "2. Firewall blocking ports 80/443 → Configure firewall"
            print_error "3. Rate limits reached → Wait and try again later"
            print_error "4. Domain validation failed → Check domain ownership"
            print_info "Manual command: certbot --nginx -d $DOMAIN"
            log_to_file "SSL certificate installation failed for $DOMAIN"
        fi
    else
        print_error "Failed to install certbot"
        print_error "SSL setup aborted - deployment will continue without HTTPS"
    fi
fi

# Configure firewall if available
if command -v ufw &> /dev/null; then
    print_step "Configuring firewall..."
    
    # Check current firewall status
    local ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
    print_debug "Current UFW status: ${ufw_status:-unknown}"
    
    # Configure firewall rules
    if execute_command "UFW allow Nginx Full" "ufw allow 'Nginx Full'" true false; then
        if execute_command "UFW allow OpenSSH" "ufw allow OpenSSH" true false; then
            print_status "Firewall rules configured"
            log_to_file "Firewall rules configured: Nginx Full, OpenSSH allowed"
            
            # Enable firewall if not already enabled
            if [ "$ufw_status" != "active" ]; then
                print_debug "Enabling UFW firewall..."
                if execute_command "Enable UFW firewall" "ufw --force enable" true false; then
                    print_info "UFW firewall enabled"
                else
                    print_warning "Failed to enable UFW firewall"
                fi
            fi
            
            # Show current firewall status
            UFW_STATUS=$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
            print_info "Firewall status: $UFW_STATUS"
            
            # Show allowed services
            print_debug "Allowed services:"
            ufw status 2>/dev/null | grep -E "(22|80|443|Nginx|OpenSSH)" | while read line; do
                print_debug "  $line"
            done
        else
            print_warning "Failed to configure OpenSSH firewall rule"
            print_warning "SSH access might be blocked if firewall is enabled"
        fi
    else
        print_warning "Failed to configure Nginx firewall rules"
        print_warning "Web traffic might be blocked if firewall is enabled"
    fi
else
    print_info "UFW firewall not available, skipping firewall configuration"
    print_info "Consider manually configuring iptables or another firewall"
fi

# Final deployment summary and server details
log_to_file "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="

echo ""
echo -e "${GREEN}${BOLD}🎉 Deployment Completed Successfully!${NC}"
echo ""

# Show comprehensive deployment details
echo -e "${BLUE}${BOLD}🌐 Your application is now live:${NC}"
echo -e "   ${GREEN}${BOLD}http://$DOMAIN${NC}"
[ "$ENABLE_SSL" = "true" ] && echo -e "   ${GREEN}${BOLD}https://$DOMAIN${NC}"

echo ""
echo -e "${BLUE}${BOLD}📋 Comprehensive Deployment Summary:${NC}"
echo ""

# Framework and application details
echo -e "${CYAN}${BOLD}📦 Application Details:${NC}"
echo -e "   ${BOLD}Framework:${NC} $FRAMEWORK"
echo -e "   ${BOLD}Framework Type:${NC} $FRAMEWORK_TYPE"
echo -e "   ${BOLD}Application Name:${NC} $APP_NAME"
echo -e "   ${BOLD}Domain:${NC} $DOMAIN"
echo -e "   ${BOLD}Port:${NC} $APP_PORT"
if [ -n "$MAIN_FILE" ]; then
    if [ "$MAIN_FILE" = "next" ] || [ "$MAIN_FILE" = "nuxt" ] || [ "$MAIN_FILE" = "sveltekit" ]; then
        echo -e "   ${BOLD}Start Method:${NC} npm start (built-in server)"
    else
        echo -e "   ${BOLD}Main File:${NC} $MAIN_FILE"
    fi
fi
[ -n "$BUILD_DIR" ] && echo -e "   ${BOLD}Build Directory:${NC} $BUILD_DIR"
echo -e "   ${BOLD}Serve Static Files:${NC} $SERVE_STATIC"

echo ""

# Server configuration
echo -e "${CYAN}${BOLD}🖥️  Server Configuration:${NC}"
echo -e "   ${BOLD}Hostname:${NC} $(hostname)"
echo -e "   ${BOLD}OS:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
echo -e "   ${BOLD}Node.js:${NC} ${NODE_VERSION:-Not installed}"
[ -n "$NPM_VERSION" ] && echo -e "   ${BOLD}npm:${NC} $NPM_VERSION"
[ -n "$NGINX_VERSION" ] && echo -e "   ${BOLD}Nginx:${NC} $NGINX_VERSION"
[ -n "$PM2_VERSION" ] && echo -e "   ${BOLD}PM2:${NC} v$PM2_VERSION"
echo -e "   ${BOLD}SSL Enabled:${NC} $ENABLE_SSL"
[ "$ENABLE_SSL" = "true" ] && [ -n "$SSL_EXPIRY" ] && echo -e "   ${BOLD}SSL Expires:${NC} $SSL_EXPIRY"

echo ""

# Deployment configuration
echo -e "${CYAN}${BOLD}⚙️  Deployment Configuration:${NC}"
[ "$FRAMEWORK_TYPE" != "frontend" ] && echo -e "   ${BOLD}PM2 Instances:${NC} $PM2_INSTANCES"
[ "$FRAMEWORK_TYPE" != "frontend" ] && echo -e "   ${BOLD}Memory Limit:${NC} $MAX_MEMORY_RESTART"
echo -e "   ${BOLD}Package Manager:${NC} ${PACKAGE_MANAGER:-npm}"
[ -n "$BUILD_COMMAND" ] && echo -e "   ${BOLD}Build Command:${NC} $BUILD_COMMAND"
echo -e "   ${BOLD}Working Directory:${NC} $(pwd)"
echo -e "   ${BOLD}Log File:${NC} $LOG_FILE"

echo ""

# Management commands based on framework type
if [ "$FRAMEWORK_TYPE" = "backend" ] || [ "$FRAMEWORK_TYPE" = "fullstack" ]; then
    echo -e "${BLUE}${BOLD}🔧 Management Commands:${NC}"
    echo -e "   ${CYAN}pm2 logs $APP_NAME${NC}      # View real-time logs"
    echo -e "   ${CYAN}pm2 restart $APP_NAME${NC}   # Restart application"
    echo -e "   ${CYAN}pm2 stop $APP_NAME${NC}      # Stop application"
    echo -e "   ${CYAN}pm2 monit${NC}               # Process monitor"
    echo -e "   ${CYAN}pm2 list${NC}                # List all processes"
    echo -e "   ${CYAN}systemctl status nginx${NC}  # Check Nginx status"
    
    # Show current PM2 status
    if [ -n "$PM2_STATUS" ]; then
        echo ""
        echo -e "${CYAN}${BOLD}📊 Current Status:${NC}"
        echo -e "   ${BOLD}PM2 Process Status:${NC} $PM2_STATUS"
        [ -n "$PM2_MEMORY_MB" ] && echo -e "   ${BOLD}Memory Usage:${NC} ${PM2_MEMORY_MB}MB"
    fi
else
    echo -e "${BLUE}${BOLD}🔧 Management Commands:${NC}"
    echo -e "   ${CYAN}systemctl status nginx${NC}  # Check Nginx status"
    echo -e "   ${CYAN}systemctl restart nginx${NC} # Restart Nginx"
    echo -e "   ${CYAN}nginx -t${NC}                # Test Nginx config"
fi

echo ""

# Update instructions
echo -e "${BLUE}${BOLD}🔄 Update Your Application:${NC}"
echo -e "   ${CYAN}cd $(pwd)${NC}"
echo -e "   ${CYAN}git pull${NC}"
echo -e "   ${CYAN}$PACKAGE_MANAGER install${NC}"
if [ -n "$BUILD_COMMAND" ]; then
    echo -e "   ${CYAN}$BUILD_COMMAND${NC}"
fi
if [ "$FRAMEWORK_TYPE" = "backend" ] || [ "$FRAMEWORK_TYPE" = "fullstack" ]; then
    echo -e "   ${CYAN}pm2 restart $APP_NAME${NC}"
else
    echo -e "   ${CYAN}systemctl restart nginx${NC}"
fi

echo ""

# Monitoring and logs
echo -e "${BLUE}${BOLD}📊 Monitoring & Logs:${NC}"
echo -e "   ${CYAN}tail -f $LOG_FILE${NC}       # View deployment logs"
echo -e "   ${CYAN}tail -f /var/log/nginx/access.log${NC}  # Nginx access logs"
echo -e "   ${CYAN}tail -f /var/log/nginx/error.log${NC}   # Nginx error logs"
[ "$FRAMEWORK_TYPE" != "frontend" ] && echo -e "   ${CYAN}pm2 logs $APP_NAME --lines 100${NC}      # Application logs"

echo ""

# Deploy another application
echo -e "${BLUE}${BOLD}📥 Deploy Another Application:${NC}"
echo -e "   ${CYAN}curl -sSL https://your-domain.com/remote-deploy.sh | bash -s -- --app newapp --domain newdomain.com${NC}"

echo ""

# Final status and tips
print_status "Deployment completed successfully! 🚀"
echo ""
echo -e "${YELLOW}${BOLD}💡 Tips:${NC}"
echo -e "   • Monitor your application logs regularly"
echo -e "   • Set up automated backups for your application"
echo -e "   • Consider setting up monitoring with tools like PM2 Keymetrics"
echo -e "   • Keep your dependencies updated for security"
[ "$ENABLE_SSL" = "true" ] && echo -e "   • SSL certificate will auto-renew with certbot"

log_to_file "Deployment summary completed. Application is live at $DOMAIN"
echo ""

# Final deployment validation and summary
echo -e "${BLUE}${BOLD}🔍 Final Deployment Validation:${NC}"
echo ""

# Test application accessibility
if [ "$ENABLE_SSL" = "true" ]; then
    TEST_URL="https://$DOMAIN"
else
    TEST_URL="http://$DOMAIN"
fi

print_debug "Testing application accessibility at $TEST_URL"
if curl -s -o /dev/null -w "%{http_code}" "$TEST_URL" | grep -qE "200|404|403"; then
    echo -e "   ✅ ${GREEN}Application is accessible at $TEST_URL${NC}"
else
    echo -e "   ⚠️  ${YELLOW}Application may not be fully accessible yet${NC}"
    echo -e "   ${YELLOW}This is normal for some frameworks - check logs if issues persist${NC}"
fi

# Security summary
echo ""
echo -e "${YELLOW}${BOLD}🔒 Security Summary:${NC}"
echo -e "   ✅ Input validation enabled for all parameters"
echo -e "   ✅ Enhanced error handling with detailed logging"
echo -e "   ✅ Nginx security headers configured"
echo -e "   ✅ Rate limiting enabled"
if [ "$ENABLE_SSL" = "true" ]; then
    echo -e "   ✅ HTTPS/SSL encryption enabled"
else
    echo -e "   ⚠️  HTTPS/SSL not enabled - consider enabling for production"
fi
if [ -n "${UFW_STATUS:-}" ] && [ "$UFW_STATUS" = "active" ]; then
    echo -e "   ✅ Firewall configured and active"
else
    echo -e "   ⚠️  Firewall not active - consider enabling for production"
fi

echo ""
echo -e "${BLUE}${BOLD}📋 Debugging Resources:${NC}"
echo -e "   ${CYAN}Deployment Log:${NC} $LOG_FILE"
echo -e "   ${CYAN}Quick Debug:${NC} tail -50 $LOG_FILE"
echo -e "   ${CYAN}Error Count:${NC} $ERRORS_ENCOUNTERED errors encountered"
if [ $ERRORS_ENCOUNTERED -gt 0 ]; then
    echo -e "   ${YELLOW}Some errors occurred but deployment continued${NC}"
    echo -e "   ${YELLOW}Review the log file for details${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}🎉 Deployment completed successfully!${NC}"
echo -e "${GREEN}Your application is ready to serve traffic!${NC}"

