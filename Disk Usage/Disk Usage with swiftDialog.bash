#!/bin/bash
####################################################################################################
#
# ABOUT
#
#   Disk Usage with swiftDialog
#   Help users determine what's occupying all their hard drive space
#
#   See: https://snelson.us/2022/11/disk-usage-with-swiftdialog-0-0-2/
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.1, 09-Nov-2022, Dan K. Snelson (@dan-snelson)
#       Original swiftDialog, proof-of-concept version
#
#   Version 0.0.2, 12-Nov-2022, Dan K. Snelson (@dan-snelson)
#       Removed `--ontop` from Progress dialog (for longer execution times)
#       Hard-coded estimated execution time for user's home folder to 60 percent
#       Opened the macOS built-in Storage information
#
#   Version 0.0.3, 14-Nov-2022, 
#       Modified du's stderr redirection (thanks, @Pico!)
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

scriptVersion="0.0.3"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserHome=$( dscl . read /Users/"${loggedInUser}" NFSHomeDirectory | awk -F ": " '{print $2}' )
machineName=$( scutil --get LocalHostName )
volumeName=$( diskutil info / | grep "Volume Name:" | awk '{print $3,$4}' )
timestamp=$( date '+%Y-%m-%d-%H%M%S' )
diskUsageEntireVolumeTop50=$( mktemp /var/tmp/diskUsageEntireVolumeTop50.XXXX )
diskUsageUsersHomeTop50=$( mktemp /var/tmp/diskUsageUsersHomeTop50.XXXX )
outputFileNameEntireVolume="$loggedInUserHome/Desktop/$machineName-Volume-Usage-$timestamp.txt"
outputFileNameUsersHome="$loggedInUserHome/Desktop/$loggedInUser-Home-Usage-$timestamp.txt"
osVersion=$( sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
dialogApp="/usr/local/bin/dialog"
dialogWelcomeLog=$( mktemp /var/tmp/dialogWelcomeLog.XXXX )
dialogProgressLog=$( mktemp /var/tmp/dialogProgressLog.XXXX )
dialogCompleteLog=$( mktemp /var/tmp/dialogCompleteLog.XXXX )
scriptLog="${4:-"/var/tmp/org.churchofjesuschrist.log"}"
debugMode="${5:-"true"}"
estimatedTotalSeconds="${6:-"120"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Free Space Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

freeSpace=$( diskutil info / | grep -E 'Free Space|Available Space|Container Free Space' | awk -F ":\s*" '{ print $2 }' | awk -F "(" '{ print $1 }' | xargs )
freeBytes=$( diskutil info / | grep -E 'Free Space|Available Space|Container Free Space' | awk -F "(\\\(| Bytes\\\))" '{ print $2 }' )
diskBytes=$( diskutil info / | grep -E 'Total Space' | awk -F "(\\\(| Bytes\\\))" '{ print $2 }' )
freePercentage=$( echo "scale=2; ( $freeBytes * 100 ) / $diskBytes" | bc )
diskSpace="$freeSpace free ( ${freePercentage}% available )"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeTitle="Disk Usage ($scriptVersion)"
if [[ ${debugMode} == "true" ]]; then
    welcomeTitle="DEBUG MODE | $welcomeTitle"
fi
welcomeMessage="This script analyzes the following locations and outputs text files to your Desktop, which list the 50 largest directories for both:  \n- **${volumeName}** (non-system files)  \n- **${loggedInUserHome}**  \n\nPlease be patient as execution time can be in excess of ${estimatedTotalSeconds} seconds.  \n\nClick **Continue** to proceed."
welcomeIcon="/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/Internal.icns"
overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
button1text="Continue …"
button2text="Quit"
infobuttontext="KB8675309"
infobuttonaction="https://servicenow.company.com/support?id=kb_article_view&sysparm_article=${infobuttontext}"
welcomeProgressText="Waiting; click Continue to proceed"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogWelcome="$dialogApp \
--title \"$welcomeTitle\" \
--message \"$welcomeMessage\" \
--icon \"$welcomeIcon\" \
--overlayicon \"$overlayIcon\" \
--button1text \"$button1text\" \
--button2text \"$button2text\" \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--progress \
--progresstext \"$welcomeProgressText\" \
--moveable \
--ontop \
--titlefont size=22 \
--messagefont size=14 \
--iconsize 135 \
--width 700 \
--height 325 \
--commandfile \"$dialogWelcomeLog\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Progress Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progressTitle="Disk Usage ($scriptVersion)"
progressMessage="Analyzing ${volumeName} …"
progressIcon="/System/Applications/Utilities/Disk Utility.app"
progressProgressText="Initializing …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Progress Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogProgress="$dialogApp \
--title \"$progressTitle\" \
--message \"$progressMessage\" \
--icon \"$progressIcon\" \
--progress \
--progresstext \"$progressProgressText\" \
--mini \
--moveable \
--commandfile \"$dialogProgressLog\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

completeTitle="Disk Usage ($scriptVersion)"
if [[ ${debugMode} == "true" ]]; then
    completeTitle="DEBUG MODE | $completeTitle"
fi
completeMessage="### Analysis complete  \n\nPlease review the following files, which have been saved to your Desktop:  \n- **$machineName-Volume-Usage-$timestamp.txt**  \n- **$loggedInUser-Home-Usage$timestamp.txt**"
completeIcon="/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/Internal.icns"
overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
completeButton1text="Close"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogComplete="$dialogApp \
--title \"$completeTitle\" \
--message \"$completeMessage\" \
--icon \"$completeIcon\" \
--overlayicon \"$overlayIcon\" \
--button1text \"$completeButton1text\" \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--moveable \
--ontop \
--titlefont size=22 \
--messagefont size=14 \
--iconsize 135 \
--width 700 \
--height 325 \
--commandfile \"$dialogCompleteLog\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${loggedInUser}" || "${loggedInUser}" == "loginwindow" ]]; then
    echo "No user logged-in; exiting."
    exit 0
