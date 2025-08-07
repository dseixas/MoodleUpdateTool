# MoodleUpdateTool

A comprehensive collection of scripts to simplify Moodle updates and plugin management. These tools automate many of the manual steps required for Moodle maintenance, making the process faster, safer, and more reliable.

## 📋 Overview

MoodleUpdateTool provides three main scripts for different Moodle maintenance tasks:

1. **`update-moodle-from-zip.sh`** - Update Moodle from a ZIP archive (Recommended)
2. **`update-moodle.sh`** - Update Moodle from extracted directories
3. **`update-moodle-plugins.sh`** - Manage and update Moodle plugins

These scripts automate several steps defined in the [official Moodle upgrade documentation](https://docs.moodle.org/en/Upgrading).

## 🚀 Features

### Common Features (All Scripts)
- ✅ **Safety First**: Automatic maintenance mode management
- ✅ **Backup Support**: Database and file backup options
- ✅ **Error Handling**: Comprehensive error checking and rollback capabilities
- ✅ **Logging**: Detailed timestamped logs for troubleshooting
- ✅ **Permission Management**: Automatic file permission fixes
- ✅ **PHP Version Selection**: Automatic detection or manual selection
- ✅ **Validation**: Pre-flight checks for disk space, dependencies, and file integrity

### Script-Specific Features

#### `update-moodle-from-zip.sh` (v1.0) - **RECOMMENDED**
- 🔄 **Direct ZIP Processing**: No need to manually extract archives
- 📦 **Smart Plugin Preservation**: Automatically preserves custom plugins
- 🛡️ **Enhanced Safety**: ZIP structure validation and rollback mechanisms
- 🔧 **Automatic Configuration**: Preserves settings and applies safe defaults
- 📊 **Progress Tracking**: Real-time progress updates with emoji indicators

#### `update-moodle-plugins.sh` (v1.1)
- 🔍 **Plugin Status Checking**: Dry-run mode to check what needs updating
- 📈 **Detailed Upgrade Info**: Comprehensive analysis of available updates
- 🎯 **Selective Updates**: Choose which plugins to update
- 🧹 **Cache Management**: Automatic cache purging after updates
- 🌐 **Remote Update Detection**: Check for plugin updates from repositories

#### `update-moodle.sh` (Legacy)
- 📁 **Directory-based Updates**: Works with pre-extracted Moodle directories
- 🔄 **Plugin Migration**: Copies custom plugins between installations

## 📖 Usage

### Method 1: Update from ZIP (Recommended)

```bash
./update-moodle-from-zip.sh /path/to/current/moodle /path/to/moodle-4.3.zip
```

**Example:**
```bash
./update-moodle-from-zip.sh /var/www/html/moodle ~/Downloads/moodle-4.3.2.zip
```

### Method 2: Plugin Management

```bash
./update-moodle-plugins.sh /path/to/moodle
```

**Example:**
```bash
./update-moodle-plugins.sh /var/www/html/moodle
```

### Method 3: Directory-based Update (Legacy)

```bash
./update-moodle.sh /path/to/current/moodle /path/to/new/moodle
```

## 🛠️ System Requirements

### Required Software
- **Bash** 4.0+ (macOS/Linux)
- **PHP** 7.4+ with CLI access
- **MySQL/MariaDB** with mysqldump
- **unzip** utility
- **sudo** access for www-data user

### Required Permissions
- Read/write access to Moodle directory
- Sudo access for www-data operations
- Database access for backups (optional)

### Disk Space
- Minimum 2GB free space (for ZIP method)
- Minimum 1GB free space (for other methods)

## 📋 Pre-Update Checklist

### Essential Steps
1. **🔍 Compatibility Check**: Visit `https://yourmoodle.com/admin/environment.php`
2. **📦 Backup Everything**: Database, files, and configuration
3. **🔌 Update Plugins**: Update all plugins to latest compatible versions
4. **🧪 Test Environment**: Test the update in a staging environment first
5. **📊 Check Disk Space**: Ensure sufficient free space
6. **👥 Notify Users**: Inform users about planned maintenance

### Recommended Pre-Update Commands
```bash
# Check current Moodle version
grep '$release' /path/to/moodle/version.php

# Check disk space
df -h /path/to/moodle

# Verify PHP version
php -v

# Test database connection
mysql -u moodleuser -p moodledb -e "SELECT 1;"
```

## 🎯 Step-by-Step Update Guide

### Using update-moodle-from-zip.sh (Recommended)

1. **Download Moodle ZIP**
   ```bash
   wget https://download.moodle.org/download.php/direct/stable43/moodle-4.3.2.tgz
   ```

2. **Run the Update Script**
   ```bash
   ./update-moodle-from-zip.sh /var/www/html/moodle moodle-4.3.2.zip
   ```

3. **Follow Interactive Prompts**
   - Confirm update proceeding
   - Choose database backup option
   - Confirm installation replacement
   - Choose to run upgrade immediately

4. **Verify Update**
   - Check Moodle admin interface
   - Verify all plugins are working
   - Test critical functionality

### Using update-moodle-plugins.sh

1. **Check Plugin Status**
   ```bash
   ./update-moodle-plugins.sh /var/www/html/moodle
   # Select option 2: Check plugin status (dry run)
   ```

2. **Get Detailed Information**
   ```bash
   # Select option 3: Get detailed upgrade info
   ```

3. **Update Plugins**
   ```bash
   # Select option 4: Update plugins
   ```

## 🔧 Configuration Options

### Environment Variables
```bash
# Custom log file location
export LOGFILE="/var/log/moodle_update.log"

# Custom PHP binary
export PHP_BINARY="/usr/bin/php8.1"

# Custom backup directory
export BACKUP_DIR="/backups/moodle"
```

### Script Customization
You can modify the following variables in the scripts:

- `REQUIRED_SPACE_MB`: Minimum disk space requirement
- `PLUGIN_DIRS`: Additional plugin directories to process
- `BACKUP_RETENTION`: Number of backups to keep

## 📊 Menu Options (update-moodle-plugins.sh)

| Option | Description | Safe Mode |
|--------|-------------|-----------|
| 1 | List installed plugins | ✅ Read-only |
| 2 | Check plugin status (dry run) | ✅ Read-only |
| 3 | Get detailed upgrade info | ✅ Read-only |
| 4 | Update plugins | ⚠️ Modifies system |
| 5 | Purge caches | ⚠️ Modifies system |
| 6 | Enable maintenance mode | ⚠️ Affects users |
| 7 | Disable maintenance mode | ✅ Restores access |
| 8 | Check for remote plugin updates | ✅ Read-only |
| 9 | Exit | ✅ Safe |

## 🚨 Troubleshooting

### Common Issues and Solutions

#### "kill: No such process" Error
**Fixed in v1.1** - This error occurred when the script tried to kill processes that had already finished.

#### "Invalid option" Menu Error
**Fixed in v1.1** - Improved input handling to prevent logging interference.

#### Permission Denied Errors
```bash
# Fix ownership
sudo chown -R www-data:www-data /path/to/moodle

# Fix permissions
sudo chmod -R 755 /path/to/moodle
```

#### Database Connection Issues
```bash
# Test database connection
mysql -u root -p -e "SHOW DATABASES;"

# Check Moodle config
grep -E "(dbhost|dbname|dbuser)" /path/to/moodle/config.php
```

#### Insufficient Disk Space
```bash
# Check available space
df -h /path/to/moodle

# Clean up old backups
find /path/to/backups -name "moodle_backup_*" -mtime +30 -delete
```

### Log File Analysis
```bash
# View recent errors
tail -f moodle_update_*.log | grep ERROR

# Search for specific issues
grep -i "failed\|error\|warning" moodle_update_*.log
```

## 🔄 Version History

### v1.1 (Latest)
- **Fixed**: "kill: No such process" error in plugin status checking
- **Fixed**: Menu input handling issues
- **Improved**: Error handling and logging
- **Enhanced**: Plugin update detection accuracy
- **Added**: Better progress reporting

### v1.0
- **Added**: ZIP file structure validation
- **Added**: Automatic rollback capabilities
- **Added**: Timestamped backups and logs
- **Added**: Comprehensive error checking
- **Improved**: Database backup with credential extraction
- **Enhanced**: User experience with better prompts

### v0.1 (Legacy)
- Initial release with basic functionality
- Manual extraction required
- Limited error handling

## 🛡️ Security Considerations

### File Permissions
- Scripts set appropriate ownership (root:root for core, www-data:www-data for plugins)
- Maintains secure file permissions (755 for directories, 644 for files)

### Database Security
- Attempts to use existing Moodle credentials before prompting for root
- Backup files are created with restricted permissions
- No passwords are logged or stored

### Backup Security
- Timestamped backups prevent accidental overwrites
- Automatic cleanup of temporary files
- Rollback capabilities in case of failure

## 🌍 Compatibility

### Tested Platforms
- ✅ **Ubuntu** 18.04, 20.04, 22.04
- ✅ **CentOS** 7, 8
- ✅ **macOS** 10.15+ (with Homebrew)
- ✅ **Debian** 10, 11

### Moodle Versions
- ✅ **Moodle 3.9+** (LTS)
- ✅ **Moodle 4.0+** (Current)
- ✅ **Moodle 4.1+** (Latest)

### Language Support
- ✅ **English** (EN) - Fully supported
- ✅ **Spanish** (ES) - Fully supported
- ⚠️ **Other languages** - May require minor adjustments

## 🤝 Contributing

### Reporting Issues
1. Check existing issues in the repository
2. Provide detailed error logs
3. Include system information (OS, PHP version, Moodle version)
4. Describe steps to reproduce

### Feature Requests
- Plugin-specific update management
- Integration with Git repositories
- Web-based interface
- Automated scheduling

## ⚠️ Important Notes

### What These Scripts DO
- ✅ Automate Moodle core updates
- ✅ Preserve custom plugins and themes
- ✅ Handle database and file backups
- ✅ Manage maintenance mode
- ✅ Fix file permissions
- ✅ Provide detailed logging

### What These Scripts DON'T DO
- ❌ Update PHP or system packages
- ❌ Update plugin code (only detect updates)
- ❌ Modify database schema (Moodle handles this)
- ❌ Update web server configuration
- ❌ Handle SSL certificates

### Best Practices
1. **Always test in staging first**
2. **Keep multiple backups**
3. **Monitor disk space**
4. **Update during low-traffic periods**
5. **Have a rollback plan**
6. **Keep logs for troubleshooting**

## 📞 Support

### Getting Help
1. **Check the logs** - Most issues are documented in the log files
2. **Review this README** - Common solutions are documented here
3. **Test in staging** - Reproduce issues in a safe environment
4. **Check Moodle forums** - Community support for Moodle-specific issues

### Emergency Procedures
If an update fails:
1. **Don't panic** - Backups are created automatically
2. **Check maintenance mode** - Disable if needed: `php admin/cli/maintenance.php --disable`
3. **Restore from backup** - Use the timestamped backup directories
4. **Check logs** - Review error messages for specific issues
5. **Seek help** - Contact your system administrator or Moodle community

## 📄 License

This project is licensed under the terms specified in the LICENSE file.

## ☕ Support the Project

If these scripts save you time and effort, consider buying the author a coffee! Your support helps maintain and improve these tools.

---

**⚠️ DISCLAIMER**: Use these scripts at your own risk. Always backup your data before running any update procedures. The authors provide no warranty and are not responsible for any data loss or system damage.

**📝 Last Updated**: December 2024
**🔖 Version**: 1.1
**👨‍💻 Author**: Daniel Seixas
