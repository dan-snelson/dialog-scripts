#!/bin/bash
####################################################################################################
#
# ABOUT
#
#   swiftDialog Pre-install
#   Pre-install Company Logo for swiftDialog v2 Notifications
#
#   See: https://snelson.us/2023/03/swiftdialog-notifications/
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.1, 14-Nov-2022, Dan K. Snelson (@dan-snelson)
#       - Original proof-of-concept version
#
#   Version 0.0.2, 16-Nov-2022, Dan K. Snelson (@dan-snelson)
#       - Added "last logged-in user" logic
#       - Added check for Dialog.png (with graceful exit)
#
#   Version 0.0.3, 16-Mar-2023, Dan K. Snelson (@dan-snelson)
#       - Create 'Dialog.png' from Self Service's custom icon (thanks, @meschwartz!)
#       - Remove no longer required 'loggedInUser'-related code
#
#   Version 0.0.4, 10-Jul-2023, Dan K. Snelson (@dan-snelson)
#       - Installation Action (Parameter 5) [ none (default) | remove ]
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Global Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="0.0.4"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
scriptLog="${4:-"/var/tmp/org.churchofjesuschrist.log"}"
installationAction="${5:-"none"}"   # [ none (default) | remove ]



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

updateScriptLog "\n\n###\n# swiftDialog Pre-install (${scriptVersion})\n# https://snelson.us\n###\n"
updateScriptLog "PRE-FLIGHT CHECK: Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    updateScriptLog "PRE-FLIGHT CHECK: This script must be run as root; exiting."
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "PRE-FLIGHT CHECK: Complete"



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Installation Action
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Installation Action: ${installationAction} …"

case ${installationAction} in

    "remove" )
        updateScriptLog "Removing swiftDialog …"
        rm -fv /usr/local/bin/dialog
        rm -Rfv /Library/Application\ Support/Dialog/
        rm -fv /var/tmp/dialog.log
        updateScriptLog "swiftDialog has been removed"
        ;;

     "install" )
        updateScriptLog "Installing new swiftDialog version …"

function dialogCheck() {

    # Output Line Number in `true` Debug Mode
    #if [[ "${debugMode}" == "true" ]]; then updateScriptLog "WARM-UP: # # # Patch Helper true DEBUG MODE: Line No. ${LINENO} # # #" ; fi

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        updateScriptLog "WARM-UP: Dialog not found. Installing..."

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
            updateScriptLog "WARM-UP: swiftDialog version ${dialogVersion} installed; proceeding..."

        else

            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Swift Dialog: Error" buttons {"Close"} with icon caution'
            completionActionOption="Quit"
            exitCode="1"
            quitScript

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        updateScriptLog "WARM-UP: swiftDialog version $(/usr/local/bin/dialog --version) found; proceeding..."

    fi
    }
    if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    dialogCheck
else
    updateScriptLog "WARM-UP: swiftDialog version $(/usr/local/bin/dialog --version) found; proceeding..."
fi
        updateScriptLog "swiftDialog has been installed"
        ;;

    "none" | * )
        updateScriptLog "Skipping Installation Action"
        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Dialog Branding Image
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Validate 'Dialog.png' …"
if [[ -f "/Library/Application Support/Dialog/Dialog.png" ]]; then
    updateScriptLog "The file '/Library/Application Support/Dialog/Dialog.png' already exists; exiting."
    exit 0
else
    updateScriptLog "The file '/Library/Application Support/Dialog/Dialog.png' does NOT exist; proceeding …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Dialog directory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -d "/Library/Application Support/Dialog/" ]]; then
    updateScriptLog "Creating '/Library/Application Support/Dialog/' …"
    mkdir -p "/Library/Application Support/Dialog/"
else
    updateScriptLog "The directory '/Library/Application Support/Dialog/' exists …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Dialog.png from Self Service's custom icon (thanks, @meschwartz!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create 'Dialog.png' …"
xxd -p -s 260 "$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path)"/Icon$'\r'/..namedfork/rsrc | xxd -r -p > "/Library/Application Support/Dialog/Dialog.png"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Dialog Branding Image
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Validate 'Dialog.png' …"
if [[ ! -f "/Library/Application Support/Dialog/Dialog.png" ]]; then
    updateScriptLog "Error: The file '/Library/Application Support/Dialog/Dialog.png' was NOT found."
    exit 1
else
    updateScriptLog "The file '/Library/Application Support/Dialog/Dialog.png' was created sucessfully."
    find "/Library/Application Support/Dialog/Dialog.png" | tee -a "${scriptLog}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "End-of-line."

exit 0