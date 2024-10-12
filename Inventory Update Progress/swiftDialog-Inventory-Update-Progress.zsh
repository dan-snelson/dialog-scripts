#!/bin/zsh --no-rcs
# shellcheck shell=bash

####################################################################################################
#
#   Duration-triggered Inventory Update Progress with swiftDialog
#   https://snelson.us/2024/02/inventory-update-progress/
#
#   Provide your users more detailed feedback when updating inventory via Jamf Pro Self Service, at the duration **you** specify
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
# Version 0.0.5, 22-Nov-2022, Dan K. Snelson (@dan-snelson)
#	Added overlayicon
#
# Version 0.0.6, 29-Nov-2022, Dan K. Snelson (@dan-snelson)
#	Added --position bottomright
#
# Version 0.0.7, 10-Feb-2024, Dan K. Snelson (@dan-snelson)
#   Added check for recently executed inventory update
#
#       :fire: **Breaking Change** for users prior to `0.0.7` :fire:
#       
#       Version `0.0.7` modifies the Script Parameter Label for `scriptLog` — changing it to a
#       hard-coded variable in the script (as it should have been all along) — Sorry for any
#       Dan-induced headaches.
#
# Version 0.0.8, 14-Mar-2024, Dan K. Snelson (@dan-snelson)
#   Updated shebang to include `--no-rcs`
#
# Version 0.0.9, 12-Oct-2024, Dan K. Snelson (@dan-snelson)
#   - Added new Operation Mode: Silent Always (thanks for #61, @mechman27!)
#   - Updated `swiftDialogMinimumRequiredVersion` to 2.5.2.4777
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Script Version & Client-side Log
scriptVersion="0.0.9"
scriptLog="/var/log/org.churchofjesuschrist.log"

# Display an inventory progress dialog, even if an inventory update is not required
displayProgessSansUpdate="true"

# swiftDialog Binary & Logs 
swiftDialogMinimumRequiredVersion="2.5.2.4777"
dialogBinary="/usr/local/bin/dialog"
dialogLog=$( mktemp -u /var/tmp/dialogLog.XXX )
inventoryLog=$( mktemp -u /var/tmp/inventoryLog.XXX )

# Currently logged-in user
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Seconds To Wait before updating inventory
# 86400 seconds is 1 day; 90061 seconds is 1 day, 1 hour, 1 minute and 1 second.
secondsToWait="${4:-"86400"}"

# Parameter 5: Estimated Total Seconds
estimatedTotalSeconds="${5:-"120"}"

# Parameter 6: Operation Mode [ Default (i.e., delayed inventory update with swiftDialog progress) | Self Service |  Silent Always |  Silent | Uninstall ]
operationMode="${6:-"Default"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readable Name
humanReadableScriptName="swiftDialog Inventory Update Progress"

# Organization's Script Name
organizationScriptName="sdIU"

# Organization's Directory (i.e., where your client-side scripts reside; must previously exist)
organizationDirectory="/path/to/your/client/side/scripts/"

# Inventory Delay File
inventoryDelayFilepath="${organizationDirectory}.${organizationScriptName}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osVersion=$( sw_vers -productVersion )
osVersionExtra=$( sw_vers -productVersionExtra ) 
osBuild=$( sw_vers -buildVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )

# Report RSR sub-version if applicable
if [[ -n $osVersionExtra ]] && [[ "${osMajorVersion}" -ge 13 ]]; then osVersion="${osVersion} ${osVersionExtra}"; fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Inventory Update" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Updating Inventory"
message="Please wait while inventory is updated …"
icon="https://ics.services.jamfcloud.com/icon/hash_ff2147a6c09f5ef73d1c4406d00346811a9c64c0b6b7f36eb52fcb44943d26f9"
overlay=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
inventoryProgressText="Initializing …"

dialogInventoryUpdate="$dialogBinary \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--overlayicon \"$overlay\" \
--mini \
--position bottomright \
--moveable \
--progress \
--progresstext \"$inventoryProgressText\" \
--quitkey K \
--commandfile \"$dialogLog\" "



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo "${organizationScriptName} ($scriptVersion): $( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

function preFlight() {
    updateScriptLog "[PRE-FLIGHT]      ${1}"
}

function logComment() {
    updateScriptLog "                  ${1}"
}

function notice() {
    updateScriptLog "[NOTICE]          ${1}"
}

function info() {
    updateScriptLog "[INFO]            ${1}"
}

function debugVerbose() {
    if [[ "$debugMode" == "verbose" ]]; then
        updateScriptLog "[DEBUG VERBOSE]   ${1}"
    fi
}

function debug() {
    if [[ "$debugMode" == "true" ]]; then
        updateScriptLog "[DEBUG]           ${1}"
    fi
}

