#!/bin/bash


echo "###############################################"
echo "# MOODLE AutoUpdater by Daniel Seixas         #"
echo "# Version 0.5                                 #"
echo "# Use at your own risk                        #"
echo "###############################################"


echo "Current moodle version: $(cat $1/version.php|grep '(Build: '|awk '{print $3 $4 $5}'|sed 's/;\|\///g')"
echo "New moodle version: $(cat $2/version.php|grep '(Build: '|awk '{print $3 $4 $5}'|sed 's/;\|\///g')" 

echo "BEFORE proceeding you need to:"
echo "1. Activate moodle maintenance mode"
echo "2. Backup the DB"
echo "3. moodledata Backup (located in $(cat $1/config.php |grep dataroot|awk '{print $3}'|sed "s/;\|'//g"))"
echo "4. Downloaded and unziped latest moodle (Second parameter)"


if [ "$#" -ne 2 ]; then
    echo "ERROR: USAGE update-moodle current-moodle-dir new-moodle-dir"
    exit 2
fi

if [ ! -d $1 ]; then
    echo "ERROR:Current moodle dir does NOT Exist"
    exit 1
fi 

if [ ! -d $2 ]; then
    echo "ERROR: New moodle verssion dir does NOT Exist"
    exit 1
fi 

read -p "Do you want to proceed(sSyYnN) [Default=N]? " -n 1 -r 
echo
if [[ $REPLY =~ ^[YySs]$ ]]; then 
    # do dangerous stuff 

#TODO: Backup moodledata

    read -p "Do you want to do a Database backup (dump) (you need root access) [yYNn (Default=n)]? " -n 1 -r 
    echo 
    if [[ $REPLY =~ ^[YySs]$ ]]; then 
         mysqldump -u root -p $(cat $1/config.php |grep dbname|awk '{print $3}'|sed "s/'\|;//g")>moodle_bck.sql
    fi

    FOLDERS="mod theme local blocks auth report"
    for folder in $FOLDERS
    do
        echo "Procesando directorio:" $folder
        
        for value in $(diff -q $1/$folder $2/$folder  |  grep -e "^Only in*" -e "^Sólo en*" | sed -n 's/[^:]*: //p') 
        do
            echo "Comando: cp -pr $1/$folder/$value $2/$folder/$value"
            cp -pr $1/$folder/$value $2/$folder/$value
            #ls html/mod/$value
        done
    done
    
    echo "Copiando configuración"
    cp -pvr $1/config.php $2/config.php
    
    echo "Actualizar permisos"
    chown -R root:root $2
    chown -R www-data:www-data $2/mod $2/theme $2/local $2/auth 
    chmod -R 755 $2

    echo "Actualizacion completada. Recuerda los sigueintes pasos"
    echo "1. Mueve el directorio $2 a dónde esté configurado el Apache"
    echo "2. Conectate al moodle para finalizar la actualizacion"
    echo "Nota: ppara desactivar en linea de comandos el moodo mantenimiento: php admin/cli/maintenance.php --disable"


fi
