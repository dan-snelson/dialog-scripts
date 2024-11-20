#!/bin/zsh --no-rcs
# shellcheck shell=bash

setopt KSH_ARRAYS

####################################################################################################
#
# ABOUT
#
# MDM Migrate
#
####################################################################################################
#
# HISTORY
#
# Version 1.0.0, 17-Apr-2024, Dan K. Snelson (@dan-snelson)
#   - Initial testing release
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Global
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Script Version
scriptVersion="1.0.0b2"

# Client-side Log
scriptLog="/var/log/org.churchofjesuschrist.log"

# Jamf Pro API URL
apiURL=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Operation Mode [ debug | dry-run | self-migrate ]
operationMode="${4:-"debug"}"

# Parameter 5: Jamf Pro API Username
apiUser="${5:-"Jamf Pro API Username"}"

# Parameter 6: Jamf Pro API Encrypted Password (generated from Encrypt Password)
apiPasswordEncrypted="${6:-"Jamf Pro API Encrypted Password"}"

# Parameter 7: Estimated Duration (in minutes)
estimatedTotalMinutes="${7:-"20"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readable Name
humanReadableScriptName="MDM Migrate"

# Abbreviated Script Name
organizationScriptName="MDM-M"

# Extension Attribute Name
eaName="MDM Migration"

# Apple Business Manager Organization Name (i.e., "The Church of Jesus Christ of Latter-day Saints")
abmOrganizationName="The Church of Jesus Christ of Latter-day Saints"

# Organizational client-side scripts (Must previously exist; Include trailing forward slash)
temporaryPath="/path/to/client/side/scripts/"

# Salt (generated from Encrypt Password)
Salt="Salt goes here"

# Passphrase (generated from Encrypt Password)
Passphrase="Passphrase goes here"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osVersion=$( sw_vers -productVersion )
osVersionExtra=$( sw_vers -productVersionExtra ) 
osBuild=$( sw_vers -buildVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
if [[ -n $osVersionExtra ]] && [[ "${osMajorVersion}" -ge 13 ]]; then osVersion="${osVersion} ${osVersionExtra}"; fi
serialNumber=$( ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}' )
modelName=$( /usr/libexec/PlistBuddy -c 'Print :0:_items:0:machine_name' /dev/stdin <<< "$(system_profiler -xml SPHardwareDataType)" )
computerName=$( scutil --get ComputerName )
localHostName=$( scutil --get LocalHostName )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Uptime Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

timestamp="$( date '+%Y-%m-%d-%H%M%S' )"
lastBootTime=$( sysctl kern.boottime | awk -F'[ |,]' '{print $5}' )
currentTime=$( date +"%s" )
upTimeRaw=$((currentTime-lastBootTime))
upTimeMin=$((upTimeRaw/60))
upTimeHours=$((upTimeMin/60))
uptimeDays=$( uptime | awk '{ print $4 }' | sed 's/,//g' )
uptimeNumber=$( uptime | awk '{ print $3 }' | sed 's/,//g' )

if [[ "${uptimeDays}" = "day"* ]]; then
    if [[ "${uptimeNumber}" -gt 1 ]]; then
        uptimeHumanReadable="${uptimeNumber} (days)"
    else
        uptimeHumanReadable="${uptimeNumber} (day)"
    fi
elif [[ "${uptimeDays}" == "mins"* ]]; then
    uptimeHumanReadable="${uptimeNumber} (mins)"
else
    uptimeHumanReadable="${uptimeNumber} (HH:MM)"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logged-in User Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print ( $0 == toupper($0) ? toupper(substr($0,1,1))substr(tolower($0),2) : toupper(substr($0,1,1))substr($0,2) )}' )
loggedInUserID=$( id -u "${loggedInUser}" )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# swiftDialog Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

swiftDialogMinimumRequiredVersion="2.5.4.4793"
dialogBinary="/usr/local/bin/dialog"
dialogVersion=$( "${dialogBinary}" --version )
dialogWelcomeLog=$( mktemp /var/tmp/dialogWelcomeLog.XXXX )
welcomeJSONFile=$( mktemp -u /var/tmp/welcomeJSONFile.XXX )
dialogMigrationLog=$( mktemp /var/tmp/dialogMigrationLog.XXXX )
dialogCompleteLog=$( mktemp /var/tmp/dialogCompleteLog.XXXX )

welcomeBannerImage="https://img.freepik.com/free-vector/green-abstract-geometric-wallpaper_52683-29623.jpg" # Image by pikisuperstar on Freepik

welcomeBannerImageFileName=$( echo ${welcomeBannerImage} | awk -F '/' '{print $NF}' )
curl -L --location --silent "$welcomeBannerImage" -o "/var/tmp/${welcomeBannerImageFileName}"
welcomeBannerImage="/var/tmp/${welcomeBannerImageFileName}"
bannerImage="/var/tmp/${welcomeBannerImageFileName}"

# Create `overlayicon` from Self Service's custom icon (thanks, @meschwartz!)
xxd -p -s 260 "$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path)"/Icon$'\r'/..namedfork/rsrc | xxd -r -p > /var/tmp/overlayicon.icns
overlayicon="/var/tmp/overlayicon.icns"



# # #
# Reflect Debug Mode in `scriptVersion`
# # #

case ${operationMode} in
    "debug"     ) scriptVersion="DEBUG MODE | Dialog: v${dialogVersion} • ${humanReadableScriptName}: v${scriptVersion}" ;;
    "dry-run"   ) scriptVersion="v${scriptVersion} [DRY-RUN]" ;;
esac



# # #
# IT Support Variables
# # #

supportTeamName="Help Desk"
supportTeamPhone="+1 (801) 555-1212"
supportTeamEmail="rescueme@domain.com"
supportTeamWebsite="https://support.domain.com"
supportTeamHyperlink="[${supportTeamWebsite}](${supportTeamWebsite})"
supportKB="KB8675309"
supportKBURL="[${supportKB}](https://servicenow.domain.com/support?id=kb_article_view&sysparm_article=${supportKB})"



