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
#   - Original version
#
# Version 0.0.2, 13-Mar-2023, Dan K. Snelson (@dan-snelson)
#   - Prepend Serial Number on output file
#
# Version 0.0.3, 14-Mar-2023, Dan K. Snelson (@dan-snelson)
#   - Modified `find` command (thanks, @Samantha Demi and @Pico)
#
# Version 0.0.4, 09-Sep-2023, Dan K. Snelson (@dan-snelson)
#   - Updated `dialogURL`
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.4"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
falconBinary="/Applications/Falcon.app/Contents/Resources/falconctl"
osVersion=$( /usr/bin/sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $1}' )
dialogBinary="/usr/local/bin/dialog"
dialogCommandLog=$( mktemp /var/tmp/dialogCommandLog.XXX )
serialNumber=$( system_profiler SPHardwareDataType | grep "Serial Number" | awk -F ": " '{ print $2 }' )
scriptLog="${4:-"/var/tmp/com.company.log"}"    # Parameter 4: Full path to your company's client-side log
estimatedTotalSeconds="${5:-"333"}"             # Parameter 5: Estimated number of seconds to complete diagnose



####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\n###\n# CrowdStrike Falcon diagnose with Progress (${scriptVersion})\n###\n"
updateScriptLog "PRE-FLIGHT CHECK: Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    updateScriptLog "PRE-FLIGHT CHECK: This script must be run as root; exiting."
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    updateScriptLog "PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; proceeding …"
else
    updateScriptLog "PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; exiting."
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm CrowdStrike Falcon is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -f "${falconBinary}" ]]; then
    updateScriptLog "PRE-FLIGHT CHECK: CrowdStrike Falcon installed; proceeding …"
else
    updateScriptLog "PRE-FLIGHT CHECK: CrowdStrike Falcon NOT found; exiting."
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm Apple's sysdiagnose directory is empty / Delete any previous diagnose files
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -d "/private/var/db/sysdiagnose/" ]]; then
    updateScriptLog "PRE-FLIGHT CHECK: sysdiagnose directory found; deleting …"
    rm -Rf /private/var/db/sysdiagnose/
    rm /private/tmp/falconctl_diagnose_*
    rm /Users/Shared/"${serialNumber}_"*
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Check for / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        updateScriptLog "PRE-FLIGHT CHECK: Dialog not found. Installing..."

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
            updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} installed; proceeding..."

        else

            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
            quitScript "1"

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version $( /usr/local/bin/dialog --version) found; proceeding..."

    fi

}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    dialogCheck
else
    updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version $(dialog --version) found; proceeding..."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Checks Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "PRE-FLIGHT CHECK: Complete"



####################################################################################################
#
# Functions
#
####################################################################################################

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

    updateScriptLog "QUIT SCRIPT: Exiting …"
    updateDialog "quit:"

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

title="CrowdStrike Falcon Diagnose (${scriptVersion})"
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
# Update results in diagnose progress
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "QUIT SCRIPT: Diagnose Sucessful"
updateDialog "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
updateDialog "message: CrowdStrike Falcon Diagnose Complete"
updateDialog "progress: 100"
updateDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
updateScriptLog "Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
sleep 5



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Wait for 'falconctl_diagnose_' directory to be removed
# See: https://macadmins.slack.com/archives/C07MGJ2SD/p1678735637841009
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Wait for 'falconctl_diagnose_' directory to be removed from /private/tmp/ …"
updateDialog "icon: SF=deskclock.fill,weight=bold,colour1=#0066ff,colour2=#003380"
updateDialog "message: Waiting for file output …"
updateDialog "progresstext: Please wait …"
updateDialog "progress: reset"

until [[ -z "$( find /private/tmp -name "falconctl_diagnose_*" -type d )" ]]; do

    updateScriptLog "Pausing for one second before re-checking …"
    updateDialog "progress: increment 6"
    sleep 1

done

updateDialog "progress: 100"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Prepend output with Serial Number
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

originalFilename=$( find /private/tmp -name "falconctl_diagnose_*" -type f -print0 | xargs basename )
updateScriptLog "Original Filename: ${originalFilename}"

updateScriptLog "Move ${originalFilename} to /User/Shared/ …"
mv -v "/private/tmp/${originalFilename}" "/Users/Shared/${serialNumber}_${originalFilename}"

updateScriptLog "Reveal /User/Shared/${serialNumber}_${originalFilename}"
open -R "/Users/Shared/${serialNumber}_${originalFilename}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "0"