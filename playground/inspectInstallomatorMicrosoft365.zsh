#!/bin/zsh --no-rcs
# shellcheck shell=bash

####################################################################################################
#
# swiftDialog Inspect Mode for Installomator
# - Microsoft 365-specific version
#
# Installs an app specified by Jamf Pro Parameter Labels using Installomator,
# with UI provided by swiftDialog's Inspect Mode
#
# https://snelson.us
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 04-Dec-2025, Dan K. Snelson (@dan-snelson)
#   - Original version
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/

# Script Version
scriptVersion="0.0.1"

# Elapsed Time
SECONDS="0"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Installomator Label (See: https://github.com/Installomator/Installomator/tree/main/fragments/labels)
installomatorLabel="${4:-"microsoftoffice365"}"

# Parameter 5: Application Path (for verification)
applicationPath="${5:-"/Applications/Microsoft Word.app"}"

# Parameter 6: Application Icon
applicationIcon="${6:-"https://usw2.ics.services.jamfcloud.com/icon/hash_8bf6549c22de3db831aafaf9c5c02d3aa9a928f4abe377eb2f8cbeab3959615c"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readable Name
humanReadableScriptName="swiftDialog Inspect Mode for Installomator: Microsoft 365"

# Organization's Script Name
organizationScriptName="sDIMfI-M365"

# Organization's Installomator Path
organizationInstallomatorPath="/Library/Management/AppAutoPatch/Installomator/Installomator.sh"

# Organization's swiftDialog Inspect Mode Preset Option (See: https://beta.swiftdialog.app/advanced/inspect-mode/)
organizationPreset="1"

# Organization's Branding Banner URL
organizationBrandingBannerURL="https://img.freepik.com/free-photo/orange-wall-with-cracks-peeling-paint_1258-28309.jpg" # [Image by benzoix on Freepik](https://www.freepik.com/author/benzoix)

# Organization's Overlayicon URL
organizationOverlayiconURL="https://beta.swiftdialog.app/_astro/dialog_logo.CZF0LABZ_ZjWz8w.webp"

# Organization's Color Scheme
if [[ $( defaults read /Users/$( stat -f %Su /dev/console )/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>/dev/null ) == "Dark" ]]; then
    # Dark Mode
    organizationColorScheme="weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
    # Light Mode
    organizationColorScheme="weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logged-in User Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print ( $0 == toupper($0) ? toupper(substr($0,1,1))substr(tolower($0),2) : toupper(substr($0,1,1))substr($0,2) )}' )
loggedInUserID=$( id -u "${loggedInUser}" )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Application Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Application Name
appName=$( basename "${applicationPath}" .app )



####################################################################################################
#
# swiftDialog Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog binary
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# swiftDialog Binary Path
dialogBinary="/usr/local/bin/dialog"

# swiftDialog Inspect Mode JSON File
dialogInspectModeJSONFile=$( mktemp -u /var/tmp/dialogJSONFile_InspectMode_${organizationScriptName}.XXXX )

# Set initial icon based on whether the Mac is a desktop or laptop
if system_profiler SPPowerDataType | grep -q "Battery Power"; then
    icon="SF=laptopcomputer.and.arrow.down,${organizationColorScheme}"
else
    icon="SF=desktopcomputer.and.arrow.down,${organizationColorScheme}"
fi

# Download the overlayicon from ${organizationOverlayiconURL}
if [[ -n "${organizationOverlayiconURL}" ]]; then
    # echo "Downloading overlayicon from '${organizationOverlayiconURL}' …"
    curl -o "/var/tmp/overlayicon.png" "${organizationOverlayiconURL}" --silent --show-error --fail
    if [[ "$?" -ne 0 ]]; then
        echo "Error: Failed to download the overlayicon from '${brandingImageURL}'."
        overlayicon="/System/Library/CoreServices/Finder.app"
    else
        overlayicon="/var/tmp/overlayicon.png"
    fi
else
    overlayicon="/System/Library/CoreServices/Finder.app"
fi



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Run command as logged-in user (thanks, @scriptingosx!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

    echo "Run \"$@\" as \"$loggedInUserID\" … "
    launchctl asuser "$loggedInUserID" sudo -u "$loggedInUser" "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create swiftDialog Inspect Mode configuration
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function createInspectConfig() {

    cat > "${dialogInspectModeJSONFile}" <<EOF
{
    "title": "Happy $( date +'%A' ), ${loggedInUserFirstname}!\n\nWe're starting to install ${appName}.",
    "message": "Installing ${appName} …",
    "preset": "preset${organizationPreset}",
    "icon": "${applicationIcon}",
    "iconsize": 120,
    "size": "compact",
    "cachePaths": [
        "/tmp/${installomatorLabel}*"
    ],
    "scanInterval": 5,
    "sideMessage": [
        "Thank you for your patience.",
        "The installation progress is automatically monitored.",
        "Please wait while ${appName} is being installed.",
        "Your device will be ready for productive work once complete."
    ],
    "sideInterval": 8,
    "highlightColor": "#FF904C",
    "popupButton": "Installation Details...",
    "button1text": "Please wait...",
    "button1disabled": true,
    "button2text": "Restart Later",
    "button2disabled": false,
    "button2visible": false,
    "autoEnableButton": true,
    "autoEnableButtonText": "Show",
    "items": [
        {
            "id": "microsoft_word",
            "displayName": "Microsoft Word",
            "guiIndex": 0,
            "paths": [
                "/Applications/Microsoft Word.app"
            ],
            "icon": "/Applications/Microsoft Word.app"
        },
        {
            "id": "microsoft_excel",
            "displayName": "Microsoft Excel",
            "guiIndex": 1,
            "paths": [
                "/Applications/Microsoft Excel.app"
            ],
            "icon": "/Applications/Microsoft Excel.app"
        },
        {
            "id": "microsoft_powerpoint",
            "displayName": "Microsoft PowerPoint",
            "guiIndex": 2,
            "paths": [
                "/Applications/Microsoft PowerPoint.app"
            ],
            "icon": "/Applications/Microsoft PowerPoint.app"
        },
        {
            "id": "microsoft_outlook",
            "displayName": "Microsoft Outlook",
            "guiIndex": 3,
            "paths": [
                "/Applications/Microsoft Outlook.app"
            ],
            "icon": "/Applications/Microsoft Outlook.app"
        },
        {
            "id": "microsoft_onenote",
            "displayName": "Microsoft OneNote",
            "guiIndex": 4,
            "paths": [
                "/Applications/Microsoft OneNote.app"
            ],
            "icon": "/Applications/Microsoft OneNote.app"
        },
        {
            "id": "microsoft_onedrive",
            "displayName": "OneDrive",
            "guiIndex": 5,
            "paths": [
                "/Applications/OneDrive.app"
            ],
            "icon": "/Applications/OneDrive.app"
        }
    ]
}
EOF

    echo "${dialogInspectModeJSONFile}"

}




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    exitCode="${1:-0}"

    echo "Exiting …"

    # Remove the dialog command file
    rm -f "${dialogCommandFile}"

    # Remove the dialog-related JSON files
    rm -f /var/tmp/dialogJSONFile_*

    # Remove overlay icon
    if [[ -f "${overlayicon}" ]] && [[ "${overlayicon}" != "/System/Library/CoreServices/Finder.app" ]]; then
        rm -f "${overlayicon}"
    fi

    # Remove default dialog.log
    rm -f /var/tmp/dialog.log

    echo "Total Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

    echo "So long!"

    exit "${exitCode}"

}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# https://snelson.us\n####\n\n"
echo "Pre-flight Check: Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    echo "ERROR: This script must be run as root; exiting."
    quitScript "1"
else
    echo "Pre-flight Check: Running as root; proceeding …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "Pre-flight Check: Completed."



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Installomator app installation
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -e "${applicationPath}" ]]; then
    echo "${appName} is already installed at ${applicationPath}; skipping Installomator installation."
    # quitScript "0"
else
    echo "${appName} is not installed at ${applicationPath}; proceeding with Installomator installation."
    command "${organizationInstallomatorPath}" "${installomatorLabel}" DEBUG=0 NOTIFY=silent &
    installomatorPID=$!
    echo "Installomator PID: ${installomatorPID}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

inspectConfigPath=$(createInspectConfig)

# Run dialog with the env var in user context
runAsUser \
    DIALOG_INSPECT_CONFIG="${inspectConfigPath}" \
    "${dialogBinary}" --inspect-mode &
dialogPID=$!
echo "Inspect Mode PID: ${dialogPID}"

# Wait for dialog to close before script exits
echo "Waiting for Inspect Mode (PID: ${dialogPID}) to close …"
wait ${dialogPID}
echo "${operationMode} Operation Mode closed."

# Reveal installed application in Finder
if [[ -e "${applicationPath}" ]]; then
    echo "Revealing ${appName} in Finder …"
    runAsUser open -R "${applicationPath}"
else
    echo "Error: ${appName} not found at ${applicationPath} after installation."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "0"
