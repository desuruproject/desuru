#!/bin/bash

# 🚀 Universal JavaScript Framework Deployment Script
# Supports React, Next.js, Vue, Angular, Nuxt, Svelte, Gatsby, Node.js, and more!
# Optimized for remote execution via curl/wget
#
# Usage:
#   curl -sSL https://your-domain.com/remote-deploy.sh | bash -s -- --app myapp --domain example.com
#   wget -qO- https://your-domain.com/remote-deploy.sh | bash -s -- --app myapp --domain example.com
#
# GitHub Example:
#   curl -sSL https://raw.githubusercontent.com/user/repo/main/remote-deploy.sh | bash -s -- --app myapp --domain example.com

set -e

# Color codes for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

# Enhanced logging functions with detailed context
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_status() { 
    local msg="✅ $1"
    echo -e "${GREEN}$msg${NC}"
    log_to_file "SUCCESS: $1"
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
}

print_error() { 
    local msg="❌ $1"
    echo -e "${RED}$msg${NC}"
    log_to_file "ERROR: $1"
}

print_step() { 
    STEP_COUNTER=$((STEP_COUNTER + 1))
    local msg="🔄 Step $STEP_COUNTER: $1"
    echo -e "${CYAN}$msg${NC}"
    log_to_file "STEP $STEP_COUNTER: $1"
}

print_debug() {
    local msg="🐛 DEBUG: $1"
    echo -e "${YELLOW}$msg${NC}"
    log_to_file "DEBUG: $1"
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

# Validate required parameters
if [ -z "$APP_NAME" ] || [ -z "$DOMAIN" ]; then
    print_error "Missing required parameters!"
    echo ""
    show_usage
    exit 1
fi

# Validate SSL configuration
if [ "$ENABLE_SSL" = "true" ] && [ -z "$EMAIL_FOR_SSL" ]; then
    print_error "SSL enabled but no email provided!"
    print_warning "Email is required for Let's Encrypt certificates"
    print_info "Use: --email your@email.com"
    exit 1
fi

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
print_debug "Running: apt update -y"
if apt update -y >/dev/null 2>&1; then
    print_status "System packages updated"
else
    print_error "Failed to update system packages"
    print_debug "Check network connectivity and repository configuration"
    exit 1
fi

# Install Node.js 20.x if not already installed
if ! command -v node &> /dev/null; then
    print_step "Installing Node.js 20.x..."
    print_debug "Downloading NodeSource setup script..."
    if curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1; then
        print_debug "Installing Node.js package..."
        if apt install -y nodejs >/dev/null 2>&1; then
            NODE_VERSION=$(node --version)
            print_status "Node.js $NODE_VERSION installed"
            log_to_file "Node.js $NODE_VERSION installed successfully"
        else
            print_error "Failed to install Node.js package"
            exit 1
        fi
    else
        print_error "Failed to setup Node.js repository"
        exit 1
    fi
else
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    print_info "Node.js $NODE_VERSION already installed"
    print_info "npm $NPM_VERSION available"
    log_to_file "Using existing Node.js $NODE_VERSION"
fi

# Install nginx if not already installed
if ! command -v nginx &> /dev/null; then
    print_step "Installing Nginx..."
    print_debug "Installing nginx package..."
    if apt install -y nginx >/dev/null 2>&1; then
        NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3)
        print_status "Nginx $NGINX_VERSION installed"
        log_to_file "Nginx $NGINX_VERSION installed successfully"
    else
        print_error "Failed to install Nginx"
        exit 1
    fi
else
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3)
    print_info "Nginx $NGINX_VERSION already installed"
    log_to_file "Using existing Nginx $NGINX_VERSION"
fi

