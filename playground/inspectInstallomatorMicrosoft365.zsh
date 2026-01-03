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
# Version 0.0.3, 02-Jan-2026, Dan K. Snelson (@dan-snelson)
#   - Updated to use individual Installomator labels
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/

# Script Version
scriptVersion="0.0.3"

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
organizationBrandingBannerURL="https://img.freepik.com/free-photo/orange-wall-with-cracks-peeling-paint_1258-28309.jpg"

# Organization's Overlayicon URL
organizationOverlayiconURL="https://beta.swiftdialog.app/_astro/dialog_logo.CZF0LABZ_ZjWz8w.webp"

# Organization's Color Scheme
if [[ $( /usr/bin/defaults read /Users/$( /usr/bin/stat -f %Su /dev/console )/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>/dev/null ) == "Dark" ]]; then
    organizationColorScheme="weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
    organizationColorScheme="weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Application Icon
applicationIcon="${4:-"https://usw2.ics.services.jamfcloud.com/icon/hash_8bf6549c22de3db831aafaf9c5c02d3aa9a928f4abe377eb2f8cbeab3959615c"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logged-in User Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( /usr/bin/id -F "${loggedInUser}" )
loggedInUserFirstname=$( /bin/echo "$loggedInUserFullname" | /usr/bin/sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | /usr/bin/sed 's/\(.\{25\}\).*/\1…/' | /usr/bin/awk '{print ( $0 == toupper($0) ? toupper(substr($0,1,1))substr(tolower($0),2) : toupper(substr($0,1,1))substr($0,2) )}' )
loggedInUserID=$( /usr/bin/id -u "${loggedInUser}" )



####################################################################################################
#
# swiftDialog Variables
#
####################################################################################################

# Title
title="Microsoft 365 Applications"

# swiftDialog Binary Path
dialogBinary="/usr/local/bin/dialog"

# swiftDialog Inspect Mode JSON File
dialogInspectModeJSONFile=$( /usr/bin/mktemp -u /var/tmp/dialogJSONFile_InspectMode_${organizationScriptName}.XXXX )

# Set initial icon based on whether the Mac is a desktop or laptop
if /usr/sbin/system_profiler SPPowerDataType | /usr/bin/grep -q "Battery Power"; then
    icon="SF=laptopcomputer.and.arrow.down,${organizationColorScheme}"
else
    icon="SF=desktopcomputer.and.arrow.down,${organizationColorScheme}"
fi