function errorOut(){
    updateScriptLog "[ERROR]           ${1}"
}

function error() {
    updateScriptLog "[ERROR]           ${1}"
    let errorCount++
}

function warning() {
    updateScriptLog "[WARNING]         ${1}"
    let errorCount++
}

function fatal() {
    updateScriptLog "[FATAL ERROR]     ${1}"
    exit 1
}

function quitOut(){
    updateScriptLog "[QUIT]            ${1}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Inventory, showing progress via swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateInventoryProgress() {

    notice "Create Inventory Update dialog …"
    eval "$dialogInventoryUpdate" &

    SECONDS="0"
    updateDialog "progress: 1"

    /usr/local/bin/jamf recon -endUsername "${loggedInUser}" --verbose >> "$inventoryLog" &

    until [[ "$inventoryProgressText" == "Submitting data to"* ]]; do

        progressPercentage=$( echo "scale=2 ; ( $SECONDS / $estimatedTotalSeconds ) * 100" | bc )
        updateDialog "progress: ${progressPercentage}"

        inventoryProgressText=$( tail -n1 "$inventoryLog" | sed -e 's/verbose: //g' -e 's/Found app: \/System\/Applications\///g' -e 's/Utilities\///g' -e 's/Found app: \/Applications\///g' -e 's/Running script for the extension attribute //g' )
        updateDialog "progresstext: ${inventoryProgressText}"

    done

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete "Inventory Update" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function completeInventoryProgress() {

    logComment "Complete Inventory Update dialog"
    updateDialog "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
    updateDialog "message: Inventory update complete"
    updateDialog "progress: 100"
    updateDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
    logComment "Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
    sleep 3

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Self Service Inventory Update (i.e., ALWAYS update inventory)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function selfServiceInventoryUpdate() {

    logComment "Inventory WILL BE updated, showing progress via swiftDialog …"
    touch "${inventoryDelayFilepath}"
    updateInventoryProgress
    completeInventoryProgress

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# JAMF Display Message (for fallback in case swiftDialog fails to install)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function jamfDisplayMessage() {
    updateScriptLog "Jamf Display Message: ${1}"
    /usr/local/jamf/bin/jamf displayMessage -message "${1}" &
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogInstall() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    preFlight "Installing swiftDialog..."

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
        preFlight "swiftDialog version ${dialogVersion} installed; proceeding..."

    else

        # Display a so-called "simple" dialog if Team ID fails to validate
        osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
        completionActionOption="Quit"
        exitCode="1"
        quitScript

    fi

    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"

}



function dialogCheck() {

    # Output Line Number in `verbose` Debug Mode
    if [[ "${debugMode}" == "verbose" ]]; then preFlight "# # # SETUP YOUR MAC VERBOSE DEBUG MODE: Line No. ${LINENO} # # #" ; fi

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        preFlight "swiftDialog not found. Installing..."
        dialogInstall

    else

        dialogVersion=$(/usr/local/bin/dialog --version)
        if [[ "${dialogVersion}" < "${swiftDialogMinimumRequiredVersion}" ]]; then
            
            preFlight "swiftDialog version ${dialogVersion} found but swiftDialog ${swiftDialogMinimumRequiredVersion} or newer is required; updating..."
            dialogInstall
            
        else

        preFlight "swiftDialog version ${dialogVersion} found; proceeding..."

        fi
    
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    notice "*** QUITTING ***"
    updateDialog "quit: "

    # Remove dialogLog
    if [[ -f "${dialogLog}" ]]; then
        logComment "Removing ${dialogLog} …"
        rm "${dialogLog}"
    fi

    # Remove inventoryLog
    if [[ -f "${inventoryLog}" ]]; then
        logComment "Removing ${inventoryLog} …"
        rm "${inventoryLog}"
    fi

    logComment "Goodbye!"
    exit "${1}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateDialog() {
    echo "${1}" >> "${dialogLog}"
    sleep 0.1
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Uninstall
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function uninstall() {

    warning "*** UNINSTALLING ${humanReadableScriptName} ***"
    info "Reset inventoryDelayFilepath … "
    logComment "Removing '${inventoryDelayFilepath}' … "
    rm -f "${inventoryDelayFilepath}"
    logComment "Removed '${inventoryDelayFilepath}'"
    logComment "Uninstalled all ${humanReadableScriptName} configuration files"
    notice "Thanks for using ${humanReadableScriptName}!"

}



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
    if [[ -f "${scriptLog}" ]]; then
        preFlight "Created specified scriptLog"
    else
        fatal "Unable to create specified scriptLog '${scriptLog}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    preFlight "Specified scriptLog exists; writing log entries to it"
fi




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# https://snelson.us\n###\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Organization Directory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -d "${organizationDirectory}" ]]; then
    preFlight "Specified Organization Directory of exists; proceeding …"
else
    fatal "The specified Organization Directory of is NOT found; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 12 ]] ; then
    preFlight "macOS ${osMajorVersion} installed; proceeding ..."
    dialogCheck
else
    preFlight "macOS ${osMajorVersion} installed; updating inventory sans progress …"
    /usr/local/bin/jamf recon -endUsername "${loggedInUser}" --verbose >> "$inventoryLog" &
    exit 0
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate / Create Inventory Delay File
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${inventoryDelayFilepath}" ]]; then
    touch "${inventoryDelayFilepath}"
    if [[ -f "${inventoryDelayFilepath}" ]]; then
        preFlight "Created specified inventoryDelayFilepath"
    else
        fatal "Unable to create specified inventoryDelayFilepath; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    preFlight "Specified inventoryDelayFilepath exists; proceeding …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Complete!"



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Seconds To Wait" Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

testFileSeconds=$( date -j -f "%s" "$( stat -f "%m" $inventoryDelayFilepath)" +"%s" )
nowSeconds=$( date +"%s" )
ageInSeconds=$((nowSeconds-testFileSeconds))
secondsToWaitHumanReadable=$( printf '"%dd, %dh, %dm, %ds"\n' $((secondsToWait/86400)) $((secondsToWait%86400/3600)) $((secondsToWait%3600/60)) $((secondsToWait%60)) )
ageInSecondsHumanReadable=$( printf '"%dd, %dh, %dm, %ds"\n' $((ageInSeconds/86400)) $((ageInSeconds%86400/3600)) $((ageInSeconds%3600/60)) $((ageInSeconds%60)) )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Evaluate "Seconds To Wait" and "Operation Mode" before updating inventory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "*** Evaluating 'Seconds To Wait' and 'Operation Mode' before updating inventory ***"
logComment "Set to wait ${secondsToWaitHumanReadable} and inventoryDelayFilepath was created ${ageInSecondsHumanReadable} ago"
logComment "Operation Mode: '${operationMode}'"

if [[ ${ageInSeconds} -le ${secondsToWait} ]]; then
    
    # Current Inventory is "fresh" (i.e., inventory isn't yet stale enough to be updated)

    case ${operationMode} in

        "Self Service" ) # When executed via Self Service, *always* update inventory 
            selfServiceInventoryUpdate
            quitScript "0"
            ;;
        
        "Silent Always" ) # Update inventory, sans swiftDialog bypassing the ageInSeconds parameter
            logComment "Inventory WILL BE updated, sans swiftDialog …"
            /usr/local/bin/jamf recon -endUsername "${loggedInUser}"
            quitScript "0"
            ;;

        "Silent" ) # Don't leverage swiftDialog
            notice "Inventory will NOT be updated …"
            quitScript "0"
            ;;

        "Uninstall" ) # Remove client-side files
            notice "Sorry to see you go …"
            uninstall
            quitScript "0"
            ;;

        * | "Default" ) # Default Catch-all
            notice "Inventory will NOT be updated …"
            if [[ "${displayProgessSansUpdate}" == "true" ]]; then
                logComment "Display 'Inventory update not required' dialog …"
                eval "$dialogInventoryUpdate" &
                updateDialog "progress: 1"
                updateDialog "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
                updateDialog "message: Inventory update not required"
                updateDialog "progress: 100"
                updateDialog "progresstext: "
                logComment "So long!"
                sleep 3
            fi
            quitScript "0"
            ;;

    esac