# Install PM2 globally if not already installed (only for backend apps)
if [ "$FRAMEWORK_TYPE" = "backend" ] || [ "$FRAMEWORK_TYPE" = "fullstack" ]; then
    if ! command -v pm2 &> /dev/null; then
        print_step "Installing PM2..."
        print_debug "Installing PM2 globally with npm..."
        if npm install -g pm2 >/dev/null 2>&1; then
            PM2_VERSION=$(pm2 --version)
            print_status "PM2 v$PM2_VERSION installed"
            log_to_file "PM2 v$PM2_VERSION installed successfully"
        else
            print_error "Failed to install PM2"
            exit 1
        fi
    else
        PM2_VERSION=$(pm2 --version)
        print_info "PM2 v$PM2_VERSION already installed"
        log_to_file "Using existing PM2 v$PM2_VERSION"
    fi
else
    print_info "Skipping PM2 installation (frontend framework detected)"
fi

# Install application dependencies
print_step "Installing application dependencies..."
print_debug "Checking for package-lock.json or yarn.lock..."

if [ -f "package.json" ]; then
    # Determine package manager
    if [ -f "yarn.lock" ]; then
        PACKAGE_MANAGER="yarn"
        print_debug "Using Yarn package manager"
    elif [ -f "pnpm-lock.yaml" ]; then
        PACKAGE_MANAGER="pnpm"
        print_debug "Using PNPM package manager"
    else
        PACKAGE_MANAGER="npm"
        print_debug "Using NPM package manager"
    fi
    
    print_debug "Installing dependencies with $PACKAGE_MANAGER..."
    if $PACKAGE_MANAGER install >/dev/null 2>&1; then
        print_status "Dependencies installed with $PACKAGE_MANAGER"
        log_to_file "Dependencies installed successfully with $PACKAGE_MANAGER"
    else
        print_error "Failed to install dependencies with $PACKAGE_MANAGER"
        print_debug "Trying fallback to npm..."
        if npm install >/dev/null 2>&1; then
            print_status "Dependencies installed with npm (fallback)"
            log_to_file "Dependencies installed with npm (fallback)"
        else
            print_error "Failed to install dependencies"
            print_debug "Check package.json for syntax errors or network connectivity"
            exit 1
        fi
    fi
else
    print_warning "No package.json found, skipping dependency installation"
fi

# Build the application if needed
if [ -n "$BUILD_COMMAND" ]; then
    print_step "Building application..."
    print_debug "Running build command: $BUILD_COMMAND"
    
    if $BUILD_COMMAND >/dev/null 2>&1; then
        print_status "Application built successfully"
        log_to_file "Build completed successfully with: $BUILD_COMMAND"
        
        # Verify build directory exists for frontend apps
        if [ "$SERVE_STATIC" = "true" ] && [ -n "$BUILD_DIR" ]; then
            if [ -d "$BUILD_DIR" ]; then
                BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
                print_info "Build directory created: $BUILD_DIR ($BUILD_SIZE)"
                log_to_file "Build directory: $BUILD_DIR, Size: $BUILD_SIZE"
            else
                print_warning "Build directory $BUILD_DIR not found after build"
                # Try to find common build directories
                for dir in dist build out public .next; do
                    if [ -d "$dir" ]; then
                        BUILD_DIR="$dir"
                        BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
                        print_info "Found alternative build directory: $BUILD_DIR ($BUILD_SIZE)"
                        log_to_file "Alternative build directory found: $BUILD_DIR"
                        break
                    fi
                done
            fi
        fi
    else
        print_error "Build failed!"
        print_debug "Build command '$BUILD_COMMAND' returned non-zero exit code"
        print_info "Common build issues:"
        print_info "1. Missing dependencies (try running dependencies install again)"
        print_info "2. Syntax errors in source code"
        print_info "3. Insufficient memory or disk space"
        print_info "4. Missing environment variables"
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

# Configure Nginx
print_step "Configuring Nginx..."
print_debug "Framework type: $FRAMEWORK_TYPE, Serve static: $SERVE_STATIC"

