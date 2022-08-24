#!/bin/bash

####################################################################################################
#
# Setup Your Mac via swiftDialog
#
# Purpose: Leverages swiftDialog v1.11.0.2758 (or later) (https://github.com/bartreardon/swiftDialog/releases) and 
# Jamf Pro Policy Custom Events to allow end-users to self-complete Mac setup post-enrollment
# via Jamf Pro's Self Service. (See Jamf Pro Known Issues PI100009 - PI-004775.)
#
# Inspired by: Rich Trouton (@rtrouton) and Bart Reardon (@bartreardon)
#
# Based on:
# - Adam Codega (@adamcodega)'s https://github.com/acodega/dialog-scripts/blob/main/MDMAppsDeploy.sh
# - James Smith (@smithjw)'s https://github.com/smithjw/swiftEnrolment
#
####################################################################################################
#
# HISTORY
#
# Version 1.2.5, 24-Aug-2022, Dan K. Snelson (@dan-snelson)
#   Resolves https://github.com/dan-snelson/dialog-scripts/issues/3 (thanks, @pyther!)
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version & Debug Mode (Jamf Pro Script Parameter 4)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="1.2.5"
debugMode="${4}"        # ( true | false, blank )
assetTagCapture="${5}"  # ( true | false, blank )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog path, Command Files, JAMF binary, log files and currently logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogApp="/usr/local/bin/dialog"
dialogCommandFile="/var/tmp/dialog.log"
welcomeScreenCommandFile="/var/tmp/dialog_welcome_screen.log"
loggedInUser=$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }' )
jamfBinary="/usr/local/bin/jamf"
logFolder="/private/var/log"
logName="enrollment.log"
exitCode="0"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# APPS TO BE INSTALLED
#
# For each configuration step, specify:
# - listitem: The text to be displayed in the list
# - icon: The hash of the icon to be displayed on the left
#   - See: https://rumble.com/v119x6y-harvesting-self-service-icons.html
# - progresstext: The text to be displayed below the progress bar 
# - trigger: The Jamf Pro Policy Custom Event Name
# - path: The filepath for validation
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
            "icon": "92b8d3c448e7d773457532f0478a428a0662f694fbbfc6cb69e1fab5ff106d97",
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
            "progresstext": "Finalizing Church Configuration …",
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
# "Welcome Screen" Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeTitle="Welcome to your new Mac!"
welcomeMessage="To begin, please enter your Mac's **Asset Tag**, then click **Continue** to start applying Church settings to your new Mac.  \n\nOnce completed, the **Quit** button will be re-enabled and you'll be prompted to restart your Mac.  \n\nIf you need assistance, please contact the Help Desk: +1 (801) 555-1212."

appleInterfaceStyle=$( /usr/bin/defaults read /Users/"${loggedInUser}"/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>&1 )

if [[ "${appleInterfaceStyle}" == "Dark" ]]; then
    welcomeIcon="https://wallpapercave.com/dwp2x/MGxxFCB.jpg"
else
    welcomeIcon="https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Apple_Computer_Logo_rainbow.svg/1028px-Apple_Computer_Logo_rainbow.svg.png?20201228132849"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome Screen" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogWelcomeScreenCMD="$dialogApp --ontop --title  \"$welcomeTitle\" \
--message \"$welcomeMessage\" \
--icon \"$welcomeIcon\" \
--iconsize 198 \
--button1text \"Continue\" \
--button2text \"Quit\" \
--button2disabled \
--infotext \"v$scriptVersion\" \
--blurscreen \
--titlefont 'size=26' \
--messagefont 'size=16' \
--textfield \"Asset Tag\",required=true,prompt=\"Please enter your Mac's seven-digit Asset Tag\",regex='^(AP|IP)?[0-9]{6,}$',regexerror=\"Please enter (at least) seven digits for the Asset Tag, optionally preceed by either 'AP' or 'IP'. \" \
--quitkey k \
--commandfile \"$welcomeScreenCommandFile\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" Dialog Title, Message, Overlay Icon and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Setting up your Mac"
message="Please wait while the following apps are installed …"
overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )

# Set initial icon based on whether the Mac is a desktop or laptop
hwType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | grep "Book")
if [ "$hwType" != "" ]; then
  icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
  icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCMD="$dialogApp --ontop --title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress $progress_total \
--button1text \"Quit\" \
--button1disabled \
--infotext \"v$scriptVersion\" \
--titlefont 'size=28' \
--messagefont 'size=14' \
--height '67%' \
--position 'centre' \
--blurscreen \
--overlayicon \"$overlayicon\" \
--quitkey K"

# --liststyle 'compact' \


#------------------------------- Edits below this line are optional -------------------------------#



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# JAMF Display Message (for fallback in case swiftDialog fails to install)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function jamfDisplayMessage() {
    echo "${1}"
    /usr/local/jamf/bin/jamf displayMessage -message "${1}" &
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / install swiftDialog (thanks, Adam!)
# https://github.com/acodega/dialog-scripts/blob/main/dialogCheckFunction.sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
  # Expected Team ID of the downloaded PKG
  expectedDialogTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
    echo "Dialog not found. Installing..."
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
    echo_logger "DIALOG: version $(dialog --version) found; proceeding..."
  fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a "Welcome Screen" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialog_command_welcome_screen(){
  echo "$1"
  echo "$1"  >> $welcomeScreenCommandFile
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a "Setup Your Mac" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialog_update() {
    echo_logger "DIALOG: $1"
    # shellcheck disable=2001
    echo "$1" >> "$dialogCommandFile"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Finalise app installations
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function finalise(){
    if [[ "${jamfProPolicyTriggerFailure}" == "failed" ]]; then
        dialog_update "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
        dialog_update "progresstext: Failures detected; Church Support notified. Please restart."
        echo_logger "Jamf Pro Policy Trigger Failures: ${jamfProPolicyTriggerFailures}"
    else
        dialog_update "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
        dialog_update "progresstext: Complete! Please restart and enjoy your new Mac!"
    fi
    dialog_update "progress: complete"
    dialog_update "button1text: Quit"
    dialog_update "button1: enable"
    rm "$dialogCommandFile"
    rm "$welcomeScreenCommandFile"
    exit "${exitCode}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#  smithjw's Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function echo_logger() {
    logFolder="${logFolder:=/private/var/log}"
    logName="${logName:=log.log}"

    mkdir -p $logFolder

    echo -e "$(date +%Y-%m-%d\ %H:%M:%S)  $1" | tee -a $logFolder/$logName
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
    if [ "$debugMode" = true ]; then
        echo_logger "DIALOG: DEBUG MODE: $jamfBinary policy -event $trigger"
        sleep 7
    elif [ "$trigger" == "recon" ]; then
        if [[ ${assetTagCapture} == "true" ]]; then
            echo_logger "DIALOG: RUNNING: $jamfBinary recon -assetTag ${assetTag}"
            "$jamfBinary" recon -assetTag "${assetTag}"
        else
            echo_logger "DIALOG: RUNNING: $jamfBinary recon"
            "$jamfBinary" recon
        fi
    else
        echo_logger "DIALOG: RUNNING: $jamfBinary policy -event $trigger"
        "$jamfBinary" policy -event "$trigger"
    fi
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
  echo "This script should be run as root"
  exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Welcome Screen and capture user's interaction
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${assetTagCapture} == "true" ]]; then

    assetTag=$( eval "$dialogWelcomeScreenCMD" | awk -F " : " '{print $NF}' )

    if [[ -z ${assetTag} ]]; then
        returncode="2"
    else
        returncode="0"
    fi

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Evaluate User Interaction at Welcome Screen
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${assetTagCapture} == "true" ]]; then

    case ${returncode} in

        0)  ## Process exit code 0 scenario here
            echo_logger "DIALOG: ${loggedInUser} entered an Asset Tag of ${assetTag} and clicked Continue"
            eval "${dialogCMD[*]}" & sleep 0.3
            dialog_update "message: Asset Tag reported as \`${assetTag}\`. $message"
            if [[ ${debugMode} == "true" ]]; then
                dialog_update "title: DEBUG MODE | $title"
            fi
            ;;

        2)  ## Process exit code 2 scenario here
            echo_logger "DIALOG: ${loggedInUser} clicked Quit when prompted to enter Asset Tag"
            exit 0
            ;;

        3)  ## Process exit code 3 scenario here
            echo_logger "DIALOG: ${loggedInUser} clicked infobutton"
            /usr/bin/osascript -e "set Volume 3"
            /usr/bin/afplay /System/Library/Sounds/Tink.aiff
            ;;

        4)  ## Process exit code 4 scenario here
            echo_logger "DIALOG: ${loggedInUser} allowed timer to expire"
            eval "${dialogCMD[*]}" & sleep 0.3
            ;;

        *)  ## Catch all processing
            echo_logger "DIALOG: Something else happened; Exit code: ${returncode}"
            exit 1
            ;;

    esac

else

    eval "${dialogCMD[*]}" & sleep 0.3
    if [[ ${debugMode} == "true" ]]; then
        dialog_update "title: DEBUG MODE | $title"
    fi

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set progress_total to the number of steps in policy_array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialog_update "progresstext: Initializing configuration …"
progress_total=$(get_json_value "${policy_array[*]}" "steps.length")
echo_logger "DIALOG: progress_total=$progress_total"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set initial progress bar
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_index=0
dialog_update "progress: $progress_index"



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
# The ${array_name[*]/%/,} expansion will combine all items within the array adding a "," character at the end
# To add a character to the start, use "/#/" instead of the "/%/"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

list_item_string=${list_item_array[*]/%/,}
dialog_update "list: ${list_item_string%?}"
for (( i=0; i<dialog_step_length; i++ )); do
    dialog_update "listitem: index: $i, icon: https://ics.services.jamfcloud.com/icon/hash_${icon_url_array[$i]}, status: pending, statustext: Pending …"
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Close Welcome Screen and pause on initial loading screen to build anticipation
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialog_command_welcome_screen "quit:"
sleep 3



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# This for loop will iterate over each distinct step in the policy_array array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

for (( i=0; i<dialog_step_length; i++ )); do

    # Increment the progress bar
    dialog_update "progress: $(( i * ( 100 / progress_total ) ))"

    # Creating initial variables
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    progresstext=$(get_json_value "${policy_array[*]}" "steps[$i].progresstext")

    trigger_list_length=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list.length")

    # If there's a value in the variable, update running swiftDialog

    if [[ -n "$listitem" ]]; then dialog_update "listitem: index: $i, icon: https://ics.services.jamfcloud.com/icon/hash_$icon, status: wait, statustext: Installing …, "; fi
    if [[ -n "$icon" ]]; then dialog_update "icon: https://ics.services.jamfcloud.com/icon/hash_$icon"; fi
    if [[ -n "$progresstext" ]]; then dialog_update "progresstext: $progresstext"; fi
    if [[ -n "$trigger_list_length" ]]; then
        for (( j=0; j<trigger_list_length; j++ )); do
            # Setting variables within the trigger_list
            trigger=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].trigger")
            path=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].path")

            # If the path variable has a value, check if that path exists on disk
            if [[ -f "$path" ]]; then
                echo_logger "INFO: $path exists, moving on"
                 if [[ "$debugMode" = true ]]; then sleep 3; fi
            else
                run_jamf_trigger "$trigger"
            fi
        done
    fi

    # Validate the expected path exists
    echo_logger "DIALOG: Testing for \"$path\" …"
    if [[ -f "$path" ]] || [[ -z "$path" ]]; then
        dialog_update "listitem: index: $i, icon: https://ics.services.jamfcloud.com/icon/hash_$icon, status: success, statustext: Installed"
    else
        dialog_update "listitem: index: $i, icon: https://ics.services.jamfcloud.com/icon/hash_$icon, status: fail, statustext: Failed"
        jamfProPolicyTriggerFailure="failed"
        jamfProPolicyTriggerFailures+="$trigger; "
        exitCode="1"
    fi
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete processing and enable the "Done" button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

finalise