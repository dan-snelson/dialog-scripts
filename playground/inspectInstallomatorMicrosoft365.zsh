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
# Version 0.0.2, 02-Jan-2026, Dan K. Snelson (@dan-snelson)
#   - Updated to use personal fork of Installomator (thanks, @BigMacAdmin!)
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/

# Script Version
scriptVersion="0.0.2"

# Client-side Log
scriptLog="/var/log/org.churchofjesuschrist.log"

# Elapsed Time
SECONDS="0"

# Minimum Required Version of swiftDialog
swiftDialogMinimumRequiredVersion="3.0.0.4925"

# Load is-at-least for version comparison
autoload -Uz is-at-least



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readable Name
humanReadableScriptName="swiftDialog Inspect Mode for Installomator: Microsoft 365"

# Organization's Script Name
organizationScriptName="sDIMfI-M365"

# Organization's Installomator URL
organizationInstallomatorURL="https://raw.githubusercontent.com/dan-snelson/Installomator/refs/heads/dev/Installomator.sh"

# Organization's Installomator URL Hash
organizationInstallomatorURLHash="b89128f7fe410208570427a4160017560104d84811e7f7336c6a5c92697b9ee7"

# Organization's Installomator Path
organizationInstallomatorFile="/var/tmp/Installomator/Installomator.sh"

# Organization's Installomator Download Directory
organizationInstallomatorDownloadDirectory="$(dirname "${organizationInstallomatorFile}")/downloads"

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
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Installomator Label (See: https://github.com/Installomator/Installomator/tree/main/fragments/labels)
installomatorLabel="${4:-"microsoftoffice365"}"

# Parameter 5: Application Path (for verification)
applicationPath="${5:-"/Applications/Microsoft Word.app"}"

# Parameter 6: Application Icon
applicationIcon="${6:-"https://usw2.ics.services.jamfcloud.com/icon/hash_8bf6549c22de3db831aafaf9c5c02d3aa9a928f4abe377eb2f8cbeab3959615c"}"



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
        warning "Failed to download the overlayicon from '${organizationOverlayiconURL}'."
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
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo "${organizationScriptName}  ($scriptVersion): $( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

function preFlight()    { updateScriptLog "[PRE-FLIGHT]      ${1}"; }
function logComment()   { updateScriptLog "                  ${1}"; }
function notice()       { updateScriptLog "[NOTICE]          ${1}"; }
function info()         { updateScriptLog "[INFO]            ${1}"; }
function errorOut()     { updateScriptLog "[ERROR]           ${1}"; }
function error()        { updateScriptLog "[ERROR]           ${1}"; let errorCount++; }
function warning()      { updateScriptLog "[WARNING]         ${1}"; let errorCount++; }
function fatal()        { updateScriptLog "[FATAL ERROR]     ${1}"; exit 1; }
function quitOut()      { updateScriptLog "[QUIT]            ${1}"; }



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Run command as logged-in user (thanks, @scriptingosx!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

    echo "Run \"$@\" as \"$loggedInUserID\" … "
    launchctl asuser "$loggedInUserID" sudo -u "$loggedInUser" "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create swiftDialog Inspect Mode configuration (thanks, @headmin!)
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
        "${organizationInstallomatorDownloadDirectory}/*"
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

    notice "Exiting …"

    # Remove the dialog command file
    # rm -f "${dialogCommandFile}"

    # Remove the dialog-related JSON files
    rm -f /var/tmp/dialogJSONFile_*

    # Remove overlay icon
    if [[ -f "${overlayicon}" ]] && [[ "${overlayicon}" != "/System/Library/CoreServices/Finder.app" ]]; then
        rm -f "${overlayicon}"
    fi

    # Remove default dialog.log
    rm -f /var/tmp/dialog.log

    logComment "Total Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

    logComment "So long!"

    exit "${exitCode}"

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
    # preFlight "Specified scriptLog '${scriptLog}' exists; writing log entries to it"
    if [[ -f "${scriptLog}" ]]; then
        logSize=$(stat -f%z "${scriptLog}" 2>/dev/null || echo "0")
        maxLogSize=$((10 * 1024 * 1024))  # 10MB
        
        if (( logSize > maxLogSize )); then
            preFlight "Log file exceeds ${maxLogSize} bytes; rotating"
            mv "${scriptLog}" "${scriptLog}.${currentTime}.old"
            touch "${scriptLog}"
            preFlight "Log file rotated; previous log saved as ${scriptLog}.${currentTime}.old"
        fi
    fi
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# https://snelson.us\n####\n\n"
preFlight "Pre-flight Check: Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "ERROR: This script must be run as root; exiting."
else
    preFlight "Pre-flight Check: Running as root; proceeding …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogInstall() {
    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail --connect-timeout 10 --max-time 30 \
        "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" \
        | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
    
    # Validate URL was retrieved
    if [[ -z "${dialogURL}" ]]; then
        fatal "Failed to retrieve swiftDialog download URL from GitHub API"
    fi
    
    # Validate URL format
    if [[ ! "${dialogURL}" =~ ^https://github\.com/ ]]; then
        fatal "Invalid swiftDialog URL format: ${dialogURL}"
    fi

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    preFlight "Installing swiftDialog from ${dialogURL}..."

    # Create temporary working directory
    workDirectory=$( basename "$0" )
    tempDirectory=$( mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package with timeouts
    if ! curl --location --silent --fail --connect-timeout 10 --max-time 60 \
             "$dialogURL" -o "$tempDirectory/Dialog.pkg"; then
        rm -Rf "$tempDirectory"
        fatal "Failed to download swiftDialog package"
    fi

    # Verify the download
    teamID=$(spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

        installer -pkg "$tempDirectory/Dialog.pkg" -target /
        sleep 2
        dialogVersion=$( /usr/local/bin/dialog --version )
        preFlight "swiftDialog version ${dialogVersion} installed; proceeding..."

    else

        # Display a so-called "simple" dialog if Team ID fails to validate
        osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "DDM OS Reminder Error" buttons {"Close"} with icon caution'
        exit "1"

    fi

    # Remove the temporary working directory when done
    rm -Rf "$tempDirectory"

}



function dialogCheck() {

    # Check for Dialog and install if not found
    if [[ ! -x "/Library/Application Support/Dialog/Dialog.app" ]]; then

        preFlight "swiftDialog not found; installing …"
        dialogInstall
        if [[ ! -x "/usr/local/bin/dialog" ]]; then
            fatal "swiftDialog still not found; are downloads from GitHub blocked on this Mac?"
        fi

    else

        dialogVersion=$(/usr/local/bin/dialog --version)
        if ! is-at-least "${swiftDialogMinimumRequiredVersion}" "${dialogVersion}"; then
            
            preFlight "swiftDialog version ${dialogVersion} found but swiftDialog ${swiftDialogMinimumRequiredVersion} or newer is required; updating …"
            dialogInstall
            if [[ ! -x "/usr/local/bin/dialog" ]]; then
                fatal "Unable to update swiftDialog; are downloads from GitHub blocked on this Mac?"
            fi

        else

            preFlight "swiftDialog version ${dialogVersion} found; proceeding …"

        fi
    
    fi

}




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate / install Installomator
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function installomatorDownloadValidation() {

    actualHash=$( shasum -a 256 "${organizationInstallomatorFile}" | awk '{print $1}' )
    if [[ "${organizationInstallomatorURLHash}" == "${actualHash}" ]]; then
        preFlight "Installomator hash verified successfully: ${actualHash}"
        chmod +x "${organizationInstallomatorFile}"
    else
        preFlight "Installomator download hash mismatch!"
        preFlight "Expected: ${organizationInstallomatorURLHash}"
        preFlight "Actual:   ${actualHash}"
        rm -f "${organizationInstallomatorFile}"
        fatal "Hash mismatch! Possible tampering, corruption, or outdated hash."
    fi

}

function installomatorDownload() {

    mkdir -p "$(dirname "${organizationInstallomatorFile}")"

    if [[ -e "${organizationInstallomatorFile}" ]]; then
        preFlight "Existing Installomator found; validating hash …"
        installomatorDownloadValidation
    else
        preFlight "Downloading Installomator from ${organizationInstallomatorURL} …"
        curl --location --silent --fail --connect-timeout 10 --max-time 60 --retry 3 \
            "${organizationInstallomatorURL}" \
            -o "${organizationInstallomatorFile}"
        
        if [[ ! -e "${organizationInstallomatorFile}" || ! -s "${organizationInstallomatorFile}" ]]; then
            fatal "Failed to download Installomator from ${organizationInstallomatorURL}"
        else
            installomatorDownloadValidation
        fi
    fi

}



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
# Validate / install swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate / install Installomator
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

installomatorDownload



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Installomator app installation with concurrent Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -e "${applicationPath}" ]]; then
    quitOut "${appName} is already installed at ${applicationPath}; skipping installation."
    quitScript "0"
else
    notice "${appName} is NOT installed at ${applicationPath}; proceeding with Installomator."

    # Ensure download directory exists
    mkdir -p "${organizationInstallomatorDownloadDirectory}"

    # Run Installomator in background
    command "${organizationInstallomatorFile}" "${installomatorLabel}" \
        DOWNLOAD_DIRECTORY="${organizationInstallomatorDownloadDirectory}" \
        DEBUG=0 NOTIFY=silent &
    installomatorPID=$!
    logComment "Installomator PID: ${installomatorPID}"

    # Create and launch Dialog in background for real-time progress
    notice "Create Dialog …"
    inspectConfigPath=$(createInspectConfig)
    runAsUser \
        DIALOG_INSPECT_CONFIG="${inspectConfigPath}" \
        "${dialogBinary}" --inspect-mode &
    dialogPID=$!
    logComment "Inspect Mode PID: ${dialogPID}"

    # Wait for Dialog to close (user can dismiss after seeing progress)
    logComment "Waiting for Inspect Mode (PID: ${dialogPID}) to close …"
    wait ${dialogPID}
    logComment "Inspect Mode closed."

    # Now wait for Installomator and verify
    wait ${installomatorPID}
    installomatorExitCode=$?
    if [[ ${installomatorExitCode} -ne 0 ]]; then
        fatal "Installomator failed with exit code ${installomatorExitCode}"
    fi

    # Reveal installed application in Finder
    if [[ -e "${applicationPath}" ]]; then
        notice "Revealing ${appName} in Finder …"
        runAsUser open -R "${applicationPath}"
    else
        error "Error: ${appName} not found at ${applicationPath} after installation."
    fi
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "0"
