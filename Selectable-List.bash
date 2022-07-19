#!/bin/bash

####################################################################################################
#
# swiftDialog Selectable List
# See: https://github.com/bartreardon/swiftDialog/wiki/Selectable-Lists
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 19-Jul-2022, Dan K. Snelson (@dan-snelson)
#   Initial Proof-of-concept
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

scriptVersion="0.0.1"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog path, Command Files, JAMF binary, log files and currently logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogApp="/usr/local/bin/dialog"
dialogCommandFile="/var/tmp/dialog.log"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog Title, Message, Overlay Icon and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Selectable List"
message="Please select your Department"
overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )

# Set initial icon based on whether the Mac is a desktop or laptop
hwType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | grep "Book")  
if [ "$hwType" != "" ]; then
  icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
  icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCMD="$dialogApp --ontop --title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--button1text \"OK\" \
--infotext \"v$scriptVersion\" \
--overlayicon \"$overlayicon\" \
--titlefont 'size=28' \
--messagefont 'size=14' \
--textfield \"Asset Tag\",required=true,prompt=\"Please enter your Mac's seven-digit Asset Tag\",regex='^\d{7,}$',regexerror=\"Please enter seven digits (numbers only) for the Asset Tag\" \
--selecttitle \"Select an Option\" \
--selectvalues \"Option 1,Option 2,Option 3,Option 4, Option 5\" \
--position 'centre' \
--quitkey k"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Welcome Screen and capture user's interaction
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

userInput=$( eval "$dialogCMD" )

assetTag=$( echo "$userInput" | grep "Asset Tag" | awk -F " : " '{print $NF}' )
option=$( echo "$userInput" | grep "SelectedOption" | awk -F " : " '{print $NF}' )

echo "Asset Tag: ${assetTag}"
echo "Option: ${option}"



exit 0