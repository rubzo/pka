#!/bin/bash

function sanity_check {
	if [ "`which apktool`" == "" ]; then
		echo "You don't have apktool installed!"
		exit 1
	fi
	if [ "`which keytool`" == "" ]; then
		echo "You don't have keytool installed - install the Android SDK!"
		exit 1
	fi
	echo "(Making sure adb root is running...)"
	adb root > /dev/null
}

function not_ready {
	echo "Command not ready yet."
	exit 1
}

function makekeystore {
	keytool -genkey -v -keystore ${PKA_HOME}/pka.keystore -alias pka_alias -keyalg RSA -keysize 2048 -validity 10000
	echo "Generated keystore."
}

function extract {
	if [ "$1" == "" ]; then
		echo "You need to provide an .apk name to extract!"
		exit 1
	fi

	if [ "`ls *.apk 2> /dev/null`" != "" ]; then
		echo "You've already extracted an APK here, use clean to get rid of it!"
		exit 1
	fi

	APK=`adb shell ls /data/app/ | grep $1 | dos2unix`

	adb pull /data/app/$APK

	apktool d $APK apk_contents

	mkdir original_backup

	cp -R apk_contents *.apk original_backup

	echo "APK extracted."
}

function install {
	if [ ! -e ${PKA_HOME}/pka.keystore ]; then 
		echo "You need to create a keystore before you install anything! Use pka makekeystore!"
		exit 1
	fi
	if [ ! -d apk_contents ]; then 
		echo "You need to have extracted an APK here first before you can reinstall it! Use pka extract <name>!"
		exit 1
	fi

	APK=`ls | grep *.apk`

	apktool b apk_contents $APK

	if [ $? -ne 0 ]; then
		echo "apktool had some trouble repackaging your APK - you've corrupted the smali files somehow?"
		exit 1
	fi

	jarsigner -verbose -sigalg MD5withRSA -digestalg SHA1 -keystore ${PKA_HOME}/pka.keystore $APK pka_alias

	NAME=`echo $APK | sed 's/-.*.apk//'`

	echo "Attempting to uninstall APK first... (will say Failure if not present already)"
	adb uninstall $NAME

	adb install $APK

	echo "APK installed."
}

function modinstall {
	if [ ! -e ${PKA_HOME}/pka.keystore ]; then 
		echo "You need to create a keystore before you install anything! Use pka makekeystore!"
		exit 1
	fi
	if [ ! -d apk_contents ]; then 
		echo "You need to have extracted an APK here first before you can reinstall it! Use pka extract <name>!"
		exit 1
	fi

	APK=`ls | grep *.apk`

	cd apk_contents

	smali -o classes.dex smali

	cd ..

	unzip -d other_apk_contents $APK

	rm -rf other_apk_contents/META-INF/*

	cp apk_contents/classes.dex other_apk_contents/

	cd other_apk_contents

	zip -r ../new_$APK *

	cd ..

	jarsigner -verbose -sigalg MD5withRSA -digestalg SHA1 -keystore ${PKA_HOME}/pka.keystore new_$APK pka_alias

	NAME=`echo $APK | sed 's/-.*.apk//'`

	echo "Attempting to uninstall APK first... (will say Failure if not present already)"
	adb uninstall $NAME

	adb install new_$APK

	echo "APK installed."
}

function get_mprof {
	adb pull /sdcard/AutoProfile.trace .
	echo "Retrieved AutoProfile.trace."
}

function read_mprof {
	traceview AutoProfile.trace
}

function reset {
	cp -R original_backup/* .
	echo "Reset APK contents to original state."
}

function backup {
	if [ "$1" == "" ]; then
		echo "You need to provide a name to back up to!"
		exit 1
	fi

	mkdir backup_$1

	cp -R apk_contents *.apk backup_$1

	echo "Backed up to backup_$1."
}

function restore {
	if [ "$1" == "" ]; then
		echo "You need to provide a name to back up to!"
		exit 1
	fi

	if [ ! -d backup_$1 ]; then
		echo "$1 is not the name of a backup!"
		exit 1
	fi

	cp -R backup_$1/* .
	echo "Restored from backup_$1."
}

function clean {
	rm -rf *apk_contents
	rm *.apk
	rm -f AutoProfile.trace
	echo "Cleaned up."
}

function cleanbackups {
	rm -rf *backup*
	echo "Cleaned up all backups."
}