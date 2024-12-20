#!/bin/bash

####################################################################################################
#
#   swiftDialog sysdiagnose Progress
#   https://snelson.us/2022/10/user-friendly-sysdiagnose/
#
#   Purpose: Help your users easily provide detailed logs to AppleCare Enterprise Support
#
####################################################################################################
#
# HISTORY
#
# Version 1.0.0, 25-Mar-2015, Dan K. Snelson (@dan-snelson)
#   Original version
#
# Version 1.1.0, 14-Nov-2017, Dan K. Snelson (@dan-snelson)
#   Updates for client-side functions
#
# Version 1.2.0, 05-Jan-2020, Dan K. Snelson (@dan-snelson)
#   Updated output filename to better match Apple's default
#
# Version 1.3.0, 15-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Near-complete re-write to leverage swiftDialog
#
# Version 1.3.1, 17-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Updated `sed` regex (thanks, @Nick Koval!)
#   Updated `updateScriptLog` function (thanks, @tlark!)
#
# Version 1.3.2, 09-Sep-2023, Dan K. Snelson (@dan-snelson)
#   Updated `dialogURL`
#
# Version 1.3.3, 12-Oct-2024, Dan K. Snelson (@dan-snelson)
#   Updated for macOS 15.0.1
#
# Version 1.4.0, 17-Oct-2024, Dan K. Snelson (@dan-snelson)
#   Manually include system and user /Library/Logs/DiagnosticReports
#
# Version 1.4.1, 20-Dec-2024, Dan K. Snelson (@dan-snelson)
#   - Updates for swiftDialog 2.5.5
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/

# Script Version
scriptVersion="1.4.1"

# Client-side Log
scriptLog="/var/log/org.churchofjesuschrist.log"

# Progress Directory
sysdiagnoseProgressDirectory="/var/tmp/sysdiagnoseProgress"

# Timestamp
timestamp=$( date '+%Y.%m.%d_%H-%M-%S' )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: AppleCare Enterprise Case Number
caseNumber="${4:-"86753099"}"

# Parameter 5: GigaFiles URL
gigafilesLink="${5:-"https://gigafiles.apple.com/data-capture/edc"}"

# Parameter 6: Estimated Total Seconds
estimatedTotalSeconds="${6:-"240"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readabale Name
humanReadableScriptName="sysdiagnose with Progress"

# Organization's Script Name
organizationScriptName="SDwP"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Serial Number and Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

serialNumber=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
osVersion=$( sw_vers -productVersion )
osVersionExtra=$( sw_vers -productVersionExtra ) 
osBuild=$( sw_vers -buildVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )

# Report RSR sub version if applicable
if [[ -n $osVersionExtra ]] && [[ "${osMajorVersion}" -ge 13 ]]; then osVersion="${osVersion} ${osVersionExtra}"; fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logged-in User Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print ( $0 == toupper($0) ? toupper(substr($0,1,1))substr(tolower($0),2) : toupper(substr($0,1,1))substr($0,2) )}' )
loggedInUserID=$( id -u "${loggedInUser}" )
loggedInUserGroupMembership=$( id -Gn "${loggedInUser}" )
loggedInUserHome=$( dscl . read /Users/"${loggedInUser}" NFSHomeDirectory | awk -F ": " '{print $2}' )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog binary (and enable swiftDialog's `--verbose` mode with script's operationMode)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# swiftDialog Binary Path
dialogBinary="/usr/local/bin/dialog"

# swiftDialog Minimum Required Version
swiftDialogMinimumRequiredVersion="2.5.5.4802"

# swiftDialog Command Files
dialogWelcomeLog=$( mktemp /var/tmp/dialogWelcomeLog.XXX )
dialogProgressLog=$( mktemp /var/tmp/dialogProgressLog.XXX )
dialogCompleteLog=$( mktemp /var/tmp/dialogCompleteLog.XXX )
sysdiagnoseExecutionLog=$( mktemp /var/tmp/sysdiagnoseExecutionLog.XXX )

# Set Permissions on Dialog Command Files
chmod -vv 644 "${dialogWelcomeLog}" | tee -a "${scriptLog}"
chmod -vv 644 "${dialogProgressLog}" | tee -a "${scriptLog}"
chmod -vv 644 "${dialogCompleteLog}" | tee -a "${scriptLog}"
chmod -vv 644 "${sysdiagnoseExecutionLog}" | tee -a "${scriptLog}"

