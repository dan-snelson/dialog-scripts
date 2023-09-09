#!/bin/bash

####################################################################################################
#
#   swiftDialog Inventory Update Progress
#   https://snelson.us/2022/10/inventory-update-progress/
#
#   Purpose: Provide more detailed feedback on Jamf Pro Self Service Inventory Update
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 13-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Original version
#
# Version 0.0.2, 14-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Added logic to simply update inventory for OSes too old for swiftDialog
#
# Version 0.0.3, 18-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Added "debug mode" for auditing Extension Attribute execution time
#
# Version 0.0.4, 20-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Modified `updateScriptLog` function to (hopefully) make parsing easier (thanks, @tlark!)
#   Corrected fat-fingered spelling of "Elasped"
#
# Version 0.0.5, 27-Dec-2022, Dan K. Snelson (@dan-snelson)
#   Provided alternate `recon` option to address Issue No. 24
#
# Version 0.0.6, 09-Sep-2023, Dan K. Snelson (@dan-snelson)
#   - Updated `dialogURL`
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.6"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
osVersion=$( /usr/bin/sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $1}' )
dialogApp="/usr/local/bin/dialog"
dialogLog=$( mktemp /var/tmp/dialogLog.XXX )
inventoryLog=$( mktemp /var/tmp/inventoryLog.XXX )
scriptLog="${4:-"/var/tmp/org.churchofjesuschrist.log"}"
estimatedTotalSeconds="${5:-"298"}"
debugMode="${6:-"false"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Inventory Update" Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Updating Inventory"
message="Please wait while inventory is updated …"
icon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
inventoryProgressText="Initializing …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Inventory Update" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogInventoryUpdate="$dialogApp \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--mini \
--moveable \
--progress \
--progresstext \"$inventoryProgressText\" \
--quitkey K \
--commandfile \"$dialogLog\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${loggedInUser}" || "${loggedInUser}" == "loginwindow" ]]; then
    echo "No user logged-in; exiting."
    exit 0
# else
#     uid=$(id -u "${loggedInUser}")
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    echo "macOS ${osMajorVersion} installed; proceeding ..."
else
    echo "macOS ${osMajorVersion} installed; updating inventory sans progress …"
    /usr/local/bin/jamf recon -endUsername "${loggedInUser}" --verbose >> "$inventoryLog" &     # Include the user name of the primary user
    # /usr/local/bin/jamf recon --verbose >> "$inventoryLog" &                                  # Omit the user name of the primary user
    exit 0
fi



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
# JAMF Display Message (for fallback in case swiftDialog fails to install)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function jamfDisplayMessage() {
    updateScriptLog "Jamf Display Message: ${1}"
    /usr/local/jamf/bin/jamf displayMessage -message "${1}" &
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / install swiftDialog (thanks, Adam!)
# https://github.com/acodega/dialog-scripts/blob/main/dialogCheckFunction.sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

  # Expected Team ID of the downloaded PKG
  expectedDialogTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

    updateScriptLog "Dialog not found. Installing..."

    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
 
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /

    else

      jamfDisplayMessage "Dialog Team ID verification failed."
      exit 1

    fi
 
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  

  else

    updateScriptLog "swiftDialog version $(dialog --version) found; proceeding..."

  fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Quitting …"
    updateDialog "quit: "

    sleep 1
    updateScriptLog "Exiting …"

    # brutal hack - need to find a better way
    killall tail

    # Remove dialogLog
    if [[ -e ${dialogLog} ]]; then
        updateScriptLog "Removing ${dialogLog} …"
        rm "${dialogLog}"
    fi

    # Remove inventoryLog
    if [[ -e ${inventoryLog} ]]; then
        updateScriptLog "Removing ${inventoryLog} …"
        rm "${inventoryLog}"
    fi

    updateScriptLog "Goodbye!"
    exit 0

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateDialog() {
    echo "${1}" >> "${dialogLog}"
    sleep 0.4
}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root; exiting."
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
    updateScriptLog "*** Created log file via script ***"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logging preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${debugMode} == "true" ]]; then
    updateScriptLog "DEBUG MODE | swiftDialog Inventory Update Progress (${scriptVersion})"
else
    updateScriptLog "swiftDialog Inventory Update Progress (${scriptVersion})"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create "Inventory Update" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Inventory Update dialog …"
eval "$dialogInventoryUpdate" &

if [[ ${debugMode} == "true" ]]; then
    sleep 0.5
    updateDialog "title: DEBUG MODE | $title"
    updateDialog "message: Please wait while a DEBUG inventory is submitted …"
fi

SECONDS="0"
updateDialog "progress: 1"

/usr/local/bin/jamf recon -endUsername "${loggedInUser}" --verbose >> "$inventoryLog" &     # Include the user name of the primary user
# /usr/local/bin/jamf recon --verbose >> "$inventoryLog" &                                  # Omit the user name of the primary user

until [[ "$inventoryProgressText" == "Submitting data to"* ]]; do

    progressPercentage=$( echo "scale=2 ; ( $SECONDS / $estimatedTotalSeconds ) * 100" | bc )
    updateDialog "progress: ${progressPercentage}"
    # if [[ ${debugMode} == "true" ]]; then
    #     updateScriptLog "DEBUG MODE | progress: ${progressPercentage}"
    # fi

    inventoryProgressText=$( tail -n1 "$inventoryLog" | sed -e 's/verbose: //g' -e 's/Found app: \/System\/Applications\///g' -e 's/Utilities\///g' -e 's/Found app: \/Applications\///g' -e 's/Running script for the extension attribute //g' )
    updateDialog "progresstext: ${inventoryProgressText}"
    if [[ ${debugMode} == "true" ]]; then
        updateScriptLog "DEBUG MODE | progresstext: ${inventoryProgressText}"
    fi

done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete "Inventory Update" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Complete Inventory Update dialog"
updateDialog "message: Inventory update complete"
updateDialog "progress: 100"
updateDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
updateScriptLog "Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

sleep 3



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript