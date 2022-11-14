#!/bin/bash

####################################################################################################
#
# Setup Your Mac via swiftDialog
# https://snelson.us/setup-your-mac/
#
####################################################################################################
#
# HISTORY
#
#   Version 1.3.0, 09-Nov-2022, Dan K. Snelson (@dan-snelson)
#       Script Parameter Changes:
#       - Parameter 4: `debug` mode enabled by default
#       - Parameter 7: Script Log Location
#       Embraced drastic speed improvements in swiftDialog v2
#       Caffeinated script (thanks, @grahampugh!)
#       Enhanced `wait` exiting logic
#       General script standardization
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version & Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="1.3.0"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
debugMode="${4:-"true"}"            # [ true (default) | false ]
infoCapture="${5:-"false"}"     # [ true | false (default) ]
completionAction="${6:-"wait"}"     # [ number of seconds to sleep | wait (default) ]
scriptLog="${7:-"/var/tmp/org.churchofjesuschrist.log"}"

if [[ ${debugMode} == "true" ]]; then
    scriptVersion="Dialog: v$(dialog --version) • Setup Your Mac: v${scriptVersion}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for an allowed "Completion Action" value (Parameter 6); defaults to "wait"
# Options: [ number of seconds to sleep | wait (default) ]
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case "${completionAction}" in
    '' | *[!0-9]*   ) completionAction="wait" ;;
    *               ) completionAction="sleep ${completionAction}" ;;
esac

if [[ ${debugMode} == "true" ]]; then
    echo "Using \"${completionAction}\" as the Completion Action"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog path, Command Files, JAMF binary, log files and currently logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogApp="/usr/local/bin/dialog"
welcomeCommandFile=$( mktemp /var/tmp/dialogWelcome.XXX )
setupYourMacCommandFile=$( mktemp /var/tmp/dialogSetupYourMac.XXX )
setupYourMacPolicyArrayIconPrefixUrl="https://ics.services.jamfcloud.com/icon/hash_"
failureCommandFile=$( mktemp /var/tmp/dialogFailure.XXX )
jamfBinary="/usr/local/bin/jamf"
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | cut -d " " -f 1 )
exitCode="0"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# APPS TO BE INSTALLED (Thanks, Obi-@smithjw!)
#
# For each configuration step, specify:
# - listitem: The text to be displayed in the list
# - icon: The hash of the icon to be displayed on the left
#   - See: https://rumble.com/v119x6y-harvesting-self-service-icons.html
# - progresstext: The text to be displayed below the progress bar 
# - trigger: The Jamf Pro Policy Custom Event Name
# - path: The filepath for validation
#
# shellcheck disable=1112
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

