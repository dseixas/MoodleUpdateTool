#!/bin/bash

# Define log file
LOGFILE="moodle_update.log"

# Function to display initial warnings and script info
display_info() {
    cat <<EOF
###############################################
# MOODLE AutoUpdater BY ZIP  by Daniel Seixas #
# Version 0.1                                 #
# Use at your own risk                        #
###############################################
This script allows you to update moodle if you have the new moodle version in zip 
mode.
EOF
}

# Function to display usage
usage() {
    echo "ERROR: USAGE: update-moodle current-moodle-dir moodle_zip.zip" | tee -a "$LOGFILE"
    exit 2
}

# Function to select PHP version
select_php_version() {
    local php_versions=($(update-alternatives --list php | awk -F '/' '{print $NF}' | sort))
    echo "Available PHP versions:" | tee -a "$LOGFILE"
    select version in "${php_versions[@]}"; do
        if [[ -n "$version" ]]; then
            echo "Selected PHP version: $version" | tee -a "$LOGFILE"
            PHP_BINARY=$(update-alternatives --list php | grep "$version")
            return
        else
            echo "Invalid selection. Please try again." | tee -a "$LOGFILE"
        fi
    done
}

# Function to enable maintenance mode
enable_maintenance_mode() {
    sudo -u www-data "$PHP_BINARY" "$1/admin/cli/maintenance.php" --enable | tee -a "$LOGFILE"
}

# Function to disable maintenance mode
disable_maintenance_mode() {
    sudo -u www-data "$PHP_BINARY" "$1/admin/cli/maintenance.php" --disable | tee -a "$LOGFILE"
}

# Function to remove trailing slash if present
remove_trailing_slash() {
    local path=$1
    # Remove trailing slash if it exists
    path="${path%/}"
    echo "$path"
}

# Start logging
exec &> >(tee -a "$LOGFILE")

# Display initial warnings and script info
display_info

# Check for the correct number of arguments
if [ "$#" -ne 2 ]; then
    usage
fi

# Check if the current Moodle directory exists
if [ ! -d "$1" ]; then
    echo "ERROR: Current Moodle directory does NOT exist" | tee -a "$LOGFILE"
    exit 1
fi

# Check if the new Moodle zip file exists
if [ ! -f "$2" ]; then
    echo "ERROR: New Moodle version file does NOT exist" | tee -a "$LOGFILE"
    exit 1
fi

# Select PHP version
select_php_version

# Extracting current and new Moodle versions
current_version=$(grep '(Build:' "$1/version.php" | awk '{print $3 $4 $5}' | sed 's/;\|\///g')
new_version=$(echo "$2" | grep -oP '\d+') 



#preparing $1 value:

echo "PREProcessed input: $1"
# Remove trailing slash and assign the result to a new variable
set -- "$(remove_trailing_slash "$1")" "${@:2}"


# Continue with the rest of your script using $1
# For example, you can use $1 in further commands like this:
# echo "Using modified input: $1"


echo "Current Moodle version: $current_version" | tee -a "$LOGFILE"
echo "New Moodle version: $new_version" | tee -a "$LOGFILE"

# Instructions before proceeding
echo "BEFORE proceeding you need to:" | tee -a "$LOGFILE"
echo "1. Activate Moodle maintenance mode" | tee -a "$LOGFILE"
echo "2. Backup the DB" | tee -a "$LOGFILE"
echo "3. Backup Moodle data (located in $(grep "^.CFG..dataroot" "$1/config.php" | awk '{print $3}' | sed "s/;\|'//g"))" | tee -a "$LOGFILE"
echo "4. Download and unzip the latest Moodle (Second parameter)" | tee -a "$LOGFILE"

# Enable maintenance mode
enable_maintenance_mode "$1"

# Prompt user for confirmation
read -p "Do you want to proceed (sSyYnN) [Default=N]? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[YySs]$ ]]; then
    disable_maintenance_mode "$1"
    exit 0
fi