# The total number of steps for the progress bar, plus one (i.e., updateWelcomeDialog "progress: increment")
progressSteps="18"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="AppleCare Enterprise Support Case No. ${caseNumber}"
message="### Capture & Upload System-wide logs  \n\nThis script gathers the following system diagnostic information helpful in AppleCare Enterprise Support investigating system performance issues:  \n\n- A spindump of the system  \n- Several seconds of _fs_usage_ ouput  \n- Several seconds of _top_ output  \n- Data about kernel zones  \n- Status of loaded kernel extensions  \n- Resident memory usage of user processes  \n- Recent system logs  \n- A System Profiler report  \n- Recent crash reports  \n- Disk usage information  \n- I/O Kit registry information  \n- Network status  \n\nPlease click **Continue** to proceed."
icon="https://ics.services.jamfcloud.com/icon/hash_4a2fef8d10a0e9ab126cfbafd4950615a0dc647e4e300493787e504aefebf62a"
overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
button1text="Continue …"
button2text="Quit"
infobuttontext="KB8675309"
infobuttonaction="https://servicenow.company.com/support?id=kb_article_view&sysparm_article=${infobuttontext}"
welcomeProgressText="Waiting; click Continue to proceed"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSysdiagnoseWelcome="$dialogBinary \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--button1text \"$button1text\" \
--button2text \"$button2text\" \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--progress \
--progresstext \"$welcomeProgressText\" \
--moveable \
--titlefont size=22 \
--messagefont size=13 \
--width 700 \
--height 500 \
--commandfile \"$dialogWelcomeLog\" "

# --overlayicon \"$overlayIcon\" \



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Progress Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="AppleCare Enterprise Support Case No. ${caseNumber}"
message="Capturing logs …"
icon="https://ics.services.jamfcloud.com/icon/hash_4a2fef8d10a0e9ab126cfbafd4950615a0dc647e4e300493787e504aefebf62a"
progressProgressText="Initializing …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Progress Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSysdiagnoseProgress="$dialogBinary \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress \
--progresstext \"$progressProgressText\" \
--mini \
--moveable \
--commandfile \"$dialogProgressLog\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="AppleCare Enterprise Support Case No. ${caseNumber}"
message="### Log gathering complete  \n\nPlease complete the following steps to provide your logs to  \nAppleCare Enterprise Support:  \n1. Click **Upload** to open Safari to the Apple Support site for this case  \n1. Login with your Apple Account\n1. Add the file listed below from your Desktop  \n\n- **sysdiagnose_${serialNumber}_${timestamp}.tar.gz**\n- **${serialNumber}_System_DiagnosticReports-${timestamp}.zip**\n- **${serialNumber}_User_DiagnosticReports-${timestamp}.zip**"
icon="https://ics.services.jamfcloud.com/icon/hash_4a2fef8d10a0e9ab126cfbafd4950615a0dc647e4e300493787e504aefebf62a"
overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
uploadButton1text="Upload"
infobuttontext="KB8675309"
infobuttonaction="https://servicenow.company.com/support?id=kb_article_view&sysparm_article=${infobuttontext}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSysdiagnoseUpload="$dialogBinary \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--overlayicon \"$overlayIcon\" \
--button1text \"$uploadButton1text\" \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--moveable \
--titlefont size=22 \
--messagefont size=13 \
--width 725 \
--height 450 \
--commandfile \"$dialogCompleteLog\" "



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

function debug() {
    if [[ "$operationMode" == "debug" ]]; then
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
# Run command as logged-in user (thanks, @scriptingosx!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

    updateScriptLog "Run \"$@\" as \"$uid\" … "
    launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# sysdiagnose with progress
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function sysdiagnoseWithProgress() {

    eval "$dialogSysdiagnoseProgress" &

    SECONDS="0"

    updateScriptLog "Starting sysdiagnose …"

    echo -ne '\n' | sysdiagnose -u -A sysdiagnose_"${serialNumber}"_"${timestamp}" -f "$sysdiagnoseProgressDirectory" -V / | cat > "$sysdiagnoseExecutionLog" &

    sleep 0.5

    updateProgressDialog "progress: 1"

    while pgrep -q -x "sysdiagnose"; do

        progressPercentage=$( echo "scale=2 ; ( $SECONDS / $estimatedTotalSeconds ) * 100" | bc )
        updateProgressDialog "progress: ${progressPercentage}"

        sysdialogProgressText=$( tail -n1 "$sysdiagnoseExecutionLog" | sed -e 's|Executing container: ||g' -e 's|^[.)]|Processing …|g' -Ee 's|/?.*/[^/]*\.tmp||g' )
        updateProgressDialog "progresstext: ${sysdialogProgressText}"
        updateScriptLog "${sysdialogProgressText}"

    done

    logComment "Compress System DiagnosticReports …"
    zip -rjq "$sysdiagnoseProgressDirectory/${serialNumber}_System_DiagnosticReports-${timestamp}.zip" "/Library/Logs/DiagnosticReports"

    logComment "Compress User DiagnosticReports …"
    zip -rjq "$sysdiagnoseProgressDirectory/${serialNumber}_User_DiagnosticReports-${timestamp}.zip" "${loggedInUserHome}/Library/Logs/DiagnosticReports"

    updateProgressDialog "progress: 98"
    updateProgressDialog "progresstext: Moving files …"

    updateScriptLog "Move sysdiagnose file to user's Desktop …"
    mv -v "$sysdiagnoseProgressDirectory/sysdiagnose_${serialNumber}_${timestamp}.tar.gz" "${loggedInUserHome}/Desktop/"

    updateScriptLog "Move System DiagnosticReports file to user's Desktop …"
    mv -v "$sysdiagnoseProgressDirectory/${serialNumber}_System_DiagnosticReports-${timestamp}.zip" "${loggedInUserHome}/Desktop/"

    updateScriptLog "Move User DiagnosticReports file to user's Desktop …"
    mv -v "$sysdiagnoseProgressDirectory/${serialNumber}_User_DiagnosticReports-${timestamp}.zip" "${loggedInUserHome}/Desktop/"

    updateProgressDialog "progress: 100"
    updateProgressDialog "progresstext: Complete! Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
    logComment "Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

    sleep 3

    updateProgressDialog "quit: "

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# sysdiagnose for older OSes
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function sysdiagnoseForOlderOSes() {

    jamfDisplayMessage "Please be patient while logs are gathered …"

    updateScriptLog "Run sysdiagnose for macOS ${osMajorVersion} …"
    echo -ne '\n' | sysdiagnose -u -A sysdiagnose_"${serialNumber}"_"${timestamp}" -f /var/tmp/ -V /

    updateScriptLog "Move output to user's Desktop …"
    mv -v /var/tmp/sysdiagnose_"${serialNumber}"_"${timestamp}".tar.gz "${loggedInUserHome}"/Desktop/

    # I/O Pause
    sleep 3

    updateScriptLog "Inform user …"
    message="Log Gathering Complete for Case No. $caseNumber

Your computer logs have been saved
to your Desktop as:
sysdiagnose_${serialNumber}_${timestamp}.tar.gz

Please upload the file to AppleCare Enterprise Support:
$gigafilesLink

"
    jamfDisplayMessage "${message}"

    # runAsUser "open -R ${loggedInUserHome}/Desktop/sysdiagnose_${serialNumber}_${timestamp}.tar.gz"
    open -R "${loggedInUserHome}/Desktop/sysdiagnose_${serialNumber}_${timestamp}.tar.gz"

    updateScriptLog "Saved as: sysdiagnose_${serialNumber}_${timestamp}.tar.gz"

    quitScript "0"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Quitting …"
    updateProgressDialog "quit: "

    sleep 1
    updateScriptLog "Exiting …"

    # brutal hack - need to find a better way
    killall tail

    # Remove dialogWelcomeLog
    if [[ -e ${dialogWelcomeLog} ]]; then
        updateScriptLog "Removing ${dialogWelcomeLog} …"
        rm "${dialogWelcomeLog}"
    fi

    # Remove sysdiagnoseExecutionLog
    if [[ -e ${sysdiagnoseExecutionLog} ]]; then
        updateScriptLog "Removing ${sysdiagnoseExecutionLog} …"
        rm "${sysdiagnoseExecutionLog}"
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

    # Remove sysdiagnoseProgressDirectory
    if [[ -d ${sysdiagnoseProgressDirectory} ]]; then
        updateScriptLog "Removing ${sysdiagnoseProgressDirectory} …"
        rm -R "${sysdiagnoseProgressDirectory}"
    fi

    updateScriptLog "Goodbye!"
    exit "${1}"

}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Progress Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateProgressDialog() {
    sleep 0.1
    echo "${1}" >> "${dialogProgressLog}"
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
        preFlight "Created specified scriptLog: ${scriptLog}"
    else
        fatal "Unable to create specified scriptLog '${scriptLog}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    preFlight "Specified scriptLog '${scriptLog}' exists; writing log entries to it"
fi




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# Operation Mode: ${operationMode}\n###\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Validate swiftDialog is installed"
dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Create sysdiagnose Temporary Directory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Create sysdiagnose Temporary Directory"

if [[ ! -d "${sysdiagnoseProgressDirectory}" ]]; then
    mkdir -p "${sysdiagnoseProgressDirectory}"
else
    rm -Rf "${sysdiagnoseProgressDirectory}"
    mkdir -p "${sysdiagnoseProgressDirectory}"
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
# Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    echo "macOS ${osMajorVersion} installed; proceeding ..."
else
    echo "macOS ${osMajorVersion} installed; executing sysdiagnose sans progress …"
    sysdiagnoseForOlderOSes
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Welcome Dialog …"

eval "$dialogSysdiagnoseWelcome"

welcomeReturncode=$?

case ${welcomeReturncode} in

    0)  ## Process exit code 0 scenario here
        updateScriptLog "${loggedInUser} clicked ${button1text};"
        sysdiagnoseWithProgress
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
# Create Upload Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Upload Dialog …"

eval "$dialogSysdiagnoseUpload"

uploadReturncode=$?

case ${uploadReturncode} in

    0)  ## Process exit code 0 scenario here
        updateScriptLog "${loggedInUser} clicked ${uploadButton1text};"

        updateScriptLog "Open upload link … "
        runAsUser open -a /Applications/Safari.app "$gigafilesLink"

        sleep 30

        updateScriptLog "Reveal sysdiagnose in Finder … "
        runAsUser open -R "${loggedInUserHome}/Desktop/sysdiagnose_${serialNumber}_${timestamp}.tar.gz"

        quitScript "0"

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
        updateScriptLog "Something else happened; Exit code: ${uploadReturncode};"
        quitScript "1"
        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "0"