# # #
# Welcome Dialog Variables
# # #

# Title
welcomeTitle="Happy $( date +'%A' ), ${loggedInUserFirstname}! Let‘s migrate your ${modelName}"

# Icon (based on whether the Mac is a desktop or laptop)
if system_profiler SPPowerDataType | grep -q "Battery Power"; then
    welcomeIcon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
    welcomeIcon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi

# Button 1 Text
button1text="Continue …"

# Button 2 Text
button2text="Quit"

# Info Button Text
infobuttontext="${supportKB}"

# Info Button Action
infobuttonaction="https://servicenow.churchofjesuschrist.org/support?id=kb_article_view&sysparm_article=${infobuttontext}"

# Welcome Message (with variables)
welcomeMessage="### This script migrates your Mac from its current Mobile Device Management (MDM) server to a new MDM server<br><br>After careful consideration, the Client-side Platforms Solution has made the decision to change macOS MDM vendors and a **one-time migration is required by DD-MMM-2024**. (Please see $supportKBURL for detailed instructions.)<br><br>Please be patient as execution time can be in excess of ${estimatedTotalMinutes} minutes. Once completed, an **immediate restart** will be required.<br><br>Click **Continue** to proceed."

if [[ "${upTimeHours}" -gt 24 ]]; then
    welcomeMessage+="<br><br><br>### Excessive Uptime<br>Your Mac was last rebooted ${uptimeHumanReadable} ago.<br>Please manually restart before proceeding."
fi

# Progress Text (with Operation Mode)
if [[ "${operationMode}" == "self-migrate" ]]; then
    welcomeProgressText="Waiting; click Continue to proceed"
else
    welcomeProgressText="Operation Mode: ${operationMode} | Waiting; click Continue to proceed"
fi

# Info Box
infobox="**User:**<br>• **Name:** ${loggedInUserFullname}<br>• **Username:** ${loggedInUser}<br>• **ID:** ${loggedInUserID}<br><br>**Computer:**<br>• **Serial Number:** ${serialNumber}<br><br>**Last Restart:**<br>• ${uptimeHumanReadable}"

# Help Message
helpmessage="**${supportTeamName}:**<br>• **Phone:** ${supportTeamPhone}<br>• **Email:** ${supportTeamEmail}<br>• **Web:** ${supportTeamHyperlink}<br>• **Article:** ${supportKBURL}<br><br>**User Information:**<br>• **Name:** ${loggedInUserFullname}<br>• **Username:** ${loggedInUser}<br>• **ID:** ${loggedInUserID}<br><br>**Computer Information:**<br>• **Serial Number:** ${serialNumber}<br>• **Operating System:** ${osVersion} (${osBuild})<br>• **Computer Name:** ${computerName}<br>• **Model Name:** ${modelName}<br>• **Local Host Name:** ${localHostName}<br>• **Last Restart:** ${uptimeHumanReadable}<br><br>**Environment Information:**<br>• **Dialog:** ${dialogVersion}<br>• **Started:** ${timestamp} <br>• **Script Version:** ${scriptVersion} <br>• **Operation Mode:** ${operationMode}"




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome" JSON Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeJSON='{
    "bannerimage" : "'"${welcomeBannerImage}"'",
    "bannertext" : "'"${welcomeTitle}"'",
    "titlefont" : "shadow=true, size=36",
    "message" : "'"${welcomeMessage}"'",
    "icon" : "'"${welcomeIcon}"'",
    "iconsize" : "150",
    "overlayicon" : "'"${overlayicon}"'",
    "infobox" : "'"${infobox}"'",
    "button1text" : "'"${button1text}"'",
    "button2text" : "'"${button2text}"'",
    "infobuttontext" : "'"${infobuttontext}"'",
    "infobuttonaction" : "'"${infobuttonaction}"'",
    "infotext" : "'"${scriptVersion}"'",
    "progress" : "true",
    "progresstext" : "'"${welcomeProgressText}"'",
    "helpmessage" : "'"${helpmessage}"'",
    "commandfile" : "'"${welcomeJSONFile}"'",
    "ontop" : "true",
    "blurscreen" : "true",
    "moveable" : "false",
    "messagefont" : "size=14",
    "quitkey" : "k",
    "quitinfo" : "true",
    "textfield" : [
        {   "title" : "Password",
            "secure" : true,
            "required" : true,
            "prompt" : "Please enter the password you use to login to your Mac"
        }
    ],
    "height" : "700"
}'



# # #
# Migration Dialog Title, Message and Icon
# # #

migrationTitle="Migrating ${loggedInUserFirstname}‘s ${modelName}"
migrationMessage="Please wait while the following actions are completed"
migrationIcon="/System/Applications/Utilities/Migration Assistant.app"
migrationProgressText="Initializing migration …"
migrationInfotext="${humanReadableScriptName} (${scriptVersion})"



# # #
# Migration Dialog Settings and Features
# # #

dialogMigration="$dialogBinary \
--bannerimage \"${bannerImage}\" \
--bannertext \"${migrationTitle}\" \
--title \"$migrationTitle\" \
--message \"$migrationMessage\" \
--icon \"$migrationIcon\" \
--overlayicon \"$overlayicon\" \
--infobox \"${infobox}\" \
--listitem \"Dynamically building required steps; please wait …\" \
--button1text \"Wait\" \
--button1disabled \
--progress \
--progresstext \"$migrationProgressText\" \
--infotext \"$scriptVersion\" \
--helpmessage \"$helpmessage\" \
--titlefont size=28 \
--messagefont 'size=14' \
--height '700' \
--position 'centre' \
--ontop \
--quitkey K \
--blurscreen \
--commandfile \"$dialogMigrationLog\" "

# --presentation \

