#!/bin/bash

####################################################################################################
#
# Setup Your Mac via Dialog
#
# Purpose: Leverages Dialog v1.9.1+ (https://github.com/bartreardon/Dialog/releases) and 
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
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

dialogApp="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# For each configuration step (i.e., app to be installed), enter a pipe-separated list of:
# Display Name | Filepath for validation | Jamf Pro Policy Custom Event Name
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

apps=(
    "Palo Alto GlobalProtect|/Applications/GlobalProtect.app|globalProtect"
    "FileVault Disk Encryption|/Library/Preferences/com.apple.fdesetup.plist|filevault"
    "Sophos Endpoint|/Applications/Sophos/Sophos Endpoint.app|sophosEndpoint"
    "Google Chrome|/Applications/Google Chrome.app|googleChrome"
    "Microsoft Teams|/Applications/Microsoft Teams.app|microsoftTeams"
    "Zoom|/Applications/zoom.us.app|zoom"
)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set progress_total to the number of apps in the list
# Add 1 to progress_total for "Updating Inventory step"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_total=${#apps[@]}
progress_total=$(( 1 + progress_total ))

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog Title and Message
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Setting up your Mac"
message="Please wait while the following apps are downloaded and installed:"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog icon based on whether the Mac is a desktop or laptop
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

hwType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | grep "Book")  
if [ "$hwType" != "" ]; then
  icon="SF=laptopcomputer.and.arrow.down,weight=thin,colour1=#51a3ef,colour2=#5154ef"
else
  icon="SF=desktopcomputer.and.arrow.down,weight=thin,colour1=#51a3ef,colour2=#5154ef"
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
  dialog_command "progresstext: Installation of applications complete."
  sleep 5
  dialog_command "progresstext: Updating computer inventory …"
  /usr/local/bin/jamf recon
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
  dialog_command "listitem: $(echo "$app" | cut -d '|' -f1): ✅"
  dialog_command "progress: increment"
  progress_index=$(( progress_index + 1 ))
  echo "at item number $progress_index"
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
dialog_command "progress: 1"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute Jamf Pro Policy Events 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

(for app in "${apps[@]}"; do
  dialog_command "listitem: $(echo "$app" | cut -d '|' -f1): wait"
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