# Download the overlayicon from ${organizationOverlayiconURL}
if [[ -n "${organizationOverlayiconURL}" ]]; then
    /usr/bin/curl -o "/var/tmp/overlayicon.png" "${organizationOverlayiconURL}" --silent --show-error --fail
    if [[ "$?" -ne 0 ]]; then
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
    echo "${organizationScriptName} ($scriptVersion): $( /bin/date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | /usr/bin/tee -a "${scriptLog}"
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
    /bin/echo "Run \"$@\" as \"$loggedInUserID\" … "
    /bin/launchctl asuser "$loggedInUserID" /usr/bin/sudo -u "$loggedInUser" "$@"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create swiftDialog Inspect Mode configuration (thanks, @headmin!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function createInspectConfig() {
    /bin/cat > "${dialogInspectModeJSONFile}" <<EOF
{
    "title": "Happy $( /bin/date +'%A' ), ${loggedInUserFirstname}!\n\nWe're starting to install ${title}.",
    "message": "Installing ${title} …",
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
        "Please wait while ${title} is being installed.",
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
            "id": "microsoftword",
            "displayName": "Microsoft Word",
            "guiIndex": 0,
            "paths": [
                "/Applications/Microsoft Word.app"
            ],
            "icon": "/Applications/Microsoft Word.app"
        },
        {
            "id": "microsoftexcel",
            "displayName": "Microsoft Excel",
            "guiIndex": 1,
            "paths": [
                "/Applications/Microsoft Excel.app"
            ],
            "icon": "/Applications/Microsoft Excel.app"
        },
        {
            "id": "microsoftpowerpoint",
            "displayName": "Microsoft PowerPoint",
            "guiIndex": 2,
            "paths": [
                "/Applications/Microsoft PowerPoint.app"
            ],
            "icon": "/Applications/Microsoft PowerPoint.app"
        },
        {
            "id": "microsoftoutlook",
            "displayName": "Microsoft Outlook",
            "guiIndex": 3,
            "paths": [
                "/Applications/Microsoft Outlook.app"
            ],
            "icon": "/Applications/Microsoft Outlook.app"
        },
        {
            "id": "microsoftonenote",
            "displayName": "Microsoft OneNote",
            "guiIndex": 4,
            "paths": [
                "/Applications/Microsoft OneNote.app"
            ],
            "icon": "/Applications/Microsoft OneNote.app"
        },
        {
            "id": "microsoftonedrive",
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
    /bin/echo "${dialogInspectModeJSONFile}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog Installation Functions (thanks, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogInstall() {
    dialogURL=$(/usr/bin/curl -L --silent --fail --connect-timeout 10 --max-time 30 \
        "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" \
        | /usr/bin/awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
    
    if [[ -z "${dialogURL}" ]]; then
        fatal "Failed to retrieve swiftDialog download URL from GitHub API"
    fi
    
    if [[ ! "${dialogURL}" =~ ^https://github\.com/ ]]; then
        fatal "Invalid swiftDialog URL format: ${dialogURL}"
    fi
    
    expectedDialogTeamID="PWA5E9TQ59"
    preFlight "Installing swiftDialog from ${dialogURL}..."
    
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    
    if ! /usr/bin/curl --location --silent --fail --connect-timeout 10 --max-time 60 \
             "$dialogURL" -o "$tempDirectory/Dialog.pkg"; then
        /bin/rm -Rf "$tempDirectory"
        fatal "Failed to download swiftDialog package"
    fi
    
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | /usr/bin/awk '/origin=/ {print $NF }' | /usr/bin/tr -d '()')
    
    if [[ "$expectedDialogTeamID" == "$teamID" ]]; then
        /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
        /bin/sleep 2
        dialogVersion=$( /usr/local/bin/dialog --version )
        preFlight "swiftDialog version ${dialogVersion} installed; proceeding..."
    else
        /usr/bin/osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "DDM OS Reminder Error" buttons {"Close"} with icon caution'
        exit "1"
    fi
    
    /bin/rm -Rf "$tempDirectory"
}

function dialogCheck() {
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
# Installomator Download
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function installomatorDownloadValidation() {
    actualHash=$( /usr/bin/shasum -a 256 "${organizationInstallomatorFile}" | /usr/bin/awk '{print $1}' )
    if [[ "${organizationInstallomatorURLHash}" == "${actualHash}" ]]; then
        preFlight "Installomator hash verified successfully: ${actualHash}"
        /bin/chmod +x "${organizationInstallomatorFile}"
    else
        preFlight "Installomator download hash mismatch!"
        preFlight "Expected: ${organizationInstallomatorURLHash}"
        preFlight "Actual:   ${actualHash}"
        /bin/rm -f "${organizationInstallomatorFile}"
        fatal "Hash mismatch! Possible tampering, corruption, or outdated hash."
    fi
}

function installomatorDownload() {
    /bin/mkdir -p "$(/usr/bin/dirname "${organizationInstallomatorFile}")"
    
    if [[ -e "${organizationInstallomatorFile}" ]]; then
        preFlight "Existing Installomator found; validating hash …"
        installomatorDownloadValidation
    else
        preFlight "Downloading Installomator from ${organizationInstallomatorURL} …"
        /usr/bin/curl --location --silent --fail --connect-timeout 10 --max-time 60 --retry 3 \
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
# Installomator Label Helpers (Inspect Mode JSON)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

installomatorLabelForApplicationPath() {
    inspectConfigPath="${1}"
    targetApplicationPath="${2}"
    /usr/bin/jq -r --arg path "${targetApplicationPath}" \
        '.items[] | select(.paths[]? == $path) | .id' \
        "${inspectConfigPath}" 2>/dev/null | /usr/bin/head -n 1
}

installomatorPathsForLabel() {
    inspectConfigPath="${1}"
    targetInstallomatorLabel="${2}"
    /usr/bin/jq -r --arg label "${targetInstallomatorLabel}" \
        '.items[] | select(.id == $label) | .paths[]?' \
        "${inspectConfigPath}" 2>/dev/null
}

installomatorLabelsFromInspectConfig() {
    inspectConfigPath="${1}"
    /usr/bin/jq -r '.items[]?.id' "${inspectConfigPath}" 2>/dev/null
}

installomatorLabelIsInstalled() {
    inspectConfigPath="${1}"
    targetInstallomatorLabel="${2}"
    
    installed="true"
    paths=$(installomatorPathsForLabel "${inspectConfigPath}" "${targetInstallomatorLabel}")
    
    if [[ -z "${paths}" ]]; then
        logComment "No paths defined for label '${targetInstallomatorLabel}'"
        installed="false"
    else
        while IFS= read -r path; do
            if [[ ! -e "${path}" ]]; then
                logComment "Missing path for label '${targetInstallomatorLabel}': ${path}"
                installed="false"
            else
                logComment "Found path for label '${targetInstallomatorLabel}': ${path}"
            fi
        done <<< "${paths}"
    fi
    
    if [[ "${installed}" == "true" ]]; then
        logComment "Label '${targetInstallomatorLabel}' is installed"
        return 0
    else
        logComment "Label '${targetInstallomatorLabel}' is NOT installed"
        return 1
    fi
}

installomatorInstallInspectItem() {
    local inspectConfigPath installomatorLabel installomatorExitCode dialogPID
    
    # Create Dialog configuration and ensure download directory exists
    notice "Create Dialog …"
    inspectConfigPath=$(createInspectConfig)
    /bin/mkdir -p "${organizationInstallomatorDownloadDirectory}"
    
    # Launch Dialog in background for real-time progress
    runAsUser DIALOG_INSPECT_CONFIG="${inspectConfigPath}" "${dialogBinary}" --inspect-mode &
    dialogPID=$!
    info "Inspect Mode PID: ${dialogPID}"
    
    # Process each Installomator label
    while IFS= read -r installomatorLabel; do
        [[ -z "${installomatorLabel}" ]] && continue
        
        notice "Processing Installomator Label: ${installomatorLabel}"
        
        # Skip if already installed
        if installomatorLabelIsInstalled "${inspectConfigPath}" "${installomatorLabel}"; then
            info "Label '${installomatorLabel}' already installed; skipping."
            continue
        fi
        
        # Install via Installomator
        notice "Installing '${installomatorLabel}' …"
        "${organizationInstallomatorFile}" "${installomatorLabel}" \
            DOWNLOAD_DIRECTORY="${organizationInstallomatorDownloadDirectory}" \
            DEBUG=0 NOTIFY=silent
        installomatorExitCode=$?
        
        [[ ${installomatorExitCode} -ne 0 ]] \
            && error "Installomator failed for '${installomatorLabel}' (exit code: ${installomatorExitCode})" \
            || info "Installomator completed for '${installomatorLabel}'"
            
    done <<< "$(installomatorLabelsFromInspectConfig "${inspectConfigPath}")"
    
    # Wait for Dialog to close
    info "Waiting for Inspect Mode (PID: ${dialogPID}) to close …"
    wait ${dialogPID}
    info "Inspect Mode closed."
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {
    exitCode="${1:-0}"
    
    notice "Exiting …"
    
    # Remove the dialog-related JSON files
    /bin/rm -f /var/tmp/dialogJSONFile_*
    
    # Remove overlay icon
    if [[ -f "${overlayicon}" ]] && [[ "${overlayicon}" != "/System/Library/CoreServices/Finder.app" ]]; then
        /bin/rm -f "${overlayicon}"
    fi
    
    # Remove default dialog.log
    /bin/rm -f /var/tmp/dialog.log
    
    info "Total Elapsed Time: $(/usr/bin/printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
    info "So long!"
    
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
    /usr/bin/touch "${scriptLog}"
    if [[ -f "${scriptLog}" ]]; then
        preFlight "Created specified scriptLog: ${scriptLog}"
    else
        fatal "Unable to create specified scriptLog '${scriptLog}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    if [[ -f "${scriptLog}" ]]; then
        logSize=$(/usr/bin/stat -f%z "${scriptLog}" 2>/dev/null || /bin/echo "0")
        maxLogSize=$((10 * 1024 * 1024))  # 10MB
        
        if (( logSize > maxLogSize )); then
            preFlight "Log file exceeds ${maxLogSize} bytes; rotating"
            /bin/mv "${scriptLog}" "${scriptLog}.$(/bin/date +%s).old"
            /usr/bin/touch "${scriptLog}"
            preFlight "Log file rotated"
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

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    fatal "ERROR: This script must be run as root; exiting."
else
    preFlight "Pre-flight Check: Running as root; proceeding …"
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

dialogCheck
installomatorDownload
installomatorInstallInspectItem
quitScript "0"