policy_array=('
{
    "steps": [
        {
            "listitem": "FileVault Disk Encryption",
            "icon": "f9ba35bd55488783456d64ec73372f029560531ca10dfa0e8154a46d7732b913",
            "progresstext": "FileVault is built-in to macOS and provides full-disk encryption to help prevent unauthorized access to your Mac.",
            "trigger_list": [
                {
                    "trigger": "filevault",
                    "path": "/Library/Preferences/com.apple.fdesetup.plist"
                }
            ]
        },
        {
            "listitem": "Sophos Endpoint",
            "icon": "c70f1acf8c96b99568fec83e165d2a534d111b0510fb561a283d32aa5b01c60c",
            "progresstext": "You’ll enjoy next-gen protection with Sophos Endpoint which doesn’t rely on signatures to catch malware.",
            "trigger_list": [
                {
                    "trigger": "sophosEndpoint",
                    "path": "/Applications/Sophos/Sophos Endpoint.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Palo Alto GlobalProtect",
            "icon": "fcccf5d72ad9a4f6d3a4d780dcd8385378a0a8fd18e8c33ad32326f5bd53cca0",
            "progresstext": "Use Palo Alto GlobalProtect to establish a Virtual Private Network (VPN) connection to Church headquarters.",
            "trigger_list": [
                {
                    "trigger": "globalProtect",
                    "path": "/Applications/GlobalProtect.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Microsoft Teams",
            "icon": "dcb65709dba6cffa90a5eeaa54cb548d5ecc3b051f39feadd39e02744f37c19e",
            "progresstext": "Microsoft Teams is a hub for teamwork in Office 365. Keep all your team’s chats, meetings and files together in one place.",
            "trigger_list": [
                {
                    "trigger": "microsoftTeams",
                    "path": "/Applications/Microsoft Teams.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Zoom",
            "icon": "be66420495a3f2f1981a49a0e0ad31783e9a789e835b4196af60554bf4c115ac",
            "progresstext": "Zoom is a videotelephony software program developed by Zoom Video Communications.",
            "trigger_list": [
                {
                    "trigger": "zoom",
                    "path": "/Applications/zoom.us.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Google Chrome",
            "icon": "12d3d198f40ab2ac237cff3b5cb05b09f7f26966d6dffba780e4d4e5325cc701",
            "progresstext": "Google Chrome is a browser that combines a minimal design with sophisticated technology to make the Web faster.",
            "trigger_list": [
                {
                    "trigger": "googleChrome",
                    "path": "/Applications/Google Chrome.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Final Configuration",
            "icon": "00d7c19b984222630f20b6821425c3548e4b5094ecd846b03bde0994aaf08826",
            "progresstext": "Finalizing Configuration …",
            "trigger_list": [
                {
                    "trigger": "finalConfiguration",
                    "path": ""
                },
                {
                    "trigger": "reconAtReboot",
                    "path": ""
                },
                {
                    "trigger": "computerNameSet",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Update Inventory",
            "icon": "90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296",
            "progresstext": "A listing of your Mac’s apps and settings — its inventory — is sent automatically to the Jamf Pro server daily.",
            "trigger_list": [
                {
                    "trigger": "recon",
                    "path": ""
                }
            ]
        }
    ]
}
')



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome / Asset Tag" Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeTitle="Welcome to your new Mac, ${loggedInUserFirstname}!"
welcomeMessage="To begin, please enter your Mac's **Asset Tag**, then click **Continue** to start applying Church settings to your new Mac.  \n\nOnce completed, the **Quit** button will be re-enabled and you'll be prompted to restart your Mac.  \n\nIf you need assistance, please contact the Help Desk: +1 (801) 555-1212."

appleInterfaceStyle=$( /usr/bin/defaults read /Users/"${loggedInUser}"/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>&1 )

if [[ "${appleInterfaceStyle}" == "Dark" ]]; then
    welcomeIcon="https://wallpapercave.com/dwp2x/MGxxFCB.jpg"
else
    welcomeIcon="https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Apple_Computer_Logo_rainbow.svg/1028px-Apple_Computer_Logo_rainbow.svg.png?20201228132849"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome / Asset Tag" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogWelcomeCMD="$dialogApp \
--title \"$welcomeTitle\" \
--message \"$welcomeMessage\" \
--icon \"$welcomeIcon\" \
--iconsize 198 \
--button1text \"Continue\" \
--button2text \"Quit\" \
--button2disabled \
--infotext \"$scriptVersion\" \
--blurscreen \
--ontop \
--titlefont 'size=26' \
--messagefont 'size=16' \
--textfield \"Asset Tag\",required=true,prompt=\"Please enter your Mac's seven-digit Asset Tag\",regex='^(AP|IP)?[0-9]{7,}$',regexerror=\"Please enter (at least) seven digits for the Asset Tag, optionally preceed by either 'AP' or 'IP'. \" \
--textfield \"Computer Name\",required=true,prompt=\"Please enter your Mac's Computer Name\" \
--selecttitle \"Location\" \
--selectvalues \"Building 1, Building 2, Buliding 3\" \
--selectdefault \"Building 1\" \
--selecttitle \"Department\" \
--selectvalues \"Department 1, Department 2, Department 3\" \
--selectdefault \"Department 1\" \
--quitkey k \
--commandfile \"$welcomeCommandFile\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" Dialog Title, Message, Overlay Icon and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Setting up ${loggedInUserFirstname}'s Mac"
message="Please wait while the following apps are installed …"
overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )

# Set initial icon based on whether the Mac is a desktop or laptop
if system_profiler SPPowerDataType | grep -q "Battery Power"; then
  icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
  icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSetupYourMacCMD="$dialogApp \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress \
--progresstext \"Initializing configuration …\" \
--button1text \"Quit\" \
--button1disabled \
--infotext \"$scriptVersion\" \
--titlefont 'size=28' \
--messagefont 'size=14' \
--height '70%' \
--position 'centre' \
--blurscreen \
--ontop \
--overlayicon \"$overlayicon\" \
--quitkey k \
--commandfile \"$setupYourMacCommandFile\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

failureTitle="Failure Detected"
failureMessage="Placeholder message; update in the finalise function"
failureIcon="SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogFailureCMD="$dialogApp \
--moveable \
--title \"$failureTitle\" \
--message \"$failureMessage\" \
--icon \"$failureIcon\" \
--iconsize 125 \
--width 625 \
--height 400 \
--position topright \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--titlefont 'size=22' \
--messagefont 'size=14' \
--overlayicon \"$overlayicon\" \
--commandfile \"$failureCommandFile\" "



#------------------------------- Edits below this line are optional -------------------------------#



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
# Execute a "Welcome / Asset Tag" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateWelcome(){
    updateScriptLog "WELCOME DIALOG: $1"
    echo "$1" >> "$welcomeCommandFile"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a "Setup Your Mac" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateSetupYourMac() {
    updateScriptLog "SETUP YOUR MAC DIALOG: $1"
    echo "$1" >> "$setupYourMacCommandFile"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a "Failure" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateFailure(){
    updateScriptLog "FAILURE DIALOG: $1"
    echo "$1" >> "$failureCommandFile"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Finalise app installations
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function finalise(){

    if [[ "${jamfProPolicyTriggerFailure}" == "failed" ]]; then

        killProcess "caffeinate"
        dialogUpdateSetupYourMac "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
        dialogUpdateSetupYourMac "progresstext: Failures detected. Please click Continue for troubleshooting information."
        dialogUpdateSetupYourMac "button1text: Continue …"
        dialogUpdateSetupYourMac "button1: enable"
        dialogUpdateSetupYourMac "progress: complete"
        updateScriptLog "Jamf Pro Policy Name Failures: ${jamfProPolicyPolicyNameFailures}"
        eval "${completionAction}"
        dialogUpdateSetupYourMac "quit:"
        eval "${dialogFailureCMD}" & sleep 0.3
        if [[ ${debugMode} == "true" ]]; then
            dialogUpdateFailure "title: DEBUG MODE | $failureTitle"
        fi
        dialogUpdateFailure "message: A failure has been detected, ${loggedInUserFirstname}.  \n\nPlease complete the following steps:\n1. Reboot and login to your Mac  \n2. Login to Self Service  \n3. Re-run any failed policy listed below  \n\nThe following failed to install:  \n${jamfProPolicyPolicyNameFailures}  \n\n\n\nIf you need assistance, please contact the Help Desk,  \n+1 (801) 555-1212, and mention [KB86753099](https://servicenow.company.com/support?id=kb_article_view&sysparm_article=KB86753099#Failures). "
        dialogUpdateFailure "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
        eval "${completionAction}"
        dialogUpdateFailure "quit:"
        quitScript "${exitCode}"

    else

        dialogUpdateSetupYourMac "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
        dialogUpdateSetupYourMac "progresstext: Complete! Please restart and enjoy your new Mac, ${loggedInUserFirstname}!"
        dialogUpdateSetupYourMac "progress: complete"
        dialogUpdateSetupYourMac "button1text: Quit"
        dialogUpdateSetupYourMac "button1: enable"
        if [[ "${completionAction}" == "wait" ]]; then
            wait "${dialogProcessID}" # Comment-out this line to NOT require user-interaction for successful completions
        else
            eval "${completionAction}"
        fi
        quitScript "${exitCode}"

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON via osascript and JavaScript
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function get_json_value() {
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env).$2"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# smithjw's sweet function to execute Jamf Pro Policy Custom Events
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function run_jamf_trigger() {
    trigger="$1"
    if [[ "$debugMode" = true ]]; then
        if [ "$trigger" == "recon" ]; then
            if [[ ${infoCapture} == "true" ]]; then
                updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: $jamfBinary recon -assetTag ${assetTag}"
                updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: $jamfBinary setComputerName -name ${computerName}"
                updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: $jamfBinary recon -department ${department}"
                updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: $jamfBinary recon -building ${location}"
            else
                updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary recon"
            fi
        else
            updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: $jamfBinary policy -event $trigger"
        fi
        sleep 2
    elif [ "$trigger" == "recon" ]; then
        if [[ ${infoCapture} == "true" ]]; then
            updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary recon -assetTag ${assetTag}"
            "$jamfBinary" recon -assetTag "${assetTag}"
            updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary setComputerName -name ${computerName}"
            "$jamfBinary" setComputerName -name "${computerName}"
            updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary recon -department ${department}"
            "$jamfBinary" recon -department "${department}"
            updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary recon -building ${location}"
            "$jamfBinary" recon -building "${location}"
        else
            updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary recon"
            "$jamfBinary" recon
        fi
    else
        updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary policy -event $trigger"
        "$jamfBinary" policy -event "$trigger"
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Kill a specified process (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function killProcess() {

    process="$1"
    if process_pid=$( pgrep -a "${process}" 2>/dev/null ) ; then
        updateScriptLog "Attempting to terminate the '$process' process …"
        updateScriptLog "(Termination message indicates success.)"
        kill "$process_pid" 2> /dev/null
        if pgrep -a "$process" >/dev/null ; then
            updateScriptLog "ERROR: '$process' could not be terminated."
        fi
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Exiting …"

    # Stop `caffeinate` process
    updateScriptLog "De-caffeinate …"
    killProcess "caffeinate"

    # Remove welcomeCommandFile
    if [[ -e ${welcomeCommandFile} ]]; then
        updateScriptLog "Removing ${welcomeCommandFile} …"
        rm "${welcomeCommandFile}"
    fi

    # Remove setupYourMacCommandFile
    if [[ -e ${setupYourMacCommandFile} ]]; then
        updateScriptLog "Removing ${setupYourMacCommandFile} …"
        rm "${setupYourMacCommandFile}"
    fi

    # Remove failureCommandFile
    if [[ -e ${failureCommandFile} ]]; then
        updateScriptLog "Removing ${failureCommandFile} …"
        rm "${failureCommandFile}"
    fi

    updateScriptLog "Goodbye!"
    exit "${1}"

}



####################################################################################################
#
# Pre-flight Checks
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
    updateScriptLog "\n\n###\n# DEBUG MODE | Setup Your Mac (${scriptVersion})\n###\n"
else
    updateScriptLog "\n\n###\n# Setup Your Mac (${scriptVersion})\n###\n"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm Setup Assistant complete and user at Desktop
# Useful for triggering on Enrollment Complete and will not pause if run via Self Service
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dockStatus=$( pgrep -x Dock )
updateScriptLog "Waiting for Desktop …"

while [[ "$dockStatus" == "" ]]; do
    updateScriptLog "Desktop is not loaded; waiting 5 seconds …"
    sleep 5
    dockStatus=$( pgrep -x Dock )
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Ensure computer does not go to sleep while running this script (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Caffeinating this script (pid=$$)"
caffeinate -dimsu -w $$ &



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Welcome Screen and capture user's interaction
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${infoCapture} == "true" ]]; then

    userDialogInput=$( eval "$dialogWelcomeCMD" )

    computerName=$( echo "$userDialogInput" | grep "Computer Name" | awk -F " : " '{print $NF}' )
    department=$( echo "$userDialogInput" | grep "Department" | head -1 | awk -F " : " '{print $NF}' )
    location=$( echo "$userDialogInput" | grep "Location" | head -1 | awk -F " : " '{print $NF}' )
    assetTag=$( echo "$userDialogInput" | grep "Asset Tag" | awk -F " : " '{print $NF}' )
    
    if [[ -z ${assetTag} ]]; then
        returncode="2"
    else
        returncode="0"
    fi

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Evaluate User Interaction at Welcome Screen
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${infoCapture} == "true" ]]; then

    case ${returncode} in

        0)  ## Process exit code 0 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} entered an Asset Tag of ${assetTag} and clicked Continue"
            eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
            dialogProcessID=$!
            dialogUpdateSetupYourMac "message: Asset Tag reported as \`${assetTag}\`. $message"
            if [[ ${debugMode} == "true" ]]; then
                dialogUpdateSetupYourMac "title: DEBUG MODE | $title"
            fi
            ;;

        2)  ## Process exit code 2 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} clicked Quit when prompted to enter Asset Tag"
            quitScript "0"
            ;;

        3)  ## Process exit code 3 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} clicked infobutton"
            /usr/bin/osascript -e "set Volume 3"
            /usr/bin/afplay /System/Library/Sounds/Tink.aiff
            ;;

        4)  ## Process exit code 4 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} allowed timer to expire"
            eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
            dialogProcessID=$!
            ;;

        *)  ## Catch all processing
            updateScriptLog "WELCOME DIALOG: Something else happened; Exit code: ${returncode}"
            quitScript "1"
            ;;

    esac

else

    eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
    dialogProcessID=$!
    if [[ ${debugMode} == "true" ]]; then
        dialogUpdateSetupYourMac "title: DEBUG MODE | $title"
    fi

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Iterate through policy_array JSON to construct the list for swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialog_step_length=$(get_json_value "${policy_array[*]}" "steps.length")
for (( i=0; i<dialog_step_length; i++ )); do
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    list_item_array+=("$listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    icon_url_array+=("$icon")
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set progress_total to the number of steps in policy_array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_total=$(get_json_value "${policy_array[*]}" "steps.length")
updateScriptLog "SETUP YOUR MAC DIALOG: progress_total=$progress_total"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# The ${array_name[*]/%/,} expansion will combine all items within the array adding a "," character at the end
# To add a character to the start, use "/#/" instead of the "/%/"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

list_item_string=${list_item_array[*]/%/,}
dialogUpdateSetupYourMac "list: ${list_item_string%?}"
for (( i=0; i<dialog_step_length; i++ )); do
    dialogUpdateSetupYourMac "listitem: index: $i, icon: ${setupYourMacPolicyArrayIconPrefixUrl}${icon_url_array[$i]}, status: pending, statustext: Pending …"
done
dialogUpdateSetupYourMac "list: show"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set initial progress bar
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_index=0
dialogUpdateSetupYourMac "progress: $progress_index"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Close Welcome Screen
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogUpdateWelcome "quit:"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# This for loop will iterate over each distinct step in the policy_array array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

for (( i=0; i<dialog_step_length; i++ )); do

    # Increment the progress bar
    dialogUpdateSetupYourMac "progress: $(( i * ( 100 / progress_total ) ))"

    # Creating initial variables
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    progresstext=$(get_json_value "${policy_array[*]}" "steps[$i].progresstext")

    trigger_list_length=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list.length")

    # If there's a value in the variable, update running swiftDialog

    if [[ -n "$listitem" ]]; then dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Installing …, "; fi
    if [[ -n "$icon" ]]; then dialogUpdateSetupYourMac "icon: ${setupYourMacPolicyArrayIconPrefixUrl}${icon}"; fi
    if [[ -n "$progresstext" ]]; then dialogUpdateSetupYourMac "progresstext: $progresstext"; fi
    if [[ -n "$trigger_list_length" ]]; then
        for (( j=0; j<trigger_list_length; j++ )); do
            # Setting variables within the trigger_list
            trigger=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].trigger")
            path=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].path")

            # If the path variable has a value, check if that path exists on disk
            if [[ -f "$path" ]]; then
                updateScriptLog "SETUP YOUR MAC DIALOG: INFO: $path exists, moving on"
                if [[ "$debugMode" = true ]]; then sleep 3; fi
            else
                run_jamf_trigger "$trigger"
            fi
        done
    fi

    # Validate the expected path exists
    updateScriptLog "SETUP YOUR MAC DIALOG: Testing for \"$path\" …"
    if [[ -f "$path" ]] || [[ -z "$path" ]]; then
        dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Installed"
    else
        dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
        jamfProPolicyTriggerFailure="failed"
        jamfProPolicyPolicyNameFailures+="• $listitem  \n"
        exitCode="1"
    fi

done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete processing and enable the "Done" button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

finalise