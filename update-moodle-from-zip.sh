#!/bin/bash

# Define log file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="moodle_update_${TIMESTAMP}.log"

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR=""
BACKUP_CREATED=false

# Function to display initial warnings and script info
display_info() {
    cat <<EOF
###############################################
# MOODLE AutoUpdater BY ZIP  by Daniel Seixas #
# Version 1.0                                 #
# Use at your own risk                        #
###############################################
This script allows you to update Moodle from a ZIP file while preserving
your custom plugins and configuration.

IMPORTANT: Always backup your database and files before running this script!
EOF
}

# Function to display usage
usage() {
    echo "ERROR: USAGE: $0 <current-moodle-dir> <moodle_zip.zip>" | tee -a "$LOGFILE"
    echo "Example: $0 /var/www/html/moodle moodle-4.3.zip" | tee -a "$LOGFILE"
    exit 2
}

# Function to log messages with timestamp
log_message() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOGFILE"
}

# Function to handle errors and cleanup
error_exit() {
    log_message "ERROR" "$1"
    cleanup_temp_files
    if [ "$BACKUP_CREATED" = true ]; then
        log_message "INFO" "Backup is available at: ./current_moodle_bck"
    fi
    exit 1
}

# Function to cleanup temporary files
cleanup_temp_files() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_message "INFO" "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}

# Function to validate zip file structure
validate_zip_structure() {
    local zip_file="$1"
    log_message "INFO" "Validating ZIP file structure..."
    
    # Check if zip contains a moodle directory with version.php
    if ! unzip -l "$zip_file" | grep -q "moodle/version.php"; then
        error_exit "ZIP file does not contain a valid Moodle installation (missing moodle/version.php)"
    fi
    
    # Check for essential directories
    local essential_dirs=("admin" "lib" "course" "user")
    for dir in "${essential_dirs[@]}"; do
        if ! unzip -l "$zip_file" | grep -q "moodle/$dir/"; then
            error_exit "ZIP file missing essential directory: $dir"
        fi
    done
    
    log_message "INFO" "ZIP file structure validation passed"
}

# Function to extract version from version.php
extract_moodle_version() {
    local version_file="$1"
    if [ ! -f "$version_file" ]; then
        echo "unknown"
        return
    fi
    
    # Extract version and release information
    local version=$(grep '$release' "$version_file" | head -1 | sed "s/.*'\([^']*\)'.*/\1/")
    local build=$(grep '$version' "$version_file" | head -1 | sed 's/[^0-9]*\([0-9]\+\).*/\1/')
    
    if [ -n "$version" ]; then
        echo "$version (Build: $build)"
    else
        echo "unknown"
    fi
}

# Function to validate preconditions
validate_preconditions() {
    log_message "INFO" "Running pre-update checks..."

    # Check if required directories are set
    if [ -z "$MOODLE_DIR" ]; then
        error_exit "MOODLE_DIR is not defined"
    fi

    # Check if Moodle directory exists and is valid
    if [ ! -d "$MOODLE_DIR" ]; then
        error_exit "Moodle directory ($MOODLE_DIR) does not exist"
    fi

    if [ ! -f "$MOODLE_DIR/version.php" ]; then
        error_exit "Not a valid Moodle installation (version.php not found)"
    fi

    if [ ! -f "$MOODLE_DIR/config.php" ]; then
        error_exit "Moodle config.php not found"
    fi

    # Extract and validate moodledata directory
    if [ -n "$MOODLEDATA_DIR" ] && [ ! -d "$MOODLEDATA_DIR" ]; then
        error_exit "Moodledata directory ($MOODLEDATA_DIR) does not exist"
    fi

    # Check for minimum disk space (2GB for safety)
    local required_space_mb=2048
    local available_space_mb=$(df -Pm "$MOODLE_DIR" | tail -1 | awk '{print $4}')

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        error_exit "Not enough disk space. Required: ${required_space_mb}MB. Available: ${available_space_mb}MB"
    fi

    # Check for required commands
    local required_commands=("unzip" "mysqldump" "php")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "Required command not found: $cmd"
        fi
    done

    # Warn if running as root
    if [ "$(id -u)" -eq 0 ]; then
        log_message "WARN" "Running as root. Consider using a regular user with sudo privileges"
    fi

    log_message "INFO" "Pre-update validations passed"
}

# Function to select PHP version
select_php_version() {
    # Try to find PHP automatically first
    if command -v php >/dev/null 2>&1; then
        PHP_BINARY=$(command -v php)
        local php_version=$(php -v | head -1 | awk '{print $2}')
        log_message "INFO" "Using PHP: $PHP_BINARY (version $php_version)"
        return
    fi

    # Fallback to manual selection if available
    local php_versions=($(update-alternatives --list php 2>/dev/null | awk -F '/' '{print $NF}' | sort))
    
    if [ ${#php_versions[@]} -eq 0 ]; then
        error_exit "No PHP installation found"
    fi
    
    log_message "INFO" "Available PHP versions:"
    select version in "${php_versions[@]}"; do
        if [[ -n "$version" ]]; then
            log_message "INFO" "Selected PHP version: $version"
            PHP_BINARY=$(update-alternatives --list php | grep "$version")
            return
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Function to enable maintenance mode
enable_maintenance_mode() {
    log_message "INFO" "Enabling maintenance mode..."
    if ! sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/admin/cli/maintenance.php" --enable; then
        error_exit "Failed to enable maintenance mode"
    fi
}

# Function to disable maintenance mode
disable_maintenance_mode() {
    log_message "INFO" "Disabling maintenance mode..."
    if ! sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/admin/cli/maintenance.php" --disable; then
        log_message "WARN" "Failed to disable maintenance mode. You may need to do this manually."
    fi
}

# Function to backup database
backup_database() {
    log_message "INFO" "Starting database backup..."
    
    local dbname=$(grep 'dbname' "$MOODLE_DIR/config.php" | awk '{print $3}' | sed "s/'\|;//g")
    local dbuser=$(grep 'dbuser' "$MOODLE_DIR/config.php" | awk '{print $3}' | sed "s/'\|;//g")
    local dbpass=$(grep 'dbpass' "$MOODLE_DIR/config.php" | awk '{print $3}' | sed "s/'\|;//g")
    
    if [ -z "$dbname" ]; then
        error_exit "Could not extract database name from config.php"
    fi
    
    local backup_file="moodle_db_backup_${TIMESTAMP}.sql"
    
    # Try backup with extracted credentials first, then prompt for root
    if [ -n "$dbuser" ] && [ -n "$dbpass" ]; then
        if mysqldump -u "$dbuser" -p"$dbpass" "$dbname" > "$backup_file" 2>/dev/null; then
            log_message "INFO" "Database backup completed: $backup_file"
            return
        fi
    fi
    
    # Fallback to root access
    log_message "INFO" "Attempting database backup with root access..."
    if mysqldump -u root -p "$dbname" > "$backup_file"; then
        log_message "INFO" "Database backup completed: $backup_file"
    else
        log_message "WARN" "Database backup failed. Continuing without backup."
    fi
}

# Function to create file backup
create_file_backup() {
    log_message "INFO" "Creating backup of current Moodle installation..."
    
    local backup_dir="./moodle_backup_${TIMESTAMP}"
    if cp -pr "$MOODLE_DIR" "$backup_dir"; then
        log_message "INFO" "File backup completed: $backup_dir"
        BACKUP_CREATED=true
    else
        error_exit "Failed to create file backup"
    fi
}

# Function to extract and prepare new Moodle
extract_new_moodle() {
    local zip_file="$1"
    
    log_message "INFO" "Extracting new Moodle from ZIP file..."
    
    TEMP_DIR=$(mktemp -d)
    if ! unzip -qo "$zip_file" -d "$TEMP_DIR"; then
        error_exit "Failed to extract ZIP file"
    fi
    
    NEW_MOODLE_DIR="$TEMP_DIR/moodle"
    if [ ! -d "$NEW_MOODLE_DIR" ]; then
        error_exit "Extracted ZIP does not contain moodle directory"
    fi
    
    log_message "INFO" "New Moodle extracted to: $NEW_MOODLE_DIR"
}

# Function to copy custom plugins and configurations
copy_customizations() {
    log_message "INFO" "Copying custom plugins and configurations..."
    
    # Directories to process (removed duplicates and added more)
    local folders=("mod" "theme" "local" "blocks" "auth" "report" "question" "qtype" "filter" "repository" "course/format")
    
    for folder in "${folders[@]}"; do
        if [ ! -d "$MOODLE_DIR/$folder" ]; then
            continue
        fi
        
        log_message "INFO" "Processing directory: $folder"
        
        # Create directory in new Moodle if it doesn't exist
        if [ ! -d "$NEW_MOODLE_DIR/$folder" ]; then
            mkdir -p "$NEW_MOODLE_DIR/$folder"
        fi
        
        # Find custom plugins (not in new Moodle)
        while IFS= read -r -d '' plugin_dir; do
            local plugin_name=$(basename "$plugin_dir")
            if [ ! -d "$NEW_MOODLE_DIR/$folder/$plugin_name" ]; then
                log_message "INFO" "Copying custom plugin: $folder/$plugin_name"
                if ! cp -pr "$plugin_dir" "$NEW_MOODLE_DIR/$folder/"; then
                    log_message "WARN" "Failed to copy plugin: $folder/$plugin_name"
                fi
            fi
        done < <(find "$MOODLE_DIR/$folder" -maxdepth 1 -type d -print0 2>/dev/null)
    done
}

# Function to copy configuration and set permissions
finalize_installation() {
    log_message "INFO" "Copying configuration file..."
    if ! cp "$MOODLE_DIR/config.php" "$NEW_MOODLE_DIR/config.php"; then
        error_exit "Failed to copy config.php"
    fi
    
    # Update theme to boost for safety (optional)
    log_message "INFO" "Setting default theme to boost for compatibility..."
    sed -i.bak "s/\$CFG->theme = '[^']*'/\$CFG->theme = 'boost'/" "$NEW_MOODLE_DIR/config.php" 2>/dev/null || true
    
    log_message "INFO" "Setting file permissions..."
    chown -R root:root "$NEW_MOODLE_DIR"
    
    # Set permissions for plugin directories (fixed duplicates)
    local plugin_dirs=("mod" "theme" "local" "auth" "blocks" "course/format" "question" "qtype" "filter")
    for dir in "${plugin_dirs[@]}"; do
        if [ -d "$NEW_MOODLE_DIR/$dir" ]; then
            chown -R www-data:www-data "$NEW_MOODLE_DIR/$dir"
        fi
    done
    
    chmod -R 755 "$NEW_MOODLE_DIR"
}

# Function to replace Moodle installation
replace_moodle() {
    log_message "INFO" "Replacing current Moodle installation..."
    
    # Remove old backup if exists
    if [ -d "${MOODLE_DIR}_OLD" ]; then
        rm -rf "${MOODLE_DIR}_OLD"
    fi
    
    # Move current to backup
    if ! mv "$MOODLE_DIR" "${MOODLE_DIR}_OLD"; then
        error_exit "Failed to backup current Moodle directory"
    fi
    
    # Move new Moodle to current location
    if ! mv "$NEW_MOODLE_DIR" "$MOODLE_DIR"; then
        # Try to restore on failure
        mv "${MOODLE_DIR}_OLD" "$MOODLE_DIR"
        error_exit "Failed to move new Moodle to current location"
    fi
    
    log_message "INFO" "Moodle installation replaced successfully"
}

# Function to run Moodle upgrade
run_moodle_upgrade() {
    log_message "INFO" "Running Moodle upgrade process..."
    
    if sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/admin/cli/upgrade.php" --non-interactive; then
        log_message "INFO" "Moodle upgrade completed successfully"
    else
        log_message "ERROR" "Moodle upgrade failed. Check the logs and web interface."
        return 1
    fi
}

# Function to remove trailing slash
remove_trailing_slash() {
    local path="$1"
    echo "${path%/}"
}

# Trap to ensure cleanup on exit
trap cleanup_temp_files EXIT

# Main script execution
main() {
    # Start logging
    exec > >(tee -a "$LOGFILE") 2>&1
    
    log_message "INFO" "Starting Moodle update process..."
    display_info
    
    # Check arguments
    if [ "$#" -ne 2 ]; then
        usage
    fi
    
    # Validate inputs
    local moodle_dir=$(remove_trailing_slash "$1")
    local zip_file="$2"
    
    if [ ! -d "$moodle_dir" ]; then
        error_exit "Current Moodle directory does not exist: $moodle_dir"
    fi
    
    if [ ! -f "$zip_file" ]; then
        error_exit "Moodle ZIP file does not exist: $zip_file"
    fi
    
    # Set global variables
    MOODLE_DIR="$moodle_dir"
    
    # Extract moodledata directory from config.php
    if [ -f "$MOODLE_DIR/config.php" ]; then
        MOODLEDATA_DIR=$(grep "^.CFG..dataroot" "$MOODLE_DIR/config.php" | awk '{print $3}' | sed "s/;\|'//g")
    fi
    
    # Validate ZIP file structure
    validate_zip_structure "$zip_file"
    
    # Run precondition validations
    validate_preconditions
    
    # Select PHP version
    select_php_version
    
    # Extract version information
    local current_version=$(extract_moodle_version "$MOODLE_DIR/version.php")
    log_message "INFO" "Current Moodle version: $current_version"
    
    # Display pre-update instructions
    echo ""
    log_message "INFO" "BEFORE proceeding, ensure you have:"
    echo "1. ✅ Maintenance mode will be enabled automatically"
    echo "2. 📦 Database backup will be offered"
    echo "3. 📁 File backup will be created automatically"
    echo "4. 🔄 Moodle upgrade will be run automatically"
    echo ""
    
    # Enable maintenance mode
    enable_maintenance_mode
    
    # Prompt for confirmation
    read -p "Do you want to proceed with the update? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        disable_maintenance_mode
        log_message "INFO" "Update cancelled by user"
        exit 0
    fi
    
    # Offer database backup
    read -p "Do you want to create a database backup? [Y/n]: " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        backup_database
    fi
    
    # Create file backup
    create_file_backup
    
    # Extract new Moodle
    extract_new_moodle "$zip_file"
    
    # Copy customizations
    copy_customizations
    
    # Finalize installation
    finalize_installation
    
    # Prompt to replace
    read -p "Do you want to replace the current Moodle installation? [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        replace_moodle
        
        # Prompt to run upgrade
        read -p "Do you want to run the Moodle upgrade now? [Y/n]: " -r
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            run_moodle_upgrade
        fi
    fi
    
    # Disable maintenance mode
    disable_maintenance_mode
    
    # Final instructions
    echo ""
    log_message "INFO" "Update process completed!"
    echo "📋 Next steps:"
    echo "1. Check your Moodle site functionality"
    echo "2. Review the upgrade log at: $LOGFILE"
    echo "3. If issues occur, restore from backup: ${MOODLE_DIR}_OLD"
    echo "4. Clean up backup files when satisfied with the update"
}

# Run main function
main "$@"

