#!/bin/bash

####################################################################################################
#
#   CrowdStrike Falcon diagnose with Progress
#
#   Purpose: Provide more detailed feedback on CrowdStrike Falcon's built-in diagnose command
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 06-Feb-2023, Dan K. Snelson (@dan-snelson)
#   Original version
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.1"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
falconBinary="/Applications/Falcon.app/Contents/Resources/falconctl"
osVersion=$( /usr/bin/sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $1}' )
dialogBinary="/usr/local/bin/dialog"
dialogCommandLog=$( mktemp /var/tmp/dialogCommandLog.XXX )
timestamp=$( date +%Y-%m-%d\ %H:%M:%S )
scriptLog="${4:-"/var/tmp/com.company.log"}"    # Parameter 4: Full path to your company's client-side log
estimatedTotalSeconds="${5:-"252"}"             # Parameter 5: Estimated number of seconds to complete diagnose



####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
    echo "${timestamp} - PRE-FLIGHT CHECK: Created log file via script" | tee -a "${scriptLog}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Initiate Pre-flight Checks
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo -e "\n###\n# CrowdStrike Falcon diagnose with Progress (${scriptVersion})\n###\n" | tee -a "${scriptLog}"
echo "${timestamp} - PRE-FLIGHT CHECK: Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    echo "${timestamp} - PRE-FLIGHT CHECK: This script must be run as root; exiting." | tee -a "${scriptLog}"
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    echo "${timestamp} - PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; proceeding …"
else
    echo "${timestamp} - PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; exiting."
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm CrowdStrike Falcon is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -f "${falconBinary}" ]]; then
    echo "${timestamp} - PRE-FLIGHT CHECK: CrowdStrike Falcon installed; proceeding …" | tee -a "${scriptLog}"
else
    echo "${timestamp} - PRE-FLIGHT CHECK: CrowdStrike Falcon NOT found; exiting." | tee -a "${scriptLog}"
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm Apple's sysdiagnose directory is empty / Delete any previous diagnose files
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -d "/private/var/db/sysdiagnose/" ]]; then
    echo "${timestamp} - PRE-FLIGHT CHECK: sysdiagnose directory found; deleting …" | tee -a "${scriptLog}"
    rm -Rf /private/var/db/sysdiagnose/
    rm /private/tmp/falconctl_diagnose_*
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        echo "${timestamp} - PRE-FLIGHT CHECK: Dialog not found. Installing..." | tee -a "${scriptLog}"

        # Create temporary working directory
        workDirectory=$( /usr/bin/basename "$0" )
        tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

        # Download the installer package
        /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

        # Verify the download
        teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

        # Install the package if Team ID validates
        if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

            /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
            sleep 2
            dialogVersion=$( /usr/local/bin/dialog --version )
            echo "${timestamp} - PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} installed; proceeding..." | tee -a "${scriptLog}"

        else

            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
            quitScript "1"

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        echo "${timestamp} - PRE-FLIGHT CHECK: swiftDialog version $(dialog --version) found; proceeding..." | tee -a "${scriptLog}"

    fi

}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    dialogCheck
else
    echo "${timestamp} - PRE-FLIGHT CHECK: swiftDialog version $(dialog --version) found; proceeding..." | tee -a "${scriptLog}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Checks Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "${timestamp} - PRE-FLIGHT CHECK: Complete" | tee -a "${scriptLog}"



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Script Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateDialog() {
    echo "${1}" >> "${dialogCommandLog}"
    sleep 0.4
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    if [[ "${1}" == "1" ]]; then

        updateScriptLog "QUIT SCRIPT: Diagnose Failure"
        failureMessage="Something went sideways."
        updateDialog "message: ${failureMessage}"
        sleep 5
        updateDialog "quit:"

    else

        updateScriptLog "QUIT SCRIPT: Diagnose Sucessful"
        updateDialog "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
        updateDialog "message: CrowdStrike Falcon Diagnose Complete"
        updateDialog "progress: 100"
        updateDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
        updateScriptLog "Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
        sleep 5
        updateDialog "quit:"

    fi

    updateScriptLog "QUIT SCRIPT: Exiting …"

    # Remove dialogCommandLog
    if [[ -e ${dialogCommandLog} ]]; then
        updateScriptLog "QUIT SCRIPT: Removing ${dialogCommandLog} …"
        rm "${dialogCommandLog}"
    fi

    # Remove any default dialog file
    if [[ -e /var/tmp/dialog.log ]]; then
        updateScriptLog "QUIT SCRIPT: Removing default dialog file …"
        rm /var/tmp/dialog.log
    fi

    exit "${1}"

}



####################################################################################################
#
# General Dialog Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="CrowdStrike Falcon Diagnose"
message="Please wait while a diagnosis is performed …"
icon="https://ics.services.jamfcloud.com/icon/hash_37bf84a34fb6d957fab0718cbf9dfea0a54562db2cd9ecfe8e16cdbe5a24197c"
# overlay=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
progressText="Initializing …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogFalconctlDiagnose="$dialogBinary \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--mini \
--position bottomright \
--moveable \
--progress \
--progresstext \"$progressText\" \
--quitkey K \
--commandfile \"$dialogCommandLog\" "

# --overlayicon \"$overlay\" \


####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# falconctl diagnose progress
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Progress Dialog …"
eval "$dialogFalconctlDiagnose" & sleep 0.5

updateScriptLog "Starting falconctl diagnose …"
SECONDS="0"
eval "$falconBinary diagnose" &
sleep 2

while [[ -n $(pgrep "sysdiagnose_helper") ]]; do

    progressPercentage=$( echo "scale=2 ; ( $SECONDS / $estimatedTotalSeconds ) * 100" | bc | sed 's/\.00//g' )
    updateDialog "progress: ${progressPercentage}"
    updateDialog "progresstext: ${progressPercentage}%"

done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "0"