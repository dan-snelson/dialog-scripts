#!/bin/bash

####################################################################################################
#
# CrowdStrike Falcon Inspector
#
#   Purpose: Displays an end-user message about CrowdStrike Falcon via swiftDialog
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 11-Nov-2022, Dan K. Snelson (@dan-snelson)
#   Original, proof-of-concept version
#   (Variables lifted from Jason Broccardo's https://github.com/zoocoup/CrowdStrikeEAsforJamfPro)
#
# Version 0.0.2, 11-Nov-2022, Dan K. Snelson (@dan-snelson)
#   Corrected button enablement on completion
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

scriptVersion="0.0.2"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
osVersion=$( sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
dialogApp="/usr/local/bin/dialog"
dialogWelcomeLog=$( mktemp /var/tmp/dialogWelcomeLog.XXXX )
scriptLog="${4:-"/var/tmp/org.churchofjesuschrist.log"}"
debugMode="${5:-"true"}"
anticipationDuration="${6:-"3"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="CrowdStrike Falcon Inspector ($scriptVersion)"
message="This script analyzes the installation of CrowdStrike Falcon then reports the findings in a this window.  \n\nPlease wait …"
# icon="/Applications/Falcon.app"
icon="https://ics.services.jamfcloud.com/icon/hash_c9f81b098ecb0a2d527dd9fe464484892f1df5990d439fa680d54362023a5b5a"
# overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
button1text="Wait"
infobuttontext="KB8675309"
infobuttonaction="https://servicenow.company.com/support?id=kb_article_view&sysparm_article=${infobuttontext}"
welcomeProgressText="Initializing …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogWelcome="$dialogApp \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--button1text \"$button1text\" \
--button1disabled \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--progress \
--progresstext \"$welcomeProgressText\" \
--moveable \
--titlefont size=22 \
--messagefont size=14 \
--iconsize 135 \
--width 650 \
--height 350 \
--commandfile \"$dialogWelcomeLog\" "

# --overlayicon \"$overlayIcon\" \



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
# Check for / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

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
    updateWelcomeDialog "quit: "

    sleep 1
    updateScriptLog "Exiting …"

    # Remove dialogWelcomeLog
    if [[ -e ${dialogWelcomeLog} ]]; then
        updateScriptLog "Removing ${dialogWelcomeLog} …"
        rm "${dialogWelcomeLog}"
    fi

    updateScriptLog "Goodbye!"
    exit "${1}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateWelcomeDialog() {
    sleep 0.3
    echo "${1}" >> "${dialogWelcomeLog}"
}



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
    updateScriptLog "*** Created log file via script ***"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logging preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${debugMode} == "true" ]]; then
    updateScriptLog "\n\n###\n# DEBUG MODE | CrowdStrike Falcon Inspector (${scriptVersion})\n###\n"
else
    updateScriptLog "\n\n###\n# CrowdStrike Falcon Inspector (${scriptVersion})\n###\n"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    updateScriptLog "This script must be run as root; exiting."
    quitScript "1"
else
    updateScriptLog "Script running as \"root\"; proceeding …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    updateScriptLog "macOS ${osMajorVersion} installed; proceeding ..."
else
    updateScriptLog "macOS ${osMajorVersion} installed; exiting"
    quitScript "1"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate CrowdStrike Falcon installation (or exit with error)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -e /Applications/Falcon.app/Contents/MacOS/Falcon ]]; then
    updateScriptLog "CrowdStrike Falcon installed; proceeding …"
else
    updateScriptLog "CrowdStrike Falcon not installed; exiting"
    quitScript "1"
fi



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Welcome Dialog …"

eval "$dialogWelcome" & sleep 0.3

if [[ ${debugMode} == "true" ]]; then

    updateWelcomeDialog "title: DEBUG MODE | $title"
    updateWelcomeDialog "message: DEBUG MODE. Please wait for ${anticipationDuration} seconds …"
    updateWelcomeDialog "progresstext: DEBUG MODE. Pausing for ${anticipationDuration} seconds"
    sleep "${anticipationDuration}"
    falconVersion="DEBUG"
    systemExtensionStatus="DEBUG"
    falconAgentID="DEBUG"
    falconHeartbeats6="DEBUG"

else

    updateWelcomeDialog "progress: 5"
    updateWelcomeDialog "progresstext: Inspecting …"
    sleep "${anticipationDuration}"

    SECONDS="0"

    # CrowdStrike Falcon Inspection: Installation
    updateWelcomeDialog "progress: 18"
    updateWelcomeDialog "progresstext: Installation …"

    # CrowdStrike Falcon Inspection: Version
    falconVersion=$( /Applications/Falcon.app/Contents/Resources/falconctl stats | awk '/version/ {print $2}' )
    updateWelcomeDialog "progress: 36"
    updateWelcomeDialog "progresstext: Version …"

    # CrowdStrike Falcon Inspection: System Extension List
    systemExtensionTest=$( systemextensionsctl list | awk '/com.crowdstrike.falcon.Agent/ {print $7,$8}' | wc -l )
    if [[ "${systemExtensionTest}" -gt 0 ]]; then
        systemExtensionStatus="Loaded"
    else
        systemExtensionStatus="Likely **not** running"
    fi
    updateWelcomeDialog "progress: 54"
    updateWelcomeDialog "progresstext: System Extension …"

    # CrowdStrike Falcon Inspection: Agent ID
    falconAgentID=$( /Applications/Falcon.app/Contents/Resources/falconctl stats | awk '/agentID/ {print $2}' | tr '[:upper:]' '[:lower:]' | sed 's/\-//g' )
    updateWelcomeDialog "progress: 72"
    updateWelcomeDialog "progresstext: Agent ID …"

    # CrowdStrike Falcon Inspection: Heartbeats
    falconHeartbeats6=$( /Applications/Falcon.app/Contents/Resources/falconctl stats | awk '/SensorHeartbeatMacV4/ {print $4,$5,$6,$7,$8}' | sed 's/ /\ | /g' )
    updateWelcomeDialog "progress: 90"
    updateWelcomeDialog "progresstext: Heartbeats …"

    # Capture results to log
    updateScriptLog "Results for ${loggedInUser}"
    updateScriptLog "Installation Status: Installed"
    updateScriptLog "Version: ${falconVersion}"
    updateScriptLog "System Extension: ${systemExtensionStatus}"
    updateScriptLog "Agent ID: ${falconAgentID}"
    updateScriptLog "Heartbeats: ${falconHeartbeats6}"
    updateScriptLog "Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

    # Display results to user
    timestamp="$( date '+%Y-%m-%d-%H%M%S' )"
    updateWelcomeDialog "message: **Results for ${loggedInUser} on ${timestamp}**  \n\n- **Installation Status:** Installed  \n- **Version:** ${falconVersion}  \n- **System Extension:** ${systemExtensionStatus}  \n- **Agent ID:** ${falconAgentID}  \n- **Heartbeats:** ${falconHeartbeats6}"
    updateWelcomeDialog "progress: complete"
    updateWelcomeDialog "progresstext: Complete!"
    sleep "${anticipationDuration}"

fi

updateWelcomeDialog "button1text: Done"
updateWelcomeDialog "button1: enable"
updateWelcomeDialog "progress: 100"
updateWelcomeDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

wait

updateScriptLog "End-of-line."

quitScript "0"