# Optionally backup the database
read -p "Do you want to do a Database backup (dump) (you need root access) [yYNn (Default=n)]? " -n 1 -r
echo 
if [[ $REPLY =~ ^[YySs]$ ]]; then
    dbname=$(grep dbname "$1/config.php" | awk '{print $3}' | sed "s/'\|;//g")
    mysqldump -u root -p "$dbname" > moodle_bck.sql | tee -a "$LOGFILE"
fi

# Backup current Moodle directory
echo "Copying the current Moodle folder to a new temp location just in case ./current_moodle_bck" | tee -a "$LOGFILE"
cp -pr "$1" "./current_moodle_bck"

# Unzipping new Moodle
echo "Unzipping new Moodle" | tee -a "$LOGFILE"
if [[ -d ./new_moodle ]]; then
    rm -fr ./new_moodle
fi
unzip -qo "$2" -d ./new_moodle
new_moodle="./new_moodle/moodle"

echo "NEW MOODLE is in this folder: $new_moodle" | tee -a "$LOGFILE"

# Directories to process
FOLDERS="mod theme local blocks report resources"
  #I had to remove auth because it failed
  #FOLDERS="mod theme local blocks auth report resources"


# Processing directories
for folder in $FOLDERS; do
    echo "Processing directory: $folder" | tee -a "$LOGFILE"
    if [ ! -d "$new_moodle/$folder" ]; then
        echo "Directory does not exist in $new_moodle/$folder, creating it." | tee -a "$LOGFILE"
        mkdir -p "$new_moodle/$folder"
    fi

    for value in $(diff -q "$1/$folder" "$new_moodle/$folder" | grep -e "^Only in" -e "^Sólo en" | sed -n 's/[^:]*: //p'); do
        echo "Copying $1/$folder/$value to $new_moodle/$folder/$value" | tee -a "$LOGFILE"
        cp -pr "$1/$folder/$value" "$new_moodle/$folder/$value"  | tee -a "$LOGFILE"
    done
done

# Copy configuration file
echo "Copying configuration" | tee -a "$LOGFILE"
cp -pvr "$1/config.php" "$new_moodle/config.php" | tee -a "$LOGFILE"

# Change the default theme to Boost
echo "Changing default theme to Boost" | tee -a "$LOGFILE"
sed -i "s/'theme' => '.*'/'theme' => 'boost'/" "$new_moodle/config.php"

# Update permissions
echo "Updating permissions" | tee -a "$LOGFILE"
chown -R root:root "$new_moodle"
chown -R www-data:www-data "$new_moodle/mod" "$new_moodle/theme" "$new_moodle/local" "$new_moodle/auth"
chmod -R 755 "$new_moodle"

# Prompt to replace current Moodle with updated one
read -p "Do you want to REPLACE updated Moodle in current Moodle folder [yYNn (Default=n)]? " -n 1 -r
echo
if [[ $REPLY =~ ^[YySs]$ ]]; then
    echo "Removing  $1 _OLD" | tee -a "$LOGFILE"
    rm -fr "$1_OLD"
    mv "$1" "$1_OLD"
    echo "Moving $new_moodle to $1" | tee -a "$LOGFILE"
    mv "$new_moodle" "$1"
fi

# Prompt to update Moodle using CLI
read -p "Do you want to UPDATE Moodle now using CLI [yYNn (Default=n)]? " -n 1 -r
echo
if [[ $REPLY =~ ^[YySs]$ ]]; then
    sudo -u www-data "$PHP_BINARY" "$1/admin/cli/upgrade.php" | tee -a "$LOGFILE"
fi

# Disable maintenance mode
disable_maintenance_mode "$1"

# Final instructions
echo "Update completed. Remember the following steps:" | tee -a "$LOGFILE"
echo "1. Move the directory $2 to where Apache is configured" | tee -a "$LOGFILE"
echo "2. Connect to Moodle to finalize the update" | tee -a "$LOGFILE"
echo "Note: To disable maintenance mode via command line: php $2/admin/cli/maintenance.php --disable" | tee -a "$LOGFILE"

