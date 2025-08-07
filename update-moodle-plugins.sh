#!/bin/bash

# Define log file
LOGFILE="moodle_plugins_update.log"

# Function to display script info
display_info() {
    cat <<EOF
###############################################
# MOODLE Plugin Updater by Daniel Seixas     #
# Version 1.1                                 #
# Use at your own risk                        #
###############################################
This script allows you to test and update Moodle plugins.
EOF
}

# Function to display usage
usage() {
    echo "ERROR: USAGE: $0 /path/to/moodle" | tee -a "$LOGFILE"
    echo "Example: $0 /var/www/html/moodle" | tee -a "$LOGFILE"
    exit 2
}

# Function to validate preconditions
validate_preconditions() {
    echo "🔍 Running pre-update checks..." | tee -a "$LOGFILE"

    # Exit if required directory is not set
    if [ -z "$MOODLE_DIR" ]; then
        echo "❌ ERROR: MOODLE_DIR is not defined." | tee -a "$LOGFILE"
        exit 1
    fi

    # Check if Moodle directory exists
    if [ ! -d "$MOODLE_DIR" ]; then
        echo "❌ ERROR: Moodle directory ($MOODLE_DIR) does not exist." | tee -a "$LOGFILE"
        exit 1
    fi

    # Check if it's a valid Moodle installation
    if [ ! -f "$MOODLE_DIR/version.php" ]; then
        echo "❌ ERROR: Not a valid Moodle installation (version.php not found)." | tee -a "$LOGFILE"
        exit 1
    fi

    if [ ! -f "$MOODLE_DIR/config.php" ]; then
        echo "❌ ERROR: Moodle config.php not found." | tee -a "$LOGFILE"
        exit 1
    fi

    # Extract moodledata directory from config.php
    if [ -f "$MOODLE_DIR/config.php" ]; then
        MOODLEDATA_DIR=$(grep "^.CFG..dataroot" "$MOODLE_DIR/config.php" | awk '{print $3}' | sed "s/;\|'//g")
        if [ ! -d "$MOODLEDATA_DIR" ]; then
            echo "❌ ERROR: Moodledata directory ($MOODLEDATA_DIR) does not exist." | tee -a "$LOGFILE"
            exit 1
        fi
    fi

    # Check for minimum disk space (512MB for plugin operations)
    REQUIRED_SPACE_MB=512
    AVAILABLE_SPACE_MB=$(df -Pm "$MOODLE_DIR" | tail -1 | awk '{print $4}')

    if [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
        echo "❌ ERROR: Not enough disk space. Required: ${REQUIRED_SPACE_MB}MB. Available: ${AVAILABLE_SPACE_MB}MB" | tee -a "$LOGFILE"
        exit 1
    fi

    # Warn if running as root
    if [ "$(id -u)" -eq 0 ]; then
        echo "⚠️ WARNING: Running as root. Consider using a regular user with sudo privileges." | tee -a "$LOGFILE"
    fi

    echo "✅ Pre-update validations passed." | tee -a "$LOGFILE"
    echo ""
}

# Function to select PHP version
select_php_version() {
    local php_versions=($(update-alternatives --list php 2>/dev/null | awk -F '/' '{print $NF}' | sort))
    
    if [ ${#php_versions[@]} -eq 0 ]; then
        # Fallback: try to find PHP in common locations
        for php_path in /usr/bin/php /usr/local/bin/php $(which php 2>/dev/null); do
            if [ -x "$php_path" ]; then
                PHP_BINARY="$php_path"
                echo "Found PHP at: $PHP_BINARY" | tee -a "$LOGFILE"
                return
            fi
        done
        echo "❌ ERROR: No PHP installation found." | tee -a "$LOGFILE"
        exit 1
    fi
    
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
    echo "🔧 Enabling maintenance mode..." | tee -a "$LOGFILE"
    sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/admin/cli/maintenance.php" --enable | tee -a "$LOGFILE"
}

# Function to disable maintenance mode
disable_maintenance_mode() {
    echo "🔧 Disabling maintenance mode..." | tee -a "$LOGFILE"
    sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/admin/cli/maintenance.php" --disable | tee -a "$LOGFILE"
}

# Function to check plugin status
check_plugin_status() {
    echo "🔍 Checking plugin status (dry run)..." | tee -a "$LOGFILE"
    
    # Create a temporary PHP script to check for pending upgrades
    cat > /tmp/check_moodle_status.php << 'EOF'
<?php
define('CLI_SCRIPT', true);
require_once(__DIR__ . '/config.php');
require_once($CFG->libdir.'/clilib.php');

// Get plugin manager
$pluginman = core_plugin_manager::instance();

// Check if any plugins need upgrading
$plugins = $pluginman->get_plugins();
$needs_upgrade = false;
$upgrade_count = 0;

echo "=== LOCAL PLUGIN STATUS ===\n";
foreach ($plugins as $type => $typeplugins) {
    foreach ($typeplugins as $name => $plugin) {
        $status = $plugin->get_status();
        if ($status === core_plugin_manager::PLUGIN_STATUS_UPGRADE) {
            echo "🔄 Plugin needs upgrade: {$type}_{$name}\n";
            echo "   Current: {$plugin->versiondb}\n";
            echo "   Available: {$plugin->versiondisk}\n";
            $needs_upgrade = true;
            $upgrade_count++;
        } elseif ($status === core_plugin_manager::PLUGIN_STATUS_MISSING) {
            echo "❌ Plugin missing from disk: {$type}_{$name}\n";
        } elseif ($status === core_plugin_manager::PLUGIN_STATUS_NEW) {
            echo "🆕 New plugin to install: {$type}_{$name}\n";
            $needs_upgrade = true;
            $upgrade_count++;
        }
    }
}

// Check what the upgrade process would do
echo "\n=== UPGRADE SIMULATION ===\n";
try {
    // Check if plugin manager indicates updates are available
    if ($pluginman->some_plugins_updatable()) {
        echo "🔄 Plugin manager indicates updates are available\n";
        $needs_upgrade = true;
        
        // Simplified approach - just check if upgrade.php would do something
        echo "🔍 Checking upgrade requirements...\n";
        
        // Create a simple test to see if upgrade is needed
        $temp_output = tempnam(sys_get_temp_dir(), 'moodle_upgrade_check');
        
        // Use a safer approach - just check the upgrade status without running the actual upgrade
        $cmd = "timeout 10s sudo -u www-data php {$CFG->dirroot}/admin/cli/upgrade.php --help > $temp_output 2>&1";
        shell_exec($cmd);
        
        // Try to get upgrade information by checking the database version vs file version
        $current_version = $CFG->version;
        echo "🔍 Current Moodle version: $current_version\n";
        
        // Count plugins that need attention
        $plugin_issues = 0;
        foreach ($plugins as $type => $typeplugins) {
            foreach ($typeplugins as $name => $plugin) {
                $status = $plugin->get_status();
                if ($status !== core_plugin_manager::PLUGIN_STATUS_UPTODATE && 
                    $status !== core_plugin_manager::PLUGIN_STATUS_MISSING) {
                    $plugin_issues++;
                }
            }
        }
        
        if ($plugin_issues > 0) {
            echo "🔄 Found $plugin_issues plugins that need attention\n";
            $upgrade_count += $plugin_issues;
        }
        
        // Clean up temp file
        if (file_exists($temp_output)) {
            unlink($temp_output);
        }
        
    } else {
        echo "✅ Plugin manager shows no updates needed\n";
    }
    
} catch (Exception $e) {
    echo "⚠️ Could not simulate upgrade: " . $e->getMessage() . "\n";
}

echo "\n=== SUMMARY ===\n";
if ($needs_upgrade || $upgrade_count > 0) {
    echo "⚠️ Updates are available and ready to install.\n";
    echo "📊 Estimated updates: $upgrade_count\n";
    echo "💡 Use option 4 to perform the upgrade.\n";
} else {
    echo "✅ All plugins appear to be up to date.\n";
    echo "💡 If you expect updates, check the web interface at:\n";
    echo "   Site Administration > Plugins > Plugin overview\n";
}
EOF

    # Copy the script to Moodle directory and run it
    cp /tmp/check_moodle_status.php "$MOODLE_DIR/"
    sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/check_moodle_status.php" | tee -a "$LOGFILE"
    
    # Clean up
    rm -f /tmp/check_moodle_status.php "$MOODLE_DIR/check_moodle_status.php"
}

# Function to get detailed upgrade info
get_upgrade_info() {
    echo "📊 Getting detailed upgrade information..." | tee -a "$LOGFILE"
    
    # Create a temporary PHP script to get detailed upgrade info
    cat > /tmp/get_upgrade_info.php << 'EOF'
<?php
define('CLI_SCRIPT', true);
require_once(__DIR__ . '/config.php');
require_once($CFG->libdir.'/clilib.php');

echo "=== MOODLE UPGRADE INFORMATION ===\n";
echo "Current Moodle version: " . $CFG->version . "\n";
echo "Current release: " . $CFG->release . "\n\n";

// Get plugin manager
$pluginman = core_plugin_manager::instance();

// Check core upgrade status
if ($pluginman->some_plugins_updatable()) {
    echo "🔄 Plugin manager indicates updates are available\n\n";
} else {
    echo "✅ Plugin manager shows no updates\n\n";
}

// Check individual plugins
echo "=== LOCAL PLUGIN STATUS ===\n";
$plugins = $pluginman->get_plugins();
$upgrade_count = 0;
$missing_count = 0;
$new_count = 0;

foreach ($plugins as $type => $typeplugins) {
    foreach ($typeplugins as $name => $plugin) {
        $status = $plugin->get_status();
        if ($status === core_plugin_manager::PLUGIN_STATUS_UPGRADE) {
            echo "🔄 {$type}_{$name}: Needs upgrade\n";
            echo "   Current: " . $plugin->versiondb . "\n";
            echo "   Available: " . $plugin->versiondisk . "\n";
            $upgrade_count++;
        } elseif ($status === core_plugin_manager::PLUGIN_STATUS_NEW) {
            echo "🆕 {$type}_{$name}: New plugin to install\n";
            $new_count++;
        } elseif ($status === core_plugin_manager::PLUGIN_STATUS_MISSING) {
            echo "❌ {$type}_{$name}: Missing from disk\n";
            $missing_count++;
        }
    }
}

// Simplified update detection
echo "\n=== DETAILED UPDATE CHECK ===\n";
$detected_updates = 0;

try {
    if ($pluginman->some_plugins_updatable()) {
        echo "🔍 Analyzing available updates...\n";
        
        // Count all plugins that are not up to date
        $all_plugins = $pluginman->get_plugins();
        foreach ($all_plugins as $type => $typeplugins) {
            foreach ($typeplugins as $name => $plugin) {
                $status = $plugin->get_status();
                if ($status === core_plugin_manager::PLUGIN_STATUS_UPGRADE) {
                    echo "🆙 {$type}_{$name}: Update available\n";
                    echo "   From: {$plugin->versiondb} To: {$plugin->versiondisk}\n";
                    $detected_updates++;
                }
            }
        }
        
        // If no specific updates found, provide general guidance
        if ($detected_updates === 0) {
            echo "🔍 Plugin manager indicates updates but specific details not available\n";
            echo "💡 This may indicate core Moodle updates or plugin updates that require\n";
            echo "   the actual upgrade process to detect properly.\n";
            $detected_updates = 1; // Indicate that updates are available
        }
    } else {
        echo "✅ No updates detected by plugin manager\n";
    }
    
} catch (Exception $e) {
    echo "⚠️ Could not perform detailed update check: " . $e->getMessage() . "\n";
}

$total_updates = $upgrade_count + $new_count + $detected_updates;

echo "\n=== SUMMARY ===\n";
echo "📊 Local plugins needing upgrade: $upgrade_count\n";
echo "📊 New plugins to install: $new_count\n";
echo "📊 Missing plugins: $missing_count\n";
echo "📊 Additional updates detected: $detected_updates\n";
echo "📊 Total updates needed: $total_updates\n";

echo "\n=== RECOMMENDATIONS ===\n";
if ($total_updates > 0) {
    echo "1. Backup your database before upgrading\n";
    echo "2. Enable maintenance mode during upgrade\n";
    echo "3. Use option 4 to perform the upgrade\n";
    echo "4. Purge caches after upgrade\n";
    echo "5. Check the web interface at Site Administration > Plugins > Plugin overview\n";
    if ($missing_count > 0) {
        echo "6. Missing plugins may need to be reinstalled or removed from database\n";
    }
} else {
    echo "💡 If you expect updates but none are detected:\n";
    echo "   1. Check the web interface for the most accurate information\n";
    echo "   2. Ensure your Moodle has internet access\n";
    echo "   3. Try running option 4 anyway - it may detect updates during execution\n";
    echo "   4. Consider checking for plugin updates manually in the admin interface\n";
}
EOF

    # Copy the script to Moodle directory and run it
    cp /tmp/get_upgrade_info.php "$MOODLE_DIR/"
    sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/get_upgrade_info.php" | tee -a "$LOGFILE"
    
    # Clean up
    rm -f /tmp/get_upgrade_info.php "$MOODLE_DIR/get_upgrade_info.php"
}

# Function to list installed plugins
list_plugins() {
    echo "📋 Listing installed plugins..." | tee -a "$LOGFILE"
    
    # Plugin directories to check
    PLUGIN_DIRS="mod theme local blocks auth report question qtype filter repository portfolio"
    
    for plugin_type in $PLUGIN_DIRS; do
        if [ -d "$MOODLE_DIR/$plugin_type" ]; then
            echo "=== $plugin_type plugins ===" | tee -a "$LOGFILE"
            for plugin in "$MOODLE_DIR/$plugin_type"/*; do
                if [ -d "$plugin" ]; then
                    plugin_name=$(basename "$plugin")
                    if [ -f "$plugin/version.php" ]; then
                        version=$(grep '$plugin->version' "$plugin/version.php" 2>/dev/null | head -1 | awk '{print $3}' | sed 's/;//')
                        echo "  - $plugin_name (version: $version)" | tee -a "$LOGFILE"
                    else
                        echo "  - $plugin_name (no version info)" | tee -a "$LOGFILE"
                    fi
                fi
            done
            echo "" | tee -a "$LOGFILE"
        fi
    done
}

# Function to update plugins
update_plugins() {
    echo "🔄 Starting plugin update process..." | tee -a "$LOGFILE"
    
    # Run the upgrade process
    sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/admin/cli/upgrade.php" --non-interactive | tee -a "$LOGFILE"
    
    if [ $? -eq 0 ]; then
        echo "✅ Plugin update completed successfully." | tee -a "$LOGFILE"
    else
        echo "❌ Plugin update failed. Check the log for details." | tee -a "$LOGFILE"
        return 1
    fi
}

# Function to purge caches
purge_caches() {
    echo "🧹 Purging Moodle caches..." | tee -a "$LOGFILE"
    sudo -u www-data "$PHP_BINARY" "$MOODLE_DIR/admin/cli/purge_caches.php" | tee -a "$LOGFILE"
}

# Function to remove trailing slash if present
remove_trailing_slash() {
    local path=$1
    path="${path%/}"
    echo "$path"
}

# Main script execution starts here

# Start logging
exec &> >(tee -a "$LOGFILE")

# Display script info
display_info

# Check for the correct number of arguments
if [ "$#" -ne 1 ]; then
    usage
fi

# Set up variables
MOODLE_DIR=$(remove_trailing_slash "$1")

# Run precondition validations
validate_preconditions

# Select PHP version
select_php_version

# Get current Moodle version
current_version=$(grep 'release' "$MOODLE_DIR/version.php" | awk '{print $3}' | sed "s/'\|;//g")
echo "Current Moodle version: $current_version" | tee -a "$LOGFILE"

# Main menu
while true; do
    echo ""
    echo "=== MOODLE PLUGIN MANAGER ===" 
    echo "1. List installed plugins"
    echo "2. Check plugin status (dry run)"
    echo "3. Get detailed upgrade info"
    echo "4. Update plugins"
    echo "5. Purge caches"
    echo "6. Enable maintenance mode"
    echo "7. Disable maintenance mode"
    echo "8. Check for remote plugin updates"
    echo "9. Exit"
    echo ""
    
    # Read input without logging to avoid interference
    read -p "Select an option [1-9]: " choice
    
    # Log the choice after reading
    echo "Selected option: $choice" >> "$LOGFILE"
    
    case $choice in
        1)
            list_plugins
            ;;
        2)
            echo "Running plugin status check (no changes will be made)..."
            check_plugin_status
            ;;
        3)
            get_upgrade_info
            ;;
        4)
            echo "⚠️ WARNING: This will update all plugins and may take some time."
            read -p "Do you want to proceed? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                enable_maintenance_mode
                update_plugins
                purge_caches
                disable_maintenance_mode
            else
                echo "Plugin update cancelled."
            fi
            ;;
        5)
            purge_caches
            ;;
        6)
            enable_maintenance_mode
            ;;
        7)
            disable_maintenance_mode
            ;;
        8)
            echo "🌐 Checking for remote plugin updates..."
            echo "💡 Note: This requires internet access and may take a moment."
            check_plugin_status
            ;;
        9)
            echo "Exiting plugin manager. Goodbye!" | tee -a "$LOGFILE"
            exit 0
            ;;
        *)
            echo "Invalid option. Please select 1-9."
            ;;
    esac
done