if [ "$SERVE_STATIC" = "true" ]; then
    print_debug "Creating static file server configuration for $BUILD_DIR"
    cat > "/etc/nginx/sites-available/$APP_NAME" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $(pwd)/$BUILD_DIR;
    index index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Handle client-side routing (SPA)
    location / {
        try_files \$uri \$uri/ /index.html;
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
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    print_info "Static file server configured for $(pwd)/$BUILD_DIR"
    log_to_file "Nginx configured for static files: $(pwd)/$BUILD_DIR"
else
    print_debug "Creating reverse proxy configuration for backend application"
    cat > "/etc/nginx/sites-available/$APP_NAME" << EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

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

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    print_info "Reverse proxy configured for localhost:$APP_PORT"
    log_to_file "Nginx configured as reverse proxy to localhost:$APP_PORT"
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
print_debug "Running nginx configuration test..."
if nginx -t >/dev/null 2>&1; then
    print_debug "Nginx configuration test passed"
    print_debug "Restarting Nginx service..."
    if systemctl restart nginx >/dev/null 2>&1; then
        if systemctl enable nginx >/dev/null 2>&1; then
            print_status "Nginx configured and restarted"
            log_to_file "Nginx service restarted and enabled"
            
            # Verify Nginx is running
            if systemctl is-active nginx >/dev/null 2>&1; then
                print_info "Nginx service is active and running"
            else
                print_warning "Nginx service may not be running properly"
            fi
        else
            print_warning "Failed to enable Nginx service on boot"
        fi
    else
        print_error "Failed to restart Nginx service"
        exit 1
    fi
else
    print_error "Nginx configuration test failed!"
    print_debug "Nginx configuration errors:"
    nginx -t 2>&1 | while read line; do print_debug "$line"; done
    log_to_file "Nginx configuration test failed"
    exit 1
fi

# Configure SSL if enabled
if [ "$ENABLE_SSL" = "true" ] && [ "$DOMAIN" != "localhost" ]; then
    print_step "Setting up SSL certificate..."
    print_debug "Installing certbot and nginx plugin..."
    if apt install -y certbot python3-certbot-nginx >/dev/null 2>&1; then
        print_debug "Running certbot for domain: $DOMAIN"
        if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL_FOR_SSL" >/dev/null 2>&1; then
            print_status "SSL certificate installed successfully"
            log_to_file "SSL certificate installed for $DOMAIN"
            
            # Verify SSL is working
            SSL_EXPIRY=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
            if [ -n "$SSL_EXPIRY" ]; then
                print_info "SSL certificate expires: $SSL_EXPIRY"
            fi
        else
            print_warning "SSL certificate installation failed"
            print_debug "Common SSL issues:"
            print_debug "1. Domain doesn't point to this server"
            print_debug "2. Firewall blocking port 80/443"
            print_debug "3. Rate limits reached"
            print_info "You can manually run: certbot --nginx -d $DOMAIN"
            log_to_file "SSL certificate installation failed for $DOMAIN"
        fi
    else
        print_error "Failed to install certbot"
    fi
fi

# Configure firewall if available
if command -v ufw &> /dev/null; then
    print_step "Configuring firewall..."
    print_debug "Allowing Nginx Full and OpenSSH through firewall"
    if ufw allow 'Nginx Full' >/dev/null 2>&1 && ufw allow OpenSSH >/dev/null 2>&1; then
        print_status "Firewall configured"
        log_to_file "Firewall rules configured: Nginx Full, OpenSSH allowed"
        
        # Show firewall status
        UFW_STATUS=$(ufw status 2>/dev/null | grep "Status:" | cut -d' ' -f2)
        print_info "Firewall status: ${UFW_STATUS:-unknown}"
    else
        print_warning "Failed to configure firewall rules"
    fi
else
    print_info "UFW firewall not available, skipping firewall configuration"
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
echo -e "${GREEN}Your application is ready to serve traffic! 🎉${NC}"