# # #
# Migration steps to execute (inspired by @smithjw)
# # #

migrationJSON='
{
    "steps": [
        {
            "listitem": "Current MDM Server Connectivity",
            "subtitle": "Confirm this Mac can reach the current MDM server",
            "icon": "SF=1.square.fill",
            "progresstext": "Confirming this Mac can reach the current MDM server",
            "commandList": [
                {
                    "command": "Current MDM Server Connectivity",
                    "validation": "The JSS is available."
                }
            ]
        },
        {
            "listitem": "New MDM Server Connectivity",
            "subtitle": "Confirm this Mac can reach the new MDM server",
            "icon": "SF=2.square.fill",
            "progresstext": "Confirming this Mac can reach the new MDM server",
            "commandList": [
                {
                    "command": "New MDM Server Connectivity",
                    "validation": "Yes"
                }
            ]
        },
        {
            "listitem": "Device Eligibility",
            "subtitle": "Confirm this Mac is eligible for automated migration",
            "icon": "SF=3.square.fill",
            "progresstext": "Confirming this Mac is eligible for automated migration",
            "commandList": [
                {
                    "command": "Confirm an Apple Business Manager Record",
                    "validation": "Yes"
                }
            ]
        },
        {
            "listitem": "Current MDM Server Profile",
            "subtitle": "Confirm this Mac is enrolled with the current MDM server",
            "icon": "SF=4.square.fill",
            "progresstext": "Confirming this Mac is enrolled with the expected MDM server",
            "commandList": [
                {
                    "command": "Confirm Jamf Pro MDM Profile",
                    "validation": "Yes"
                }
            ]
        },
        {
            "listitem": "Initial Configuration Profile Check",
            "subtitle": "Confirm Configuration Profiles are installed",
            "icon": "SF=5.square.fill",
            "progresstext": "Confirming Configuration Profiles are installed on this Mac",
            "commandList": [
                {
                    "command": "Confirm Configuration Profiles",
                    "validation": "Yes"
                }
            ]
        },
        {
            "listitem": "Un-enroll from current MDM Server",
            "subtitle": "Attempt to un-enroll this Mac from its current MDM server",
            "icon": "SF=6.square.fill",
            "progresstext": "Attempting to un-enroll this Mac from its current MDM server",
            "commandList": [
                {
                    "command": "Remove Jamf Pro Configuration Profile via the API",
                    "validation": "No"
                }
            ]
        },
        {
            "listitem": "Secondary Configuration Profile Check",
            "subtitle": "Confirm Configuration Profiles have been removed",
            "icon": "SF=7.square.fill",
            "progresstext": "Confirming Configuration Profiles have been removed from this Mac",
            "commandList": [
                {
                    "command": "Confirm Configuration Profiles",
                    "validation": "No"
                }
            ]
        },
        {
            "listitem": "Remove Current MDM Server Supporting Files",
            "subtitle": "Removing the current MDM server’s supporting files",
            "icon": "SF=8.square.fill",
            "progresstext": "Removing the current MDM server’s supporting files",
            "commandList": [
                {
                    "command": "Remove Jamf Pro Framework",
                    "validation": "No"
                }
            ]
        },
        {
            "listitem": "Grant Administrative Rights",
            "subtitle": "Temporarily granting Administrative Rights",
            "icon": "SF=9.square.fill",
            "progresstext": "Temporarily granting Administrative Rights",
            "commandList": [
                {
                    "command": "Grant User Administrative Rights",
                    "validation": "Admin"
                }
            ]
        },
        {
            "listitem": "Remove BeyondTrust Endpoint Privilege Management",
            "subtitle": "Temporarily removing EPM software",
            "icon": "SF=10.square.fill",
            "progresstext": "Removing BeyondTrust Endpoint Privilege Management",
            "commandList": [
                {
                    "command": "Remove BeyondTrust Privilege Management",
                    "validation": "Stopped"
                }
            ]
        },
        {
            "listitem": "Enroll in new MDM Server",
            "subtitle": "Enroll this Mac in the new MDM server",
            "icon": "SF=11.square.fill",
            "progresstext": "Enroll this Mac in the new MDM server",
            "commandList": [
                {
                    "command": "Enroll in new MDM Server",
                    "validation": "None"
                }
            ]
        }        
    ]
}
'



# # #
# Complete Dialog Title, Message and Icon
# # #

completeTitle="Thank you, ${loggedInUserFirstname}!<br>Migration complete!"
completeMessage="### Migration complete<br>\nPlease restart."
completeIcon="/System/Applications/Utilities/Migration Assistant.app"
completeButton1text="Restart"



# # #
# Complete Dialog Settings and Features
# # #

dialogComplete="$dialogBinary \
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
--height 500 \
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
    echo "${organizationScriptName} ${scriptVersion}: $( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
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
    sidewaysExit
    # exit 1
}

