#!/bin/bash

git_address="https://github.com/iamrigo/sqlar.git"
dir_address="/home/sqlar"
version="1.1.0"
# Define colors and Helper functions for colored messages
colors=( "\033[1;31m" "\033[1;35m" "\033[1;92m" "\033[38;5;46m" "\033[1;38;5;208m" "\033[1;36m" "\033[0m" )
red=${colors[0]} pink=${colors[1]} green=${colors[2]} spring=${colors[3]} orange=${colors[4]} cyan=${colors[5]} reset=${colors[6]}
print() { echo -e "${cyan}$1${reset}"; }
error() { echo -e "${red}✗ $1${reset}"; }
success() { echo -e "${spring}✓ $1${reset}"; }
log() { echo -e "${green}! $1${reset}"; }
input() { read -p "$(echo -e "${orange}▶ $1${reset}")" "$2"; }
confirm() { read -p "$(echo -e "\n${pink}Press any key to continue...${reset}")"; }

# Handle SIGINT (Ctrl+C)
trap 'echo -e "\n"; error "Script interrupted by user! if you have problem @ErfJab"; echo -e "\n"; exit 1' SIGINT

# Function to check if user is root, update system, install Python, curl, and necessary packages
check_needs() {
    log "Checking root..."
    echo -e "Current user: $(whoami)"
    if [ "$EUID" -ne 0 ]; then
        error "Error: This script must be run as root."
        exit 1
    fi

    # Update the system
    log "Updating the system..."
    sudo apt-get update -y
    if [ $? -ne 0 ]; then
        error "Failed to update the system."
        exit 1
    fi

    # Install Python if not already installed
    if ! command -v python3 &>/dev/null; then
        log "Installing Python..."
        sudo apt-get install -y python3
        if [ $? -ne 0 ]; then
            error "Failed to install Python."
            exit 1
        fi
    fi

    # Install curl if not already installed
    if ! command -v curl &>/dev/null; then
        log "Installing curl..."
        sudo apt-get install -y curl
        if [ $? -ne 0 ]; then
            error "Failed to install curl."
            exit 1
        fi
    fi
    success "System updated and required packages installed."
}

# Function for script main menu
menu() {
    clear
    print "\n\t Welcome to Sqlar!"
    print "\t\t version $version develop by @ErfJab (telegram & github)"
    print "—————————————————————————————————————————————————————————————————————————"
    print "1) Install bot"
    print "2) Uninstall bot"
    print "0) Exit"
    print ""
    input "Enter your option number: " option
    case $option in
        1) install_bot ;;
        2) uninstall_bot ;;
        0) print "Thank you for using ErfJab script. Goodbye!"; exit 0 ;;
        *) error "Invalid option, Please select a valid option!"; menu ;;
    esac
}

install_bot() {
    check_needs
    get_db_address
    get_bot_token
    get_admin_chatid
    get_language
    complete_install
    success "Bot installation completed successfully!"
}

get_db_address() {
    local env_file="/opt/marzban/.env"
    db_url=$(grep -E "^[[:space:]]*SQLALCHEMY_DATABASE_URL[[:space:]]*=" "$env_file" | sed -E 's/^[[:space:]]*SQLALCHEMY_DATABASE_URL[[:space:]]*=[[:space:]]*//' | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')
    if [ -n "$db_url" ]; then
        success "Your db address: $db_url"
    else
        error "SQLALCHEMY_DATABASE_URL not found or is commented out."
        exit 1
    fi
}

get_bot_token() {
    while true; do
        input "Please enter token bot: " token
        response=$(curl -s "https://api.telegram.org/bot$token/getMe")
        if echo "$response" | grep -q '"ok":true'; then
            success "Token is valid."
            break
        else
            error "Invalid token. Please try again."
        fi
    done
}

get_admin_chatid() {
    while true; do
        input "Enter admin chat ID: " admin_chatid
        if [[ "$admin_chatid" =~ ^-?[0-9]+$ ]]; then
            success "Admin chat ID is valid."
            break
        else
            error "Invalid input. Please enter a valid number."
        fi
    done
}

get_language() {
    while true; do
        print "Select language:"
        print "1) English"
        print "2) Persian"
        print "3) Russian"
        input "Enter your language option number: " lang
        case $lang in
            1) language="EN"; break ;;
            2) language="PR"; break ;;
            3) language="RU"; break ;;
            *) error "Invalid input. Please try again." ;;
        esac
    done
    success "Selected language: $language"
}

complete_install() {
    log "Downloading the project from GitHub..."
    git clone $git_address $dir_address
    if [ $? -ne 0 ]; then
        error "Failed to clone the repository."
        exit 1
    fi
    success "Project downloaded successfully."

    log "Creating .env file..."
    cat > $dir_address/.env << EOL
## soqaler bot settings
# bot settings
bot_token = "$token"
admin_chatid = "$admin_chatid"
language = "$language"

# db settings
db_address = "$db_url"
EOL
    success ".env file created successfully."

    log "Setting up virtual environment..."
    if [ ! -d "sqlar" ]; then
        python3 -m venv sqlar
    fi
    source sqlar/bin/activate
    pip install -r $dir_address/requirements.txt
    success "Virtual environment 'sqlar' created and dependencies installed."

    log "Starting the bot..."
    chmod +x $dir_address/sqlar.py 
    nohup python3 $dir_address/sqlar.py 
    if ps aux | grep -v grep | grep "$dir_address/sqlar.py" > /dev/null; then
        success "Bot is running."
    else
        error "Bot is not running."
        exit 1
    fi

    log "Setting up cron job..."
    (crontab -l 2>/dev/null; echo "@reboot python3 $dir_address/sqlar.py") | crontab -
    if [ $? -ne 0 ]; then
        error "Failed to set up cron job."
        exit 1
    fi
    success "Cron job set up successfully."
}


uninstall_bot() {
    log "Uninstalling the bot..."

    deactivate 2>/dev/null

    processes=("python3 /home/sqlar.py")
    for proc in "${processes[@]}"; do
        if pgrep -f "$proc" &> /dev/null; then
            proc_name=$(echo "$proc" | cut -d ' ' -f 2)
            echo -e "Stopping existing $proc_name process...\n"
            pkill -fx "$proc"
        fi
    done

    if [ -d "sqlar" ]; then
        rm -rf sqlar
        success "Virtual environment 'sqlar' removed."
    fi

    (crontab -l 2>/dev/null | grep -v "$dir_address/sqlar.py") | crontab -
    success "Cron job removed."

    if [ -d "$dir_address" ]; then
        rm -rf /home/sqlar
        success "Cloned project directory removed."
    fi

    success "Bot uninstallation completed successfully!"
}

run() {
    menu
}

run
