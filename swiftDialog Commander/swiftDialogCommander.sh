#!/bin/bash

####################################################################################################
#
#    swiftDialog Commander
#
#    Purpose: Test swiftDialog commands
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.1, 31-May-2022, Dan K. Snelson (@dan-snelson)
#        Original version
#
#   Version 0.0.2, 04-Jun-2022, Dan K. Snelson (@dan-snelson)
#       Added output of initial dialog settings
#       Added `progress`, `progresstext` and command-line examples
#       Added `listitem` examples
#       Corrected a dialog displaying and immediately closing when using `--help`
#
#   Version 0.0.3, 06-Jun-2022, Dan K. Snelson (@dan-snelson)
#       Added link to blog post for additional examples
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="0.0.3"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog path, Command File, log files and currently logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogApp="/usr/local/bin/dialog"
dialogVersion=$( dialog --version )
dialogCommandFile="/var/tmp/dialog.log"
loggedInUser=$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( /usr/bin/id -F ${loggedInUser} )
loggedInUserFirstname=$( /bin/echo $loggedInUserFullname | /usr/bin/cut -d " " -f 1 )
logFolder="/Users/Shared/swiftDialogCMD"
logName="swiftDialogCMD.log"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Initial Dialog Title, Message
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Welcome to swiftDialog Commander ($scriptVersion)"
message="To begin, the **--moveable** option is enabled, so you can click-and-drag this window (from its upper-left hand corner) to a more sutible location (i.e., so you can see _both_ Terminal and this swiftDialog window.)  \n\nConsole _should_ have launched and opened two log files:\n1. **$dialogCommandFile**, the file that swiftDialog is set to watch for updates, which you should move below this swiftDialog window  \n\n  2. **$logFolder/$logName**, the log file for this script, which you should move below the Terminal window  \n\nEnter commands in Terminal at the **»** prompt; here are a few examples:  \n\n    title: $loggedInUserFirstname's First Test of swiftDialog  \n\n    icon: /System/Library/CoreServices/Finder.app  \n\n    message: swiftDialog is pretty sweet  \n\n    overlayicon: /Library/Application Support/Dialog/Dialog.app  \n\nEnter **quit:** to close this dialog, then enter **reset** to auto-launch a new dialog; enter **exit** to close this dialog and exit the script. (See [Updating Dialog with new content](https://github.com/bartreardon/swiftDialog/wiki/Updating-Dialog-with-new-content--(v1.9.0)).)  \n\nIf you need general assistance, please join us on the MacAdmin's Slack [swiftDialog](https://macadmins.slack.com/archives/C01U5MXNGG6) channel."
icon="/Library/Application Support/Dialog/Dialog.app"
initialProgressText="Provide your users with progress feedback"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Inital Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCMD="$dialogApp --ontop --title  \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--iconsize 198 \
--button1text \"button1text (button1disabled)\" \
--button1disabled \
--button2text \"button2text\" \
--infotext \
--titlefont 'size=26' \
--messagefont 'size=14' \
--height 575 \
--moveable \
--position 'topright' \
--progress 100 \
--progresstext \"$initialProgressText\" \
--quitkey K "



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function echo_logger() {
    logFolder="${logFolder:=/Users/Shared/swiftDialogCMD}"
    logName="${logName:=swiftDialogCMD.log}"

    mkdir -p $logFolder

    echo "$(date +%Y-%m-%d\ %H:%M:%S)  $1" >> "$logFolder/$logName"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Keep Dialog Alive
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function keepDialogAlive() {
    if [ ! "$(pgrep -i -u ${loggedInUser} dialog)" ]; then
        echo_logger "INFO: Dialog isn't running, launching now"
        eval "$dialogApp" "${dialogCMD}" & sleep 0.3
    else
        echo_logger "INFO: Dialog is running"
    fi
    osascript -e 'tell application "Terminal" to activate'
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Help
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function displayHelp() {

    echo "quit:" >> "$dialogCommandFile"

    printf '\e[8;30;100t' ; printf '\e[3;5;5t' ; clear

    echo "
swiftDialog Commander, ${scriptVersion} (for swiftDialog $dialogVersion)
by Dan K. Snelson (@dan-snelson)

    Usage:
    bash swiftDialogCommander.sh [-r | --reset] [-h | --help]

    [no flags]      Displays the \"»\" prompt and enters interactive mode
                    where you can enter commands to update the running swiftDialog.

                    Type \"exit\" and press [Return] to leave interactive mode.
                  
                    Sample commands:

                        title: Title goes here

                        message: Message goes here

                        icon: /System/Library/CoreServices/Finder.app

                        list: Item 1, Item 2, Item 3



    -r | --reset    Resets the log file before launching the script

    -h | --help     Displays this message and exits



    "
    exit
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update running dialog, then return focus to Terminal
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialog_update() {
    keepDialogAlive
    echo_logger "DIALOG: $1"
    echo "$1" >> "$dialogCommandFile"
    osascript -e 'tell application "Terminal" to activate'
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
# Reveal File in Finder
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function revealMe() {
	/usr/bin/open -R "${1}"
}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Initial Setup
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

printf '\e[8;50;100t' ; printf '\e[3;5;5t' ; clear
rm "$dialogCommandFile" > /dev/null 2>&1
echo -e "###\n# Welcome to swiftDialog Commander ($scriptVersion)\n###\n"
echo -e "This script updates a running swiftDialog via the macOS Terminal;"
echo -e "version $dialogVersion of swiftDialog is currently installed.\n"
echo -e "Type \"exit\" to close the dialog and exit this script; you can then\nre-run the script and add \"--help\" to view the built-in help.\n"
echo -e "Try copying-and-pasting the following commands:\n"
echo -e "   title: $loggedInUserFirstname's First Test of swiftDialog\n"
echo -e "   icon: /System/Library/CoreServices/Finder.app\n"
echo -e "   icon: SF=person.3.sequence.fill,palette=red,green,blue\n"
echo -e "   message: swiftDialog is pretty sweet\n"
echo -e "   overlayicon: /Library/Application Support/Dialog/Dialog.app\n"
echo -e "   list: Item 1, Item 2, Item 3\n"
echo -e "   listitem: title: Item 1, status: success\n"
echo -e "   progresstext: Item 1 installed.\n"
echo -e "   progress: 33\n"
echo -e "   listitem: title: Item 2, status: wait, statustext: Pending\n"
echo -e "   progress: 66\n"
echo -e "   listitem: title: Item 3, status: wait, statustext: Pending\n"
echo -e "   listitem: title: Item 2, status: fail, statustext: Failed\n"
echo -e "   progresstext: Item 2 failed.\n"
echo -e "Additional examples are available at:"
echo -e "https://snelson.us/swiftDialogCommander\n\n"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test for various flags during invocation
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

while test $# -gt 0; do
    case "$1" in
        -r|--reset )
            shift
            rm "$logFolder/$logName"
            echo_logger "Reset $logName …"
            ;;
        -h|--help )
            displayHelp
            ;;
    esac
    shift
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / create log files
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -d "${dialogCommandFile}" ]]; then # logFile not found; Create logFile ...
    mkdir -p "$logFolder"
    touch "$logFolder/$logFile"
    touch "$dialogCommandFile"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logging preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo_logger "swiftDialog Commander (${scriptVersion})"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Open log files
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo_logger "Open: $logFolder/$logName …"
open "$logFolder/$logName"

echo_logger "Open: $dialogCommandFile …"
open "$dialogCommandFile"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Launch swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo_logger "Initial swiftDialog command:"
echo_logger "$dialogCMD"

keepDialogAlive



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Give focus back to Terminal
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osascript -e 'tell application "Terminal" to activate'



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute sdCommands
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

while [[ "$sdCommand" != "exit" ]] ; do
    read -r -p "$(echo $'» ')" sdCommand
    dialog_update "${sdCommand}"
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "quit:" >> "$dialogCommandFile"
pkill -u ${loggedInUser} tail
osascript -e 'quit app "Console"'
revealMe "$logFolder/$logName"
revealMe "$dialogCommandFile"

exit 0