function quitOut(){
    updateScriptLog "[QUIT]            ${1}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Output Line Number in Debug Mode
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function outputLineNumberInDebugMode() {
    if [[ "${operationMode}" != *"migrate" ]]; then 
        updateScriptLog "### ${organizationScriptName} ${operationMode} mode: Line No. ${funcfiletrace##*:} ###"
    fi
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

    # Output Line Number in `verbose` Debug Mode
    if [[ "${debugMode}" == "verbose" ]]; then preFlight "# # # SETUP YOUR MAC VERBOSE DEBUG MODE: Line No. ${LINENO} # # #" ; fi

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
# Update Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateWelcomeDialog() {
    # sleep 0.35
    echo "${1}" >> "${welcomeJSONFile}"
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Migration Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateMigrationDialog() {
    # sleep 0.35
    echo "${1}" >> "${dialogMigrationLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Complete Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateCompleteDialog() {
    # sleep 0.35
    echo "${1}" >> "${dialogCompleteLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Decrypt Password
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function decryptPassword() {
    echo "${1}" | openssl enc -aes256 -md sha256 -d -a -A -S "${2}" -k "${3}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate User's Password
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function checkPassword() {
    password="$1"
    passwordTest=$( /usr/bin/dscl /Search -authonly "$loggedInUser" "$password" )

    if [[ -z "$passwordTest" ]]; then
        info "The password entered is the correct login password for $loggedInUser."
        passwordCheck="pass"
    else
        error "The password entered is NOT the login password for $loggedInUser."
        passwordCheck="fail"
        /usr/bin/afplay "/System/Library/Sounds/Basso.aiff"
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pause Script
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function pause() {
    info "Pause script for ${1} seconds …"
    sleep "${1}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for running processes (supplied as Parameter 1)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function procesStatus() {

    processToCheck="${1}"

    info "Checking process ${processToCheck} …"

    processStatus=$( pgrep -x "${processToCheck}" )
    if [[ -n ${processStatus} ]]; then
        processCheckResult+="'${processToCheck}' running; "
        logComment "'${processToCheck}' running"
    else
        processCheckResult+="'${processToCheck}' stopped; "
        logComment "'${processToCheck}' stopped"
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Command (i.e., expected "validation" and "commandResult")
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validateCommand() {

    # TO DO: Muliple attempts???

    validation="${1}"
    commandResult="${2}"

    if [[ "${validation}" == "${commandResult}" ]]; then
        updateMigrationDialog "listitem: index: $i, status: success, statustext: Success"
    else
        updateMigrationDialog "listitem: index: $i, status: fail, statustext: Failed"
        commandFailure="failure"
        exitCode="1"
        commandFailures+="• $listitem<br>"
        if [[ "${operationMode}" == *"migrate" ]]; then
            fatal "The '$listitem' failed; exiting"
        else
            logComment "Operation Mode: ${operationMode}; ignoring failure"
        fi
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Sideways Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function sidewaysExit() {

    notice "Failures detected"
    updateMigrationDialog "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
    updateMigrationDialog "progresstext: Failures detected. Please click Continue for troubleshooting information."
    updateMigrationDialog "button1text: Continue …"
    updateMigrationDialog "button1: enable"
    updateMigrationDialog "progress: reset"

    # Wait for user-acknowledgment due to detected failure
    wait

    updateMigrationDialog "quit:"

    eval "$dialogComplete" & sleep 0.3

    updateCompleteDialog "title: Sorry ${loggedInUserFirstname}, something went sideways"
    updateCompleteDialog "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
    updateCompleteDialog "message: A failure has been detected, ${loggedInUserFirstname}"
    updateCompleteDialog "message: + <br><br>"
    updateCompleteDialog "message: + Please complete the following steps:"
    updateCompleteDialog "message: + 1. Reboot and login to your ${modelName}"
    updateCompleteDialog "message: + 2. Login to the Workforce App Store"
    updateCompleteDialog "message: + 3. Re-run this migration policy"
    updateCompleteDialog "message: + <br><br>"
    updateCompleteDialog "message: + The following failed:<br><br>${commandFailures}"

    quitScript "1"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    exitCode="${1}"
    notice "*** QUITTING ***"
    logComment "Exit Code: ${exitCode}"

    case ${exitCode} in
        0) logComment "${loggedInUser} clicked ${button1text}" ;;
        2) logComment "${loggedInUser} clicked ${button2text}" ;;
        3) logComment "${loggedInUser} clicked ${infobuttontext}" ;;
        4) logComment "${loggedInUser} allowed timer to expire" ;;
    esac

    updateMigrationDialog "quit: "

    # Remove dialogWelcomeLog
    if [[ -f "${dialogWelcomeLog}" ]]; then
        logComment "Removing ${dialogWelcomeLog} …"
        rm "${dialogWelcomeLog}"
    fi

    # Remove welcomeCommandFile
    if [[ -e ${welcomeJSONFile} ]]; then
        logComment "Removing ${welcomeJSONFile} …"
        rm "${welcomeJSONFile}"
    fi

    # Remove dialogMigrationLog
    if [[ -f "${dialogMigrationLog}" ]]; then
        logComment "Removing ${dialogMigrationLog} …"
        rm "${dialogMigrationLog}"
    fi

    # Remove dialogCompleteLog
    if [[ -f "${dialogCompleteLog}" ]]; then
        logComment "Removing ${dialogCompleteLog} …"
        rm "${dialogCompleteLog}"
    fi

    # Remove overlayicon
    if [[ -f "${overlayicon}" ]]; then
        logComment "Removing ${overlayicon} …"
        rm "${overlayicon}"
    fi

    # Remove custom welcomeBannerImageFileName
    if [[ -e "/var/tmp/${welcomeBannerImageFileName}" ]]; then
        logComment "Removing /var/tmp/${welcomeBannerImageFileName} …"
        rm "/var/tmp/${welcomeBannerImageFileName}"
    fi

    # Remove any default dialog file
    if [[ -e "/var/tmp/dialog.log" ]]; then
        quitOut "Removing default dialog file …"
        rm "/var/tmp/dialog.log"
    fi

    logComment "Goodbye!"
    exit "${1}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON via osascript and JavaScript
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function parseJSONvalue() {
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env).$2"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON via osascript and JavaScript for the Welcome dialog (thanks, @bartreardon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function parseJSONwelcomeValue() {
    for var in "${@:2}"; do jsonkey="${jsonkey}['${var}']"; done
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env)$jsonkey"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm an Apple Business Manager Record
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validateAbmRecord() {

    notice "Validate an Apple Business Manager record exists for \"${serialNumber}\" in the \"${abmOrganizationName}\" organization …"

    unset commandResult
    unset checkAbmRecord

    if [[ ! -e "${temporaryPath}.abmRecord" ]]; then

        checkAbmRecord=$( profiles show -type enrollment | grep "${abmOrganizationName}" )
        echo "${checkAbmRecord}" > ${temporaryPath}.abmRecord
        
        if [[ -z ${checkAbmRecord} ]]; then
            logComment "An Apple Business Manager record does NOT exist for \"${serialNumber}\" in the \"${abmOrganizationName}\" organization."
            commandResult="No"
            rm "${temporaryPath}.abmRecord"
        else
            logComment "An Apple Business Manager record exists for \"${serialNumber}\" in the \"${abmOrganizationName}\" organization."
            commandResult="Yes"
        fi

    else

        checkAbmRecord=$( < "${temporaryPath}.abmRecord" )

        if [[ "${checkAbmRecord}" == *"${abmOrganizationName}"* ]]; then
            commandResult="Yes"
        else
            commandResult="No"
            rm "${temporaryPath}.abmRecord"
        fi

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check the status of the Jamf Pro MDM Profile
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function jamfProMdmProfileStatus() {

    notice "Check the status of the Jamf Pro MDM Profile …"

    unset commandResult
    unset mdmProfileTest

    mdmProfileTest=$( profiles list -all | grep "00000000-0000-0000-A000-4A414D460003" )

    if [[ -z ${mdmProfileTest} ]]; then

        logComment "Jamf Pro MDM Profile NOT installed"
        commandResult="No"

    else

        logComment "Jamf Pro MDM Profile IS installed"
        commandResult="Yes"

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check the status of installed Configuration Profiles
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function configurationProfilesStatus() {

    notice "Check the status of installed Configuration Profiles …"

    pause "3"

    unset commandResult
    unset configurationProfilesTest

    configurationProfilesTest=$( profiles list -all )

    if [[ ${configurationProfilesTest} == "There are no configuration profiles installed" ]]; then

        logComment "${configurationProfilesTest}"
        commandResult="No"

    else

        logComment "${configurationProfilesTest}"
        commandResult="Yes"

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate access to a given URL (i.e., Jamf Pro API)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validateURLaccess() {

    testURL="${1}"

    notice "Validate Access to ${testURL} …"

    unset commandResult
    unset urlTest

    urlTest=$( curl -s -f -LI "${testURL}" | head -n 1 )

    if [[ ${urlTest} == *"200 OK"* ]]; then

        logComment "Validated access to \"${testURL}\"; proceeding …"
        commandResult="Yes"

    else

        logComment "Error: \"${testURL}\" is NOT accessible"
        commandResult="No"

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Extension Attribute Read
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function extensionAttributeRead() {

    notice "Read Extension Attribute …"
    # set -x
    eaValue=$( curl -H "Authorization: Bearer ${apiBearerToken}" -H "Accept: text/xml" -s "${apiURL}"/JSSResource/computers/id/"${jssID}"/subset/extension_attributes | xmllint --format - | grep -A3 "<name>${eaName}</name>" | awk -F'>|<' '/value/{print $3}' | tail -n 1 )
    # set +x
    logComment "${eaName}: ${eaValue}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Extension Attribute Write
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function extensionAttributeWrite() {

    eaValue="${1}"

    notice "Write Extension Attribute '${eaName}' to '${eaValue}'"
    # set -x
    apiData="<computer><extension_attributes><extension_attribute><name>${eaName}</name><value>${eaValue}</value></extension_attribute></extension_attributes></computer>"
    apiPost=$( curl -H "Authorization: Bearer ${apiBearerToken}" -H "Content-Type: text/xml" -s "${apiURL}"/JSSResource/computers/id/"${jssID}" -d "${apiData}" -X PUT )
    /bin/echo "${apiPost}" > /dev/null
    # set +x

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remove Jamf Pro Configuration Profile via the API
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function removeJamfProConfigurationProfileViaAPI() {

    notice "Remove Jamf Pro MDM Profile via the API …"

    updateMigrationDialog "progresstext: Attempting to remove the Jamf Pro MDM Profile. A check will be made every 30 seconds for the next 5 minutes."

    logComment "Serial Number: ${serialNumber}"

    # Remove the Jamf Pro MDM Profile via the API
    if [[ "${operationMode}" == *"migrate" ]]; then
        logComment "Operation Mode: ${operationMode}; attempting to un-manage …"
        curl -s -X POST -H "Authorization: Bearer ${apiBearerToken}" -s "${apiURL}/JSSResource/computercommands/command/UnmanageDevice/id/${jssID}"
        pauseDuration="15"
    else
        logComment "Operation Mode: ${operationMode}; skipping …"
        pauseDuration="1"
    fi

    # Remove BeyondTrust Privilege Management-modified /etc/sudo.conf
    notice "Remove BeyondTrust Privilege Management-modified /etc/sudo.conf"
    sudoConfTest=$( grep "avecto_policy" /etc/sudo.conf )
    if [[ -n "${sudoConfTest}" ]]; then
        info "• avecto_policy found in sudo.conf"
        removeSudoDotConf=$( rm -fv /etc/sudo.conf | tee -a "${scriptLog}" )
        logComment "Result: ${?}"
        pause "2" 
        sudoConfTest2=$( grep "avecto_policy" /etc/sudo.conf )
        if [[ -z "${sudoConfTest2}" ]]; then
            logComment "avecto_policy NOT found in sudo.conf"
        else
            fatal "avecto_policy found in sudo.conf"
            removeSudoDotConf2=$( rm -fv /etc/sudo.conf | tee -a "${scriptLog}" )
            logComment "Result: ${?}"
        fi
    else
        logComment "avecto_policy NOT found in sudo.conf"
    fi

    # Check 10 times to confirm that the Jamf Pro MDM Profile was removed
    counter=1
    updateMigrationDialog "progresstext: Check ${counter} of 10; waiting ${pauseDuration} seconds to re-check..."
    jamfProMdmProfileStatus
    pause "${pauseDuration}"

    until [[ "${commandResult}" == "No" ]] || [[ "${counter}" -gt "9" ]]; do
        ((counter++))
        logComment "Check ${counter} of 10: Jamf Pro MDM Profile present; waiting ${pauseDuration} seconds to re-check..."
        updateMigrationDialog "progresstext: Check ${counter} of 10; waiting ${pauseDuration} seconds to re-check..."
        pause "${pauseDuration}"
        jamfProMdmProfileStatus
    done

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remove Jamf Pro Framework
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function removeJamfProFramework() {

    notice "Remove Jamf Pro Framework …"

    if [[ -e "/usr/local/bin/jamf" ]]; then

        if [[ "${operationMode}" == *"migrate" ]]; then
            logComment "Operation Mode: ${operationMode}; attempting to remove jamf framework …"
            /usr/local/bin/jamf removeFramework -verbose | tee -a "${scriptLog}"

            # TO DO: nuke "/Library/Preferences/com.jamfsoftware.jamf.plist" ???

        else
            logComment "Operation Mode: ${operationMode}; skipping removal of jamf framework…"
        fi

    else
        logComment "jamf binary NOT found"
        commandResult="No"
    fi

    if [[ -e "/usr/local/bin/jamf" ]]; then
        logComment "jamf binary exists"
        commandResult="Yes"
    else
        logComment "jamf binary NOT found"
        commandResult="No"
    fi

}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remove BeyondTrust Privilege Management
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function removeBeyondTrustPrivilegeManagement() {

    notice "Remove BeyondTrust Privilege Management"

    if [[ "${operationMode}" == "self-migrate" ]]; then

        # Enable UseSheets
        useSheetStatus=$( defaults read "/Users/${loggedInUser}/Library/Preferences/com.apple.Preferences.plist" UseSheets 2>&1 )
        if [[ "${useSheetStatus}" != "1" ]]; then
            info "Enabling UseSheets..."
            defaults write "/Users/${loggedInUser}/Library/Preferences/com.apple.Preferences.plist" UseSheets -bool true
            chown "${loggedInUser}" "/Users/${loggedInUser}/Library/Preferences/com.apple.Preferences.plist"
            pkill -l -U "${loggedInUser}" cfprefsd
            useSheetStatus=$( defaults read "/Users/${loggedInUser}/Library/Preferences/com.apple.Preferences.plist" UseSheets 2>&1 )
            logComment "UseSheets Status: ${useSheetStatus}"
        else
            logComment "UseSheets Status: ${useSheetStatus}"
        fi

        if [[ -e "/etc/defendpoint/ic3.xml" ]]; then

            info "Uninstalling …"

            if [[ -e "/usr/local/libexec/Avecto/Defendpoint/1.0/uninstall.sh" ]]; then
                info "• Defendpoint"
                removeDefendpoint=$( /usr/local/libexec/Avecto/Defendpoint/1.0/uninstall.sh  | tee -a "${scriptLog}" )
                logComment "Result: ${?}"
            else
                logComment "Defendpoint NOT found"
            fi

            if [[ -e "/usr/local/libexec/Avecto/iC3Adapter/1.0/uninstall_ic3_adapter.sh" ]]; then
                info "• iC3Adapter"
                removeiC3Adapter=$( /usr/local/libexec/Avecto/iC3Adapter/1.0/uninstall_ic3_adapter.sh  | tee -a "${scriptLog}" )
                logComment "Result: ${?}"
            else
                logComment "iC3Adapter NOT found"
            fi

            if [[ -e "/etc/defendpoint" ]]; then
                info "• Defendpoint Directory"
                removeDefendpointDirectory=$( rm -Rfv /etc/defendpoint | tee -a "${scriptLog}" )
                logComment "Result: ${?}"
            else
                logComment "Defendpoint Directory NOT found"
            fi

            # Validate various BT PMfM Processes
            procesStatus "defendpointd"
            procesStatus "Custodian"
            procesStatus "PMCAdapter"
            procesStatus "PrivilegeManagement"

            # Remove trailing "; "
            processCheckResult=${processCheckResult/%; }

            if [[ "${processCheckResult}" == *"running" ]]; then
                commandResult="Running"
            else
                commandResult="Stopped"
            fi

            info "Command Result: ${commandResult}"

        else

            logComment "BeyondTrust Privilege Management policy NOT found"

        fi

        # Remove BeyondTrust Privilege Management-modified /etc/sudo.conf
        # Moved to removeJamfProConfigurationProfileViaAPI function

    else
        logComment "Operation Mode: ${operationMode}; skipping …"
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Make logged-in user a local administrator
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function makeUserAdmin() {

    notice "Make logged-in user a local administrator"

    if [[ "${operationMode}" == "self-migrate" ]]; then

        adminCheck=$( dseditgroup -o checkmember -m "${loggedInUser}" admin )
        if [[ "${adminCheck}" == *"NOT a member of admin" ]]; then
            logComment "${adminCheck}"
            dseditgroup -v -o edit -a "${loggedInUser}" -t user admin
            adminCheck=$( dseditgroup -o checkmember -m "${loggedInUser}" admin )
            logComment "${adminCheck}"
        else
            logComment "${adminCheck}"
        fi

    else
        logComment "Operation Mode: ${operationMode}; skipping …"
    fi

    adminCheck=$( dseditgroup -o checkmember -m "${loggedInUser}" admin )
    if [[ "${adminCheck}" == *"NOT a member of admin" ]]; then
        commandResult="Standard"
    else
        commandResult="Admin"
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Re-enroll via Automatted Device Enrollment
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function ReEnrollViaAutomattedDeviceEnrollment() {

    notice "Re-enroll via Automatted Device Enrollment"

    set -xv

    if [[ "${operationMode}" == "self-migrate" ]]; then

        # command=$( su \- "${loggedInUser}" -c "sudo profiles renew -type enrollment -verbose" )
        command=$( /usr/bin/expect <<EOF
set timeout 90
spawn su \- "${loggedInUser}" -c "sudo profiles renew -type enrollment -verbose"
expect "Password:"
send "${usersPassword}\r"
expect "*#*"
EOF
)
        commandResult="${command}"
        logComment "commandResult: ${commandResult}"
    
    else
        logComment "Operation Mode: ${operationMode}; skipping …"
    fi

    set +xv

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Command Execution
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function commandExecution() {

    outputLineNumberInDebugMode

    command="${1}"
    validation="${2}"
    notice "Command Execution: '${command}' '${validation}'"

    case ${command} in

        "Current MDM Server Connectivity" )
            outputLineNumberInDebugMode
            extensionAttributeWrite "2. Started"
            extensionAttributeRead
            commandResult=$( /usr/local/bin/jamf CheckJSSConnection | tail -n 1 )
            validateCommand "${validation}" "${commandResult}"
            ;;

        "New MDM Server Connectivity" )
            outputLineNumberInDebugMode
            validateURLaccess "https://officecdn.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/CompanyPortal-Installer.pkg"
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Confirm an Apple Business Manager Record" )
            outputLineNumberInDebugMode
            validateAbmRecord
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Confirm Jamf Pro MDM Profile" )
            outputLineNumberInDebugMode
            jamfProMdmProfileStatus
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Confirm Configuration Profiles" )
            outputLineNumberInDebugMode
            configurationProfilesStatus
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Remove Jamf Pro Configuration Profile via the API" )
            outputLineNumberInDebugMode
            removeJamfProConfigurationProfileViaAPI
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Remove Jamf Pro Framework" )
            outputLineNumberInDebugMode
            removeJamfProFramework
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Remove BeyondTrust Privilege Management" )
            outputLineNumberInDebugMode
            removeBeyondTrustPrivilegeManagement
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Grant User Administrative Rights" )
            outputLineNumberInDebugMode
            makeUserAdmin
            validateCommand "${validation}" "${commandResult}"
            ;;

        "Enroll in new MDM Server" )
            outputLineNumberInDebugMode
            notice "Enroll in new MDM Server"
            ReEnrollViaAutomattedDeviceEnrollment &
            if [[ "${operationMode}" == *"migrate" ]]; then
                extensionAttributeWrite "3. Migrated"
                extensionAttributeRead
                quitScript
            fi
            # validateCommand "${validation}" "${commandResult}"
            ;;

        * ) # Catch-all
            outputLineNumberInDebugMode
            errorOut "Command Execution Catch-all: ${command}"
            updateMigrationDialog "listitem: index: $i, status: error, statustext: Error"
            ;;

    esac

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
        preFlight "Created specified scriptLog"
    else
        fatal "Unable to create specified scriptLog '${scriptLog}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    preFlight "Specified scriptLog exists; writing log entries to it"
fi




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "\n\n###\n# $humanReadableScriptName [$organizationScriptName (${scriptVersion})]\n# https://snelson.us\n###\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 12 ]] ; then
    preFlight "macOS ${osMajorVersion} installed; proceeding ..."
    dialogCheck
else
    preFlight "macOS ${osMajorVersion} installed; exiting"
    quitScript "1"
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
# Create Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Operation Mode is: '${operationMode}'"

# If Debug Mode is enabled, replace `blurscreen` with `movable`
if [[ "${operationMode}" != *"migrate" ]] ; then
    welcomeJSON=${welcomeJSON//blurscreen/moveable}
fi

logComment "Create Welcome Dialog and capture user's input"

# Write Welcome JSON to disk
echo "$welcomeJSON" > "$welcomeJSONFile"

welcomeResults=$( eval "${dialogBinary} --jsonfile ${welcomeJSONFile} --json" )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Evaluate User Input
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -n "${welcomeResults}" ]]; then
    welcomeReturnCode="0"
else
    welcomeReturnCode="2"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Process Return Codes
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case ${welcomeReturnCode} in

    2)  ## Process exit code 2 scenario here
        notice "${loggedInUser} clicked ${button2text};"
        quitScript "2"
        ;;

    3)  ## Process exit code 3 scenario here
        notice "${loggedInUser} clicked ${infobuttontext};"
        quitScript "3"
        ;;

    4)  ## Process exit code 4 scenario here
        notice "${loggedInUser} allowed timer to expire;"
        quitScript "4"
        ;;

    0)  ## Process exit code 0 scenario here
        notice "${loggedInUser} clicked ${button1text};"

        usersPassword=$(parseJSONwelcomeValue "$welcomeResults" "Password")

        checkPassword "${usersPassword}"

        if [[ "${passwordCheck}" == "fail" ]]; then
            commandFailures+="• The password entered is NOT the login password for $loggedInUser<br>"
            fatal "The password entered is NOT the login password for $loggedInUser."
        fi

        # If Debug Mode is enabled, replace `blurscreen` with `movable`
        if [[ "${operationMode}" != *"migrate" ]] ; then
            dialogMigration=${dialogMigration//blurscreen/moveable}
        fi

        # Obtain Jamf Pro Bearer Token via Basic Authentication
        apiPassword=$( decryptPassword ${apiPasswordEncrypted} ${Salt} ${Passphrase} )
        apiBearerToken=$( curl -X POST -s -u "${apiUser}:${apiPassword}" "${apiURL}/api/v1/auth/token" | plutil -extract token raw - )
        logComment "apiBearerToken: ${apiBearerToken}"

        # Obtain the Computer’s Jamf Pro Computer ID via the API
        jssID=$( curl -H "Authorization: Bearer ${apiBearerToken}" -s "${apiURL}"/JSSResource/computers/serialnumber/"${serialNumber}"/subset/general | xpath -e "/computer/general/id/text()" )
        logComment "jssID: ${jssID}"

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # Validate Installation of Configuration Profiles
        # (i.e., for subsequent runs, just re-enroll)
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        configurationProfilesStatus

        if [[ "${commandResult}" == "No" ]]; then
            notice "${configurationProfilesTest}"
            makeUserAdmin
            removeBeyondTrustPrivilegeManagement
            extensionAttributeWrite "2. Started"
            extensionAttributeRead
            ReEnrollViaAutomattedDeviceEnrollment
            #
            # 

        else

            eval "${dialogMigration[*]}" & sleep 0.3

            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            # Iterate through migrationJSON to construct the list for swiftDialog
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            outputLineNumberInDebugMode

            dialog_step_length=$(parseJSONvalue "${migrationJSON}" "steps.length")
            for (( i=0; i<dialog_step_length; i++ )); do
                listitem=$(parseJSONvalue "${migrationJSON}" "steps[$i].listitem")
                list_item_array+=("$listitem")
                subtitle=$(parseJSONvalue "${migrationJSON}" "steps[$i].subtitle")
                subtitle_array+=("$subtitle")
                icon=$(parseJSONvalue "${migrationJSON}" "steps[$i].icon")
                icon_url_array+=("$icon")
            done



            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            # Determine the "progress: increment" value based on the number of steps in migrationJSON
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            outputLineNumberInDebugMode

            totalProgressSteps=$(parseJSONvalue "${migrationJSON}" "steps.length")
            progressIncrementValue=$(( 100 / totalProgressSteps ))
            updateMigrationDialog "Total Number of Steps: ${totalProgressSteps}"
            updateMigrationDialog "Progress Increment Value: ${progressIncrementValue}"



            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            # The ${array_name[*]/%/,} expansion will combine all items within the array adding a "," character at the end
            # To add a character to the start, use "/#/" instead of the "/%/"
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            outputLineNumberInDebugMode

            list_item_string=${list_item_array[*]/%/,}
            updateMigrationDialog "list: ${list_item_string%?}"
            for (( i=0; i<dialog_step_length; i++ )); do
                updateMigrationDialog "listitem: index: $i, icon: ${icon_url_array[$i]}, status: pending, statustext: Pending …, subtitle: ${subtitle_array[$i]}"
            done
            sleep 3
            updateMigrationDialog "list: show"



            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            # Set initial progress bar
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            outputLineNumberInDebugMode

            updateMigrationDialog "Initial progress bar"
            updateMigrationDialog "progresstext: Starting migration …"
            updateMigrationDialog "progress: 1"



            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            # Execute each step in migrationJSON (inspired by @smithjw)
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            notice "Execute each step in migrationJSON (inspired by @smithjw)"

            for (( i=0; i<dialog_step_length; i++ )); do 

                outputLineNumberInDebugMode

                # Initialize SECONDS
                SECONDS="0"

                # Creating initial variables
                listitem=$(parseJSONvalue "${migrationJSON}" "steps[$i].listitem")
                icon=$(parseJSONvalue "${migrationJSON}" "steps[$i].icon")
                progresstext=$(parseJSONvalue "${migrationJSON}" "steps[$i].progresstext")
                commandListLength=$(parseJSONvalue "${migrationJSON}" "steps[$i].commandList.length")

                # If there’s a value in the variable, update running swiftDialog
                if [[ -n "$listitem" ]]; then
                    logComment "migrationJSON > ${listitem}"
                    updateMigrationDialog "listitem: index: $i, status: wait, statustext: Executing …, "
                fi
                if [[ -n "$icon" ]]; then updateMigrationDialog "icon: ${icon}"; fi
                if [[ -n "$progresstext" ]]; then updateMigrationDialog "progresstext: $progresstext"; fi
                if [[ -n "$commandListLength" ]]; then

                    for (( j=0; j<commandListLength; j++ )); do

                        # Setting variables within the commandList
                        command=$(parseJSONvalue "${migrationJSON}" "steps[$i].commandList[$j].command")
                        validation=$(parseJSONvalue "${migrationJSON}" "steps[$i].commandList[$j].validation")
                        commandExecution "${command}" "${validation}"

                    done

                fi

                # Increment the progress bar
                updateMigrationDialog "progress: increment ${progressIncrementValue}"

                # Record duration
                updateMigrationDialog "Elapsed Time for '${command}' '${validation}': $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

            done
      
        fi

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # Prompt user for failures
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        if [[ "${commandFailure}" == "failure" ]]; then

            notice "Failures detected"
            updateMigrationDialog "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
            updateMigrationDialog "progresstext: Failures detected. Please click Continue for troubleshooting information."
            updateMigrationDialog "button1text: Continue …"
            updateMigrationDialog "button1: enable"
            updateMigrationDialog "progress: reset"

            # Wait for user-acknowledgment due to detected failure
            wait

            updateMigrationDialog "quit:"

            eval "$dialogComplete" & sleep 0.3

            updateCompleteDialog "title: Sorry ${loggedInUserFirstname}, something went sideways"
            updateCompleteDialog "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
            updateCompleteDialog "message: A failure has been detected, ${loggedInUserFirstname}"
            updateCompleteDialog "message: + <br><br>"
            updateCompleteDialog "message: + Please complete the following steps:"
            updateCompleteDialog "message: + 1. Disconnect GlobalProtect"
            updateCompleteDialog "message: + 2. Reboot and login to your ${modelName}"
            updateCompleteDialog "message: + 3. Login to the Workforce App Store"
            updateCompleteDialog "message: + 4. Re-run this migration policy"
            updateCompleteDialog "message: + <br><br>"
            updateCompleteDialog "message: + The following failed:<br><br>${commandFailures}"

        else

            updateMigrationDialog "button1text: Restart"
            updateMigrationDialog "button1: enable"

        fi

        ## TO DO: Restart

        quitScript "0"

        ;;

    *)  ## Catch all processing
        updateScriptLog "Something else happened; welcomeReturncode: ${welcomeReturncode};"
        quitScript "1"
        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "End-of-line."

quitScript "0"