#!/bin/zsh --no-rcs
# shellcheck shell=bash

####################################################################################################
#
# swiftDialog Inspect Mode for Installomator
#
# - Installs Installomator Labels specified by:
#   `createInspectConfig` function > dialogInspectModeJSONFile > items:id
# - Monitors installation progress via swiftDialog 3.0.0 Inspect Mode
#
# https://snelson.us
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 05-Jan-2026, Dan K. Snelson (@dan-snelson)
#   - Original version
#
# Version 0.0.2, 13-Feb-2026, Dan K. Snelson (@dan-snelson)
#   - Removed check for swiftDialog
#   - Added Installomator phase logging for Downloading / Verifying / Installing
#
# Version 0.0.3, 14-Feb-2026, Dan K. Snelson (@dan-snelson)
#   - Added explicit Installomator log variable (`/private/var/log/Installomator.log`)
#   - Normalized Downloading / Verifying / Installing text sent to Inspect Mode
#   - Simplified list item install text to avoid duplicate "Installing Installing ..."
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

# Installomator Log
installomatorLog="/private/var/log/Installomator.log"

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
humanReadableScriptName="swiftDialog Inspect Mode for Installomator"

# Organization's Script Name
organizationScriptName="sDIMfI"

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

# swiftDialog Command File
dialogCommandFile=$( /usr/bin/mktemp /var/tmp/dialogCommandFile_${organizationScriptName}.XXXX )
/bin/chmod 666 "${dialogCommandFile}"

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
    if ! /bin/cat > "${dialogInspectModeJSONFile}" <<EOF
{
    "preset": "preset${organizationPreset}",
    "bannerimage": "${organizationBrandingBannerURL}",
    "title": "Happy $( /bin/date +'%A' ), ${loggedInUserFirstname}!\n\nWe're starting to install ${title}.",
    "bannertitle": "Happy $( /bin/date +'%A' ), ${loggedInUserFirstname}!\n\nWe're starting to install ${title}.",
    "message": "Installing ${title} …",
    "icon": "${applicationIcon}",
    "overlayicon": "${organizationOverlayiconURL}",
    "iconsize": 120,
    "size": "compact",
    "cachePaths": [
        "${organizationInstallomatorDownloadDirectory}/*.pkg",
        "/var/tmp/Installomator/downloads/Microsoft Word.pkg"
    ],
    "scanInterval": 5,
    "logMonitors": [
        {
            "path": "${scriptLog}",
            "pattern": "INFO][[:space:]]+((Downloading|Verifying|Installing).*)",
            "autoMatch": true
        },
        {
            "path": "${installomatorLog}",
            "pattern": ":[[:space:]]+((Downloading|Verifying|Installing).*)",
            "autoMatch": true
        }
    ],
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
            "icon": "https://usw2.ics.services.jamfcloud.com/icon/hash_51ae4c1e37bfbde2097e14712c3c13885157d632105804bcfaa912a627649b4c"
        },
        {
            "id": "microsoftexcel",
            "displayName": "Microsoft Excel",
            "guiIndex": 1,
            "paths": [
                "/Applications/Microsoft Excel.app"
            ],
            "icon": "https://usw2.ics.services.jamfcloud.com/icon/hash_9df1c82089b6a3ef006dc6a94995782e1809d6f9767c189a1608067a9f651ca9"
        },
        {
            "id": "microsoftpowerpoint",
            "displayName": "Microsoft PowerPoint",
            "guiIndex": 2,
            "paths": [
                "/Applications/Microsoft PowerPoint.app"
            ],
            "icon": "https://usw2.ics.services.jamfcloud.com/icon/hash_caadba785f099cec2bb510388390f5239c735a30723ba81b8a0e51792c4adff3"
        },
        {
            "id": "microsoftoutlook",
            "displayName": "Microsoft Outlook",
            "guiIndex": 3,
            "paths": [
                "/Applications/Microsoft Outlook.app"
            ],
            "icon": "https://usw2.ics.services.jamfcloud.com/icon/hash_e5b0c5b42d26e39431ecc7445ff0122e7d1a73d3487f55ca91b99523136b825d"
        },
        {
            "id": "microsoftonenote",
            "displayName": "Microsoft OneNote",
            "guiIndex": 4,
            "paths": [
                "/Applications/Microsoft OneNote.app"
            ],
            "icon": "https://usw2.ics.services.jamfcloud.com/icon/hash_e17f32e5366c1d5a3f29f67f8b38470144ecaf597435d2d46523fc1757382ec7"
        },
        {
            "id": "microsoftonedrive",
            "displayName": "OneDrive",
            "guiIndex": 5,
            "paths": [
                "/Applications/OneDrive.app"
            ],
            "icon": "https://usw2.ics.services.jamfcloud.com/icon/hash_72e08cf3b2dc4d168dc62faf4fc6821b0e0ec79f3382b1567a02b35176024adc"
        },
        {
            "id": "microsoftteamsnew",
            "displayName": "Microsoft Teams",
            "guiIndex": 6,
            "paths": [
                "/Applications/Microsoft Teams.app"
            ],
            "icon": "https://usw2.ics.services.jamfcloud.com/icon/hash_60344669638073113f3ca25e0a60e7080b5141536dbb62d8920d6e21fa70f877"
        }
    ]
}
EOF
    then
        fatal "Failed to create Dialog inspect config file"
    fi
    
    local jqValidationError
    jqValidationError=$(/usr/bin/jq empty "${dialogInspectModeJSONFile}" 2>&1)
    if [[ $? -ne 0 ]]; then
        fatal "Dialog inspect config JSON is malformed: ${jqValidationError}"
    fi

    return 0
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Installomator Download
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function installomatorDownloadValidation() {
    local actualHash
    
    actualHash=$( /usr/bin/shasum -a 256 "${organizationInstallomatorFile}" 2>/dev/null | /usr/bin/awk '{print $1}' )
    
    if [[ -z "${actualHash}" ]]; then
        fatal "Unable to calculate hash of ${organizationInstallomatorFile}"
    fi
    
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
        if ! /usr/bin/curl --location --silent --fail --connect-timeout 10 --max-time 60 --retry 3 \
            "${organizationInstallomatorURL}" \
            -o "${organizationInstallomatorFile}"; then
            fatal "Failed to download Installomator from ${organizationInstallomatorURL}"
        fi
        
        if [[ ! -e "${organizationInstallomatorFile}" || ! -s "${organizationInstallomatorFile}" ]]; then
            fatal "Downloaded Installomator file is empty or missing"
        fi
        
        installomatorDownloadValidation
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Installomator Label Helpers (Inspect Mode JSON)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

installomatorLabelForApplicationPath() {
    local inspectConfigPath="${1}"
    local targetApplicationPath="${2}"

    if [[ -z "${inspectConfigPath}" || ! -r "${inspectConfigPath}" ]]; then
        logComment "inspect config missing or unreadable: ${inspectConfigPath}"
        return 1
    fi

    /usr/bin/jq -r --arg path "${targetApplicationPath}" \
        '.items[] | select(.paths[]? == $path) | .id' \
        "${inspectConfigPath}" 2>/dev/null | /usr/bin/head -n 1
}

installomatorPathsForLabel() {
    local inspectConfigPath="${1}"
    local targetInstallomatorLabel="${2}"

    if [[ -z "${inspectConfigPath}" || ! -r "${inspectConfigPath}" ]]; then
        logComment "inspect config missing or unreadable: ${inspectConfigPath}"
        return 1
    fi

    /usr/bin/jq -r --arg label "${targetInstallomatorLabel}" \
        '.items[] | select(.id == $label) | .paths[]?' \
        "${inspectConfigPath}" 2>/dev/null
}

installomatorLabelsFromInspectConfig() {
    local inspectConfigPath="${1}"

    if [[ -z "${inspectConfigPath}" || ! -r "${inspectConfigPath}" ]]; then
        logComment "inspect config missing or unreadable: ${inspectConfigPath}"
        return 1
    fi

    /usr/bin/jq -r '.items[]?.id' "${inspectConfigPath}" 2>/dev/null
}

installomatorGUIIndexForLabel() {
    local inspectConfigPath="${1}"
    local targetInstallomatorLabel="${2}"

    if [[ -z "${inspectConfigPath}" || ! -r "${inspectConfigPath}" ]]; then
        return 1
    fi

    /usr/bin/jq -r --arg label "${targetInstallomatorLabel}" \
        '.items[] | select(.id == $label) | .guiIndex' \
        "${inspectConfigPath}" 2>/dev/null | /usr/bin/head -n 1
}

installomatorDisplayNameForLabel() {
    local inspectConfigPath="${1}"
    local targetInstallomatorLabel="${2}"

    if [[ -z "${inspectConfigPath}" || ! -r "${inspectConfigPath}" ]]; then
        return 1
    fi

    /usr/bin/jq -r --arg label "${targetInstallomatorLabel}" \
        '.items[] | select(.id == $label) | .displayName' \
        "${inspectConfigPath}" 2>/dev/null | /usr/bin/head -n 1
}

installomatorLabelIsInstalled() {
    local inspectConfigPath="${1}"
    local targetInstallomatorLabel="${2}"
    local paths
    local missing=false
    local path

    paths=$(installomatorPathsForLabel "${inspectConfigPath}" "${targetInstallomatorLabel}")

    if [[ -z "${paths}" ]]; then
        return 1
    fi

    while IFS= read -r path; do
        if [[ -z "${path}" ]]; then
            continue
        fi

        if [[ ! -e "${path}" ]]; then
            missing=true
        fi
    done <<< "${paths}"

    if [[ "${missing}" == false ]]; then
        return 0
    else
        return 1
    fi
}

installomatorPhaseFromLine() {
    local installomatorOutputLine="${1}"

    /bin/echo "${installomatorOutputLine}" | /usr/bin/sed -nE \
        's/.*:[[:space:]]*(Downloading|Verifying|Installing)(:|[[:space:]].*)?/\1/p' | /usr/bin/head -n 1
}

dialogUpdateInspectProgressText() {
    local progressText="${1}"

    if [[ -n "${progressText}" ]]; then
        /bin/echo "progresstext: ${progressText}" >> "${dialogCommandFile}"
    fi
}

dialogUpdateInspectListItemStatus() {
    local inspectConfigPath="${1}"
    local installomatorLabel="${2}"
    local statusText="${3}"
    local guiIndex

    [[ -z "${statusText}" ]] && return 0

    guiIndex=$(installomatorGUIIndexForLabel "${inspectConfigPath}" "${installomatorLabel}")

    if [[ -z "${guiIndex}" || "${guiIndex}" == "null" ]]; then
        return 0
    fi

    /bin/echo "listitem: index: ${guiIndex}, status: wait, statustext: ${statusText}" >> "${dialogCommandFile}"
}

installomatorInstallInspectItem() {
    local inspectConfigPath installomatorLabel installomatorExitCode dialogPID
    local installomatorOutputLine installomatorPhase installomatorDisplayName
    local installomatorProgressText installomatorListStatusText

    # Create Dialog configuration and ensure download directory exists
    notice "Create Dialog …"
    if ! createInspectConfig; then
        fatal "Failed to create Dialog inspect config"
    fi
    inspectConfigPath="${dialogInspectModeJSONFile}"

    if [[ -z "${inspectConfigPath}" || ! -r "${inspectConfigPath}" ]]; then
        fatal "Failed to create or read Dialog inspect config"
    fi

    /bin/mkdir -p "${organizationInstallomatorDownloadDirectory}"

    # Launch Dialog in background for real-time progress
    runAsUser DIALOG_INSPECT_CONFIG="${inspectConfigPath}" "${dialogBinary}" --inspect-mode --commandfile "${dialogCommandFile}" &
    dialogPID=$!
    info "Inspect Mode PID: ${dialogPID}"

    # Process each Installomator label (use process substitution to avoid extra subshells)
    while IFS= read -r installomatorLabel; do
        [[ -z "${installomatorLabel}" ]] && continue

        notice "Processing Installomator Label: ${installomatorLabel}"
        installomatorDisplayName=$(installomatorDisplayNameForLabel "${inspectConfigPath}" "${installomatorLabel}")
        if [[ -z "${installomatorDisplayName}" || "${installomatorDisplayName}" == "null" ]]; then
            installomatorDisplayName="${installomatorLabel}"
        fi

        # Skip if already installed
        if installomatorLabelIsInstalled "${inspectConfigPath}" "${installomatorLabel}"; then
            logComment "Label '${installomatorLabel}' already installed; skipping."
            continue
        fi

        # Install via Installomator
        notice "Installing '${installomatorLabel}' …"
        "${organizationInstallomatorFile}" "${installomatorLabel}" \
            DOWNLOAD_DIRECTORY="${organizationInstallomatorDownloadDirectory}" \
            DEBUG=0 NOTIFY=silent 2>&1 | while IFS= read -r installomatorOutputLine; do
                installomatorPhase=$(installomatorPhaseFromLine "${installomatorOutputLine}")
                if [[ -n "${installomatorPhase}" ]]; then
                    installomatorProgressText=""
                    installomatorListStatusText=""
                    case "${installomatorPhase}" in
                        Downloading)
                            installomatorProgressText="Downloading ${installomatorDisplayName} ..."
                            ;;
                        Verifying)
                            installomatorProgressText="Verifying ${installomatorDisplayName} ..."
                            ;;
                        Installing)
                            installomatorProgressText="Installing ${installomatorDisplayName} ..."
                            installomatorListStatusText="${installomatorDisplayName} ..."
                            ;;
                    esac

                    if [[ -n "${installomatorProgressText}" ]]; then
                        info "${installomatorProgressText}"
                        dialogUpdateInspectProgressText "${installomatorProgressText}"
                    fi

                    if [[ -n "${installomatorListStatusText}" ]]; then
                        dialogUpdateInspectListItemStatus "${inspectConfigPath}" "${installomatorLabel}" "${installomatorListStatusText}"
                    fi
                else
                    logComment "Installomator (${installomatorLabel}): ${installomatorOutputLine}"
                fi
            done
        installomatorExitCode=${pipestatus[1]}

        if [[ ${installomatorExitCode} -ne 0 ]]; then
            error "Installomator failed for '${installomatorLabel}' (exit code: ${installomatorExitCode})"
        else
            info "Installomator completed for '${installomatorLabel}'"
        fi

    done < <(installomatorLabelsFromInspectConfig "${inspectConfigPath}")

    # Wait for Dialog to close
    info "Waiting for Inspect Mode (PID: ${dialogPID}) to close …"
    wait "${dialogPID}"
    info "Inspect Mode closed."
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {
    exitCode="${1:-0}"
    
    notice "Exiting …"
    
    # Kill dialog process if still running
    if [[ -n "${dialogPID}" ]]; then
        if kill -0 "${dialogPID}" 2>/dev/null; then
            info "Terminating Inspect Mode (PID: ${dialogPID})"
            kill "${dialogPID}" 2>/dev/null || true
            /bin/sleep 1
        fi
    fi
    
    # Remove the dialog-related JSON files
    /bin/rm -f /var/tmp/dialogJSONFile_*
    
    # Remove overlay icon if it was downloaded
    if [[ -n "${overlayicon}" ]] && [[ -f "${overlayicon}" ]] && [[ "${overlayicon}" != "/System/Library/CoreServices/Finder.app" ]]; then
        /bin/rm -f "${overlayicon}"
    fi
    
    # Remove dialog command file and default dialog.log
    /bin/rm -f "${dialogCommandFile}"
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
        preFlight "Pause for 5 seconds to allow screen recording to be manually started."
        sleep 5
        preFlight "Continuing pre-flight checks …"
    else
        fatal "Unable to create specified scriptLog '${scriptLog}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
fi

if [[ ! -f "${installomatorLog}" ]]; then
    /usr/bin/touch "${installomatorLog}" 2>/dev/null
fi

if [[ -f "${installomatorLog}" ]]; then
    preFlight "Installomator log available: ${installomatorLog}"
else
    preFlight "Installomator log not available yet: ${installomatorLog} (continuing with stdout parsing)"
fi

# Check and rotate log if exceeds max size
logSize=$(/usr/bin/stat -f%z "${scriptLog}" 2>/dev/null || /bin/echo "0")
maxLogSize=$((10 * 1024 * 1024))  # 10MB

if (( logSize > maxLogSize )); then
    preFlight "Log file exceeds ${maxLogSize} bytes; rotating"
    if /bin/mv "${scriptLog}" "${scriptLog}.$(/bin/date +%s).old" 2>/dev/null; then
        /usr/bin/touch "${scriptLog}"
        preFlight "Log file rotated"
    else
        warning "Unable to rotate log file"
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

installomatorDownload
installomatorInstallInspectItem
quitScript 0