elif [[ ${ageInSeconds} -ge ${secondsToWait} ]]; then

    # Current Inventory is "stale" (i.e., inventory is stale and should be updated)

    case ${operationMode} in

        "Self Service" ) # When executed via Self Service, *always* update inventory 
            selfServiceInventoryUpdate
            quitScript "0"
            ;;
            
        "Silent Always" ) # Update inventory, sans swiftDialog bypassing the ageInSeconds parameter
            logComment "Inventory WILL BE updated, sans swiftDialog …"
            /usr/local/bin/jamf recon -endUsername "${loggedInUser}"
            quitScript "0"
            ;;

        "Silent" ) # Update inventory, sans swiftDialog
            logComment "Inventory WILL BE updated, sans swiftDialog …"
            /usr/local/bin/jamf recon -endUsername "${loggedInUser}"
            quitScript "0"
            ;;

        "Uninstall" ) # Remove client-side files
            logComment "Sorry to see you go …"
            uninstall
            quitScript "0"
            ;;

        * | "Default" ) # Default Catch-all
            logComment "Inventory WILL BE updated, showing progress via swiftDialog …"
            touch "${inventoryDelayFilepath}"
            updateInventoryProgress
            completeInventoryProgress
            quitScript "0"
            ;;

    esac

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Sideways Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "1"