else
    uid=$(id -u "${loggedInUser}")
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
# Run command as logged-in user (thanks, @scriptingosx!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

    # shellcheck disable=SC2145
    updateScriptLog "Run \"$@\" as \"$uid\" … "
    launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Quitting …"
    updateProgressDialog "quit: "

    sleep 1
    updateScriptLog "Exiting …"

    # Remove dialogWelcomeLog
    if [[ -e ${dialogWelcomeLog} ]]; then
        updateScriptLog "Removing ${dialogWelcomeLog} …"
        rm "${dialogWelcomeLog}"
    fi

    # Remove dialogProgressLog
    if [[ -e ${dialogProgressLog} ]]; then
        updateScriptLog "Removing ${dialogProgressLog} …"
        rm "${dialogProgressLog}"
    fi

    # Remove dialogCompleteLog
    if [[ -e ${dialogCompleteLog} ]]; then
        updateScriptLog "Removing ${dialogCompleteLog} …"
        rm "${dialogCompleteLog}"
    fi

    # Remove diskUsageEntireVolumeTop50
    if [[ -e ${diskUsageEntireVolumeTop50} ]]; then
        updateScriptLog "Removing ${diskUsageEntireVolumeTop50} …"
        rm "${diskUsageEntireVolumeTop50}"
    fi

    # Remove diskUsageUsersHomeTop50
    if [[ -e ${diskUsageUsersHomeTop50} ]]; then
        updateScriptLog "Removing ${diskUsageUsersHomeTop50} …"
        rm "${diskUsageUsersHomeTop50}"
    fi

    updateScriptLog "Goodbye!"
    exit "${1}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Progress Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateProgressDialog() {
    sleep 0.35
    echo "${1}" >> "${dialogProgressLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Analyze Disk Usage for the entire volume
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function analyzeDiskUsageEntireVolume() {
    updateScriptLog "Output disk usage statistics of \"${volumeName}\" to: ${diskUsageEntireVolumeTop50}"    
    du -I System -axrg / 2>/dev/null | sort -nr | head -n 50 >> "$diskUsageEntireVolumeTop50"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Analyze Disk Usage for the user's home folder
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function analyzeDiskUsageUsersHome() {
    updateScriptLog "Output disk usage statistics of \"$loggedInUserHome\" to: ${diskUsageUsersHomeTop50}"    
    du -axrg "$loggedInUserHome" 2>/dev/null | sort -nr | head -n 50 >> "$diskUsageUsersHomeTop50"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Open Storage Information
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function openStorageInformation() {
    if [[ "${osMajorVersion}" -ge 13 ]] ; then
        runAsUser open x-apple.systempreferences:com.apple.settings.Storage
    else
        runAsUser open /System/Library/CoreServices/Applications/Storage\ Management.app
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Output Results for the entire volume
# shellcheck disable=SC2129
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function outputResultsEntireVolume() {

    updateScriptLog "Disk usage for volume \"$volumeName\" on computer \"$machineName\" "
    updateScriptLog "Report Location: $outputFileNameEntireVolume"

    echo "--------------------------------------------------------------------------------------------------" > "$outputFileNameEntireVolume"
    echo "Disk usage for volume \"$volumeName\" on computer \"$machineName\" " >> "$outputFileNameEntireVolume"
    echo "Disk Space: $diskSpace" >> "$outputFileNameEntireVolume"
    echo "Report Location: $outputFileNameEntireVolume" >> "$outputFileNameEntireVolume"
    echo "--------------------------------------------------------------------------------------------------" >> "$outputFileNameEntireVolume"
    echo " " >> "$outputFileNameEntireVolume"
    echo " " >> "$outputFileNameEntireVolume"
    echo " " >> "$outputFileNameEntireVolume"
    echo "GBs    Directory or File" >> "$outputFileNameEntireVolume"
    echo " " >> "$outputFileNameEntireVolume"
    cat "${diskUsageEntireVolumeTop50}" >> "$outputFileNameEntireVolume"
    echo " " >> "$outputFileNameEntireVolume"
    echo "--------------------------------------------------------------------------------------------------" >> "$outputFileNameEntireVolume"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Output Results or the user's home folder
# shellcheck disable=SC2129
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function outputResultsUsersHome() {

    updateScriptLog "Disk usage for \"$loggedInUserHome\" for volume \"$volumeName\" on computer \"$machineName\" "
    updateScriptLog "Report Location: $outputFileNameUsersHome"

    echo "--------------------------------------------------------------------------------------------------" > "$outputFileNameUsersHome"
    echo "Disk usage for \"$loggedInUserHome\" for volume \"$volumeName\" on computer \"$machineName\" " >> "$outputFileNameUsersHome"
    echo "Disk Space: $diskSpace" >> "$outputFileNameUsersHome"
    echo "Report Location: $outputFileNameUsersHome" >> "$outputFileNameUsersHome"
    echo "--------------------------------------------------------------------------------------------------" >> "$outputFileNameUsersHome"
    echo " " >> "$outputFileNameUsersHome"
    echo " " >> "$outputFileNameUsersHome"
    echo " " >> "$outputFileNameUsersHome"
    echo "GBs    Directory or File" >> "$outputFileNameUsersHome"
    echo " " >> "$outputFileNameUsersHome"
    cat "${diskUsageUsersHomeTop50}" >> "$outputFileNameUsersHome"
    echo " " >> "$outputFileNameUsersHome"
    echo "--------------------------------------------------------------------------------------------------" >> "$outputFileNameUsersHome"

echo "
###
# Time Machine Information
###
" >> "$outputFileNameUsersHome"

tmDestinationInfo=$( tmutil destinationinfo )

if [[ "${tmDestinationInfo}" == *"No destinations configured"* ]]; then

    echo "WARNING: Time Machine destination NOT configured." >> "$outputFileNameUsersHome"

else

    tmutil listlocalsnapshots / >> "$outputFileNameUsersHome"

    echo "
---
- Thin Local Time Machine Snapshots
---

Thinning local Time Machine snapshots can quickly free up disk space by PERMANENTLY deleting local Time Machine snapshots.

man tmutil

    thinlocalsnapshots mount_point [purge_amount] [urgency]

        Thin local Time Machine snapshots for the specified volume.

        When purge_amount and urgency are specified, tmutil will attempt (with urgency level 1-4)
        to reclaim purge_amount in bytes by thinning snapshots.

        If urgency is not specified, the default urgency will be used.



ABSOLUTELY UNSUPPORTED EXAMPLES TO BE USED AT YOUR OWN RISK:

# Free 20 GB of snapshots stored on the boot drive (with maximum urgency)
tmutil thinlocalsnapshots / 21474836480 4

# Free 36 GB of snapshots stored on the boot drive (with maximum urgency)
tmutil thinlocalsnapshots / 38654705664 4" >> "$outputFileNameUsersHome"

fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Analyze Disk Usage with Progress
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function analyzeDiskUsageWithProgress() {

    updateScriptLog "Disk Space: $diskSpace"

    updateScriptLog "Analyze Disk Usage with Progress (1 of 2)"

    eval "$dialogProgress" & sleep 0.35

    if [[ ${debugMode} == "true" ]]; then

        updateProgressDialog "title: DEBUG MODE | $progressTitle"
        updateProgressDialog "message: DEBUG MODE. Please wait for 10 seconds …"
        sleep 2
        updateProgressDialog "progresstext: Processing …"
        sleep 2
        updateProgressDialog "progresstext: Analyzing …"
        sleep 2
        updateProgressDialog "progresstext: Thinking …"
        sleep 2
        updateProgressDialog "progresstext: Almost done …"
        sleep 2
        updateProgressDialog "quit: "

    else

        ###
        # Analyze Disk Usage for entire volume
        ###

        updateScriptLog "Analyze Disk Usage for \"${volumeName}\""
        updateProgressDialog "message: Analyze Disk Usage for \"${volumeName}\""
        updateProgressDialog "progress: 0"
        updateProgressDialog "progresstext: Initializing …"

        SECONDS="0"
        analyzeDiskUsageEntireVolume &
        updateProgressDialog "progresstext: Analyzing …"

        while [[ -n $(pgrep -x "du|sort|head") ]]; do

            progressPercentage=$( echo "scale=2 ; ( $SECONDS / $estimatedTotalSeconds ) * 100" | bc | sed 's/\.00$//')
            updateProgressDialog "progress: ${progressPercentage}"
            updateProgressDialog "progresstext: Analyzing: ${progressPercentage}%"

        done

        updateProgressDialog "progress: 100"
        updateProgressDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
        updateScriptLog "Elapsed Time for \"${volumeName}\": $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
        outputResultsEntireVolume



        ###
        # Analyze Disk Usage for user's home directory
        ###

        updateScriptLog "Analyze Disk Usage with Progress (2 of 2)"
        updateScriptLog "Analyze Disk Usage for \"${loggedInUserHome}\""
        updateProgressDialog "message: Analyze Disk Usage for \"${loggedInUserHome}\""
        updateProgressDialog "progress: 0"
        updateProgressDialog "progresstext: Initializing …"

        SECONDS="0"
        estimatedTotalSecondsUsersHome=$( echo "scale=2 ; ( $estimatedTotalSeconds * 0.6 )" | bc )
        analyzeDiskUsageUsersHome &
        updateProgressDialog "progresstext: Analyzing …"

        while [[ -n $(pgrep -x "du|sort|head") ]]; do

            progressPercentage=$( echo "scale=2 ; ( $SECONDS / $estimatedTotalSecondsUsersHome ) * 100" | bc | sed 's/\.00$//')
            updateProgressDialog "progress: ${progressPercentage}"
            updateProgressDialog "progresstext: Analyzing: ${progressPercentage}%"

        done

        updateProgressDialog "progress: 100"
        updateProgressDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
        updateScriptLog "Elapsed Time for \"${loggedInUserHome}\": $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

        outputResultsUsersHome

        updateProgressDialog "quit: "

    fi

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
    updateScriptLog "\n\n###\n# DEBUG MODE | Disk Usage (${scriptVersion})\n###\n"
else
    updateScriptLog "\n\n###\n# Disk Usage (${scriptVersion})\n###\n"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    echo "macOS ${osMajorVersion} installed; proceeding ..."
else
    echo "macOS ${osMajorVersion} installed; exiting"
    jamfDisplayMessage "macOS ${osMajorVersion} installed. Please use the previous version of this script. Exiting."
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Welcome Dialog …"

eval "$dialogWelcome"

welcomeReturncode=$?

case ${welcomeReturncode} in

    0)  ## Process exit code 0 scenario here
        updateScriptLog "${loggedInUser} clicked ${button1text};"
        analyzeDiskUsageWithProgress
        eval "$dialogComplete" 
        # shellcheck disable=SC2086
        if [[ -f "${outputFileNameEntireVolume}" || "${outputFileNameUsersHome}" ]]; then
            runAsUser open $outputFileNameEntireVolume
            runAsUser open $outputFileNameUsersHome
            openStorageInformation
            quitScript "0"
        else
            updateScriptLog "Something went sideways; couldn't find ${outputFileNameEntireVolume} or ${outputFileNameUsersHome}"
            quitScript "1"
        fi
        ;;

    2)  ## Process exit code 2 scenario here
        updateScriptLog "${loggedInUser} clicked ${button2text};"
        quitScript "0"
        ;;

    3)  ## Process exit code 3 scenario here
        updateScriptLog "${loggedInUser} clicked ${infobuttontext};"
        ;;

    4)  ## Process exit code 4 scenario here
        updateScriptLog "${loggedInUser} allowed timer to expire;"
        quitScript "1"
        ;;

    *)  ## Catch all processing
        updateScriptLog "Something else happened; Exit code: ${welcomeReturncode};"
        quitScript "1"
        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "End-of-line."

quitScript "0"