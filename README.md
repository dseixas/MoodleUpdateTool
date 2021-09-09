# MoodleUpdateTool
Moodle update tool simplifies the update of the moodle version so it's simpler and faster to do. 

MoodleUpdateTool is a fairly simple script that updates moodle to a superior version selected by the user. 

This scripts automates several steps defined in https://docs.moodle.org/311/en/Upgrading

**NOTICE**

1. This script has been tested in ubuntu systems so far.
1. This script works in EN and ES hostings, other languages may need tinkering with it.

## WHAT THIS IS  FOR

This script will prepare the out-of-the-box-vanilla moodle version you download to inherit all your current moodle settings. Also will help you with the backups.

In terms of tasks, this is what MoodleUpdateTool does:
* Export database
* Zip moodledata (TBD)
* Copy config.php from current to new moodle
* Copy all plugins and extensions (Mod, blocks, local, admin, etc...)
* Fix permissions



## WHAT THIS IS NOT FOR

Not all the steps are automatically, for example, selecting, downloading and uncompressing the moodle version you want to upgrade to is part of the user responsability as is backing up database and moodledata. 

Nevertheless the scripts provides the user with options for this last two elements.

Last but not least, the script will not update PHP, plugins or libraries, you need to update them beforehand and make sure that you're able to update to the selected version. 



This can be checked at:
https://<yourmoodlesite.com>/admin/environment.php


## USAGE

./update-moodle.sh *current-moodle-dir* *new-moodle-dir*

# USER GUIDE

**Pre-update tasks**
  ===================
* Step 0: Backup everything!!!
* Step 1: Check that you can actually update your moodle to the selected version
* Step 2: Update all plugins and extensions that are available
  
**Update tasks**
  ==================
* Step 3: go to your moodle dir
* Step 4: Download and decompress the next moodle version to a folder of your choice. This will be *new-moodle-dir*
* Step 5: Annotate current moodle folder. This will be *current-moodle-dir*
* Step 6: run the scrpit: ./update-moodle.sh *current-moodle-dir* *new-moodle-dir*

**Post-update tasks**
  ===================
* Step 7: mv *current-moodle-dir* *current-moodle-dir.backup*
* Step 8: mv *new-moodle-dir* *current-moodle-dir*
* Step 9: Go to your moodle site and follow the update steps.
  
# FINAL WORD

Use it at your own risk. No warranty whatsoever.

Let's be honest, I did this because it saves me a ton of time. Just use it, and if you feel like, buy me a coffe ;).


