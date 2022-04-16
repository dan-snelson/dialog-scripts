#!/bin/bash

####################################################################################################
#
# Setup Your Mac via Dialog
#
# Purpose: Leverages Dialog v1.10.1 (or later) (https://github.com/bartreardon/Dialog/releases) and 
# Jamf Pro Policy Custom Events to allow end-users to self-complete Mac setup post-enrollment
# via Jamf Pro's Self Service. (See Jamf Pro Known Issues PI100009 - PI-004775.)
#
# Inspired by: Rich Trouton (@rtrouton) and Bart Reardon (@bartreardon)
#
# Based on: Adam Codega (@adamcodega)'s https://github.com/acodega/dialog-scripts/blob/main/MDMAppsDeploy.sh
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 19-Mar-2022, Dan K. Snelson (@dan-snelson)
#   Original version
#
# Version 0.0.2, 20-Mar-2022, Dan K. Snelson (@dan-snelson)
#   Corrected initial indeterminate progress bar. (Thanks, @bartreardon!)
#
# Version 0.0.3, 21-Mar-2022, Dan K. Snelson (@dan-snelson)
#   Re-corrected initial indeterminate progress bar.
#
# Version 0.0.4, 16-Apr-2022, Dan K. Snelson (@dan-snelson)
#   Updated for Listview processing https://github.com/bartreardon/swiftDialog/pull/103
#   Added dynamic, policy-based icons
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog Title and Message
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Setting up your Mac"
message="Please wait while the following apps are downloaded and installed:"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# For each configuration step (i.e., app to be installed), enter a pipe-separated list of:
# Display Name | Filepath for validation | Jamf Pro Policy Custom Event Name | Icon hash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

apps=(
    "Palo Alto GlobalProtect|/Applications/GlobalProtect.app|globalProtect|ea794c5a1850e735179c7c60919e3b51ed3ed2b301fe3f0f27ad5ebd394a2e4b"
    "FileVault Disk Encryption|/Library/Preferences/com.apple.fdesetup.plist|filevault|f9ba35bd55488783456d64ec73372f029560531ca10dfa0e8154a46d7732b913"
    "Sophos Endpoint|/Applications/Sophos/Sophos Endpoint.app|sophosEndpoint|c70f1acf8c96b99568fec83e165d2a534d111b0510fb561a283d32aa5b01c60c"
    "Google Chrome|/Applications/Google Chrome.app|googleChrome|12d3d198f40ab2ac237cff3b5cb05b09f7f26966d6dffba780e4d4e5325cc701"
    "Microsoft Teams|/Applications/Microsoft Teams.app|microsoftTeams|dcb65709dba6cffa90a5eeaa54cb548d5ecc3b051f39feadd39e02744f37c19e"
    "Zoom|/Applications/zoom.us.app|zoom|92b8d3c448e7d773457532f0478a428a0662f694fbbfc6cb69e1fab5ff106d97"
)



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog path and Command File
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogApp="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Overlay Icon based on Self Service icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set progress_total to the number of apps in the list
# Add 1 to progress_total for "Updating Inventory step"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_total=${#apps[@]}
progress_total=$(( 1 + progress_total ))


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog icon based on whether the Mac is a desktop or laptop
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

hwType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | grep "Book")  
if [ "$hwType" != "" ]; then
  icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
  icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialog_command(){
  echo "$1"
  echo "$1"  >> $dialog_command_file
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Finalise app installations
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function finalise(){
  dialog_command "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
  dialog_command "progresstext: Installation of applications complete."
  sleep 5
  dialog_command "icon: https://ics.services.jamfcloud.com/icon/hash_90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296"
  dialog_command "progresstext: Updating computer inventory …"
  /usr/local/bin/jamf recon
  dialog_command "icon: SF=checkmark.seal.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
  dialog_command "progresstext: Complete"
  dialog_command "progress: complete"
  dialog_command "button1text: Done"
  dialog_command "button1: enable"
  exit 0
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for app installation
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function appCheck(){
  while [ ! -e "$(echo "$app" | cut -d '|' -f2)" ]; do
    sleep 2
  done
  dialog_command "listitem: $(echo "$app" | cut -d '|' -f1): success"
  dialog_command "progress: increment"
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
# Construct dialog to be displayed to the end-user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCMD="$dialogApp -p --title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress $progress_total \
--button1text \"Please Wait\" \
--button1disabled \
--blurscreen \
--ontop \
--overlayicon \"$overlayicon\" \
--messagefont 'size=14'"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create the list of apps
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

listitems=""
for app in "${apps[@]}"; do
  listitems="$listitems --listitem '$(echo "$app" | cut -d '|' -f1)'"
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Final dialog to be displayed to the end-user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCMD="$dialogCMD $listitems"
echo "$dialogCMD"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Launch dialog and run it in the background; sleep for two seconds to let thing initialise
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

eval "$dialogCMD" &
sleep 2



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set initial progress bar
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_index=0
dialog_command "progress: $progress_index"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set wait icon for all listitems 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

for app in "${apps[@]}"; do
  dialog_command "listitem: $(echo "$app" | cut -d '|' -f1): wait"
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute Jamf Pro Policy Events 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

(for app in "${apps[@]}"; do
  dialog_command "icon: https://ics.services.jamfcloud.com/icon/hash_$(echo "$app" | cut -d '|' -f4)"
  dialog_command "listitem: $(echo "$app" | cut -d '|' -f1): pending"
  dialog_command "progresstext: Installing $(echo "$app" | cut -d '|' -f1) …"
  install_command=$( echo "$app" | cut -d '|' -f3 )
  /usr/local/bin/jamf policy -event "$install_command" -verbose
  appCheck &
done

wait)



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete processing and enable the "Done" button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

finalise