#!/bin/zsh --no-rcs
# shellcheck shell=bash

####################################################################################################
#
# swiftDialog Template: Inspect Mode
#
# A template for scripts which leverage swiftDialog 3's new Inspect Mode (based on Mac Health Check)
#
# https://snelson.us
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 15-Nov-2025, Dan K. Snelson (@dan-snelson)
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

# Client-side Log
scriptLog="/var/log/org.churchofjesuschrist.log"

# Temporary log (per-run) that will be reordered into $scriptLog at exit
tmpScriptLog="${TMPDIR:-/private/tmp}/${organizationScriptName// /_}.${$}.log"
: > "${tmpScriptLog}"   # ensure it's empty

# Load is-at-least for version comparison
autoload -Uz is-at-least

# Minimum Required Version of swiftDialog
swiftDialogMinimumRequiredVersion="3.0.0.4916"

# Elapsed Time
SECONDS="0"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Operation Mode [ Test | Debug | Self Service | Silent ]
operationMode="${4:-"Debug"}"

    # Enable `set -x` if operation mode is "Debug" to help identify issues
    [[ "${operationMode}" == "Debug" ]] && set -x

# Parameter 5: Microsoft Teams or Slack Webhook URL [ Leave blank to disable (default) | https://microsoftTeams.webhook.com/URL | https://hooks.slack.com/services/URL ]
webhookURL="${5:-""}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readable Name
humanReadableScriptName="swiftDialog Inspect Mode"

# Organization's Script Name
organizationScriptName="sDIM"

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

# "Anticipation" Duration (in seconds)
if [[ "${operationMode}" == "Silent" ]]; then
    anticipationDuration="0"
else
    anticipationDuration="2"
fi

# Completion Timer (in seconds)
completionTimer="60"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Configuration Profile Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Organization's Client-side Jamf Pro Variables
jamfProVariables="org.churchofjesuschrist.jamfprovariables.plist"

# Property List File
plistFilepath="/Library/Managed Preferences/${jamfProVariables}"

if [[ -e "${plistFilepath}" ]]; then

    # Jamf Pro ID
    jamfProID=$( defaults read "${plistFilepath}" "Jamf Pro ID" 2>/dev/null )

    # Site Name
    jamfProSiteName=$( defaults read "${plistFilepath}" "Site Name" 2>/dev/null )

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Computer Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osVersion=$( sw_vers -productVersion )
osVersionExtra=$( sw_vers -productVersionExtra ) 
osBuild=$( sw_vers -buildVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
if [[ -n $osVersionExtra ]] && [[ "${osMajorVersion}" -ge 13 ]]; then osVersion="${osVersion} ${osVersionExtra}"; fi
serialNumber=$( ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}' )
computerName=$( scutil --get ComputerName | sed 's/’//' )
computerModel=$( sysctl -n hw.model )
localHostName=$( scutil --get LocalHostName )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logged-in User Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print ( $0 == toupper($0) ? toupper(substr($0,1,1))substr(tolower($0),2) : toupper(substr($0,1,1))substr($0,2) )}' )
loggedInUserID=$( id -u "${loggedInUser}" )



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

# swiftDialog JSON File
dialogJSONFile=$( mktemp -u /var/tmp/dialogJSONFile_${organizationScriptName}.XXXX )

# swiftDialog Inspect Mode JSON File
dialogInspectModeJSONFile=$( mktemp -u /var/tmp/dialogJSONFile_InspectMode_${organizationScriptName}.XXXX )

# swiftDialog Command File
dialogCommandFile=$( mktemp /var/tmp/dialogCommandFile_${organizationScriptName}.XXXX )

# Set Permissions on Dialog Command Files
chmod 644 "${dialogCommandFile}"

# The total number of steps for the progress bar (i.e., "progress: increment")
progressSteps="17"

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



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# IT Support Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

supportTeamName="IT Support"
supportTeamPhone="+1 (801) 555-1212"
supportTeamEmail="rescue@domain.org"
supportTeamWebsite="https://support.domain.org"
supportTeamHyperlink="[${supportTeamWebsite}](${supportTeamWebsite})"
supportKB="KB8675309"
infobuttonaction="https://servicenow.domain.org/support?id=kb_article_view&sysparm_article=${supportKB}"
supportKBURL="[${supportKB}](${infobuttonaction})"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Help Message Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

helpmessage="For assistance, please contact: **${supportTeamName}**<br>- **Telephone:** ${supportTeamPhone}<br>- **Email:** ${supportTeamEmail}<br>- **Website:** ${supportTeamWebsite}<br>- **Knowledge Base Article:** ${supportKBURL}<br><br>**User Information:**<br>- **Full Name:** ${loggedInUserFullname}<br>- **User Name:** ${loggedInUser}<br>- **User ID:** ${loggedInUserID}<br><br>**Computer Information:**<br>- **macOS:** ${osVersion} (${osBuild})<br>- **Dialog:** $(dialog -v)<br>- **Script:** ${scriptVersion}<br>- **Computer Name:** ${computerName}<br>- **Serial Number:** ${serialNumber}"

helpimage="qr=${infobuttonaction}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Main Dialog Window
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogJSON='
{
    "commandfile" : "'"${dialogCommandFile}"'",
    "bannerimage" : "'"${organizationBrandingBannerURL}"'",
    "bannertext" : "'"${humanReadableScriptName} (${scriptVersion})"'",
    "title" : "'"${humanReadableScriptName} (${scriptVersion})"'",
    "titlefont" : "shadow=true, size=36, colour=#FFFDF4",
    "ontop" : true,
    "moveable" : true,
    "windowbuttons" : "min",
    "quitkey" : "k",
    "icon" : "'"${icon}"'",
    "overlayicon" : "'"${overlayicon}"'",
    "message" : "none",
    "iconsize" : "198",
    "infobox" : "**User:** '"{userfullname}"'<br><br>**Computer Model:** '"{computermodel}"'<br><br>**Serial Number:** '"{serialnumber}"' ",
    "infobuttontext" : "'"${supportKB}"'",
    "infobuttonaction" : "'"${infobuttonaction}"'",
    "button1text" : "Wait",
    "button1disabled" : "true",
    "helpmessage" : "'"${helpmessage}"'",
    "helpimage" : "'"${helpimage}"'",
    "position" : "center",
    "progress" :  "'"${progressSteps}"'",
    "progresstext" : "Please wait …",
    "height" : "750",
    "width" : "975",
    "messagefont" : "size=14",
    "listitem" : [
        {"title" : "Title 01 goes here", "subtitle" : "Subtitle 01 goes here", "icon" : "SF=01.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 02 goes here", "subtitle" : "Subtitle 02 goes here", "icon" : "SF=02.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 03 goes here", "subtitle" : "Subtitle 03 goes here", "icon" : "SF=03.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 04 goes here", "subtitle" : "Subtitle 04 goes here", "icon" : "SF=04.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 05 goes here", "subtitle" : "Subtitle 05 goes here", "icon" : "SF=05.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 06 goes here", "subtitle" : "Subtitle 06 goes here", "icon" : "SF=06.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 07 goes here", "subtitle" : "Subtitle 07 goes here", "icon" : "SF=07.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 08 goes here", "subtitle" : "Subtitle 08 goes here", "icon" : "SF=08.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 09 goes here", "subtitle" : "Subtitle 09 goes here", "icon" : "SF=09.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 10 goes here", "subtitle" : "Subtitle 10 goes here", "icon" : "SF=10.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 11 goes here", "subtitle" : "Subtitle 11 goes here", "icon" : "SF=11.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 12 goes here", "subtitle" : "Subtitle 12 goes here", "icon" : "SF=12.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 13 goes here", "subtitle" : "Subtitle 13 goes here", "icon" : "SF=13.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 14 goes here", "subtitle" : "Subtitle 14 goes here", "icon" : "SF=14.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 15 goes here", "subtitle" : "Subtitle 15 goes here", "icon" : "SF=15.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 16 goes here", "subtitle" : "Subtitle 16 goes here", "icon" : "SF=16.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5},
        {"title" : "Title 17 goes here", "subtitle" : "Subtitle 17 goes here", "icon" : "SF=17.circle,'"${organizationColorScheme}"'", "status" : "pending", "statustext" : "Pending …", "iconalpha" : 0.5}
    ]
}
'

echo "${dialogJSON}" > "${dialogJSONFile}"



####################################################################################################
#
# Create swiftDialog Inspect Mode configuration
#
####################################################################################################

function createInspectConfig() {

    cat > "${dialogInspectModeJSONFile}" <<'EOF'
{
  "title": "Enrollment Progress Screen - Preset 1",
  "message": "Installing Office applications",
  "preset": "preset1",
  "icon": "/Library/Application Support/Dialog/Dialog.app",
  "iconsize": 120,
  "size": "compact",

  "cachePaths": [
    "/Library/Managed Installs/Cache",
    "/Library/Application Support/AirWatch/Data/Munki/Managed Installs/Cache",
    "/Library/Application Support/JAMF/Receipts"
  ],

  "sideMessage": [
    "This Enrollment includes essential productivity applications.",
    "The installation progress is automatically monitored.",
    "Please wait until all applications are completely installed.",
    "Your device will be ready for productive work once complete."
  ],
  "sideInterval": 8,

  "highlightColor": "#FF904C",
  "popupButton": "Installation Details...",

  "button1Text": "Please wait...",
  "button1Disabled": true,
  "button2Text": "Restart Later", 
  "button2Disabled": false,
  "button2Visible": true,
  "buttonStyle": "center",
  "autoEnableButton": true,

  "items": [
    {
      "id": "outlook",
      "displayName": "Microsoft Outlook",
      "guiIndex": 0,
      "paths": ["/Applications/Microsoft Outlook.app"],
      "icon": "https://apse2.ics.services.jamfcloud.com/icon/hash_a2bbe84f741a9fd7b524e5277467d84886545c04f6d3ea82dedbbca11adc3a57"
    },
    {
      "id": "excel",
      "displayName": "Microsoft Excel", 
      "guiIndex": 1,
      "paths": ["/Applications/Microsoft Excel.app"],
      "icon": "https://apse2.ics.services.jamfcloud.com/icon/hash_953c93b6a3d8b315733a3c6c8f01cf84306f76e53ed213216a22d7387dd24b17"
    },
    {
      "id": "word",
      "displayName": "Microsoft Word",
      "guiIndex": 2, 
      "paths": ["/Applications/Microsoft Word.app"],
      "icon": "https://apse2.ics.services.jamfcloud.com/icon/hash_a47fd5bb8f553b3eb62eef7ac7f732b2d96554327bd8365e7d8c7d569ee62a07"
    },
    {
      "id": "teams",
      "displayName": "Microsoft Teams",
      "guiIndex": 3,
      "paths": ["/Applications/Microsoft Teams.app"],
      "icon": "https://apse2.ics.services.jamfcloud.com/icon/hash_ddaf0a68208164124968f2682598638511f5f277a5924b05be24fc87e2e36fb3"
    },
    {
      "id": "powerpoint",
      "displayName": "Microsoft PowerPoint",
      "guiIndex": 4,
      "paths": ["/Applications/Microsoft PowerPoint.app"],
      "icon": "https://apse2.ics.services.jamfcloud.com/icon/hash_624c894823f7493dd8860f5cf7cc6c1dd49b09cd67c86aae61edc1d188a158d9"
    },
    {
      "id": "onenote", 
      "displayName": "Microsoft OneNote",
      "guiIndex": 5,
      "paths": ["/Applications/Microsoft OneNote.app"], 
      "icon": "https://apse2.ics.services.jamfcloud.com/icon/hash_0e78dd0798dad53052eda3fdaec736c07ea10b6d9322cf747dcd52ae8530eaf6"
    },
    {
      "id": "edge",
      "displayName": "Microsoft Edge",
      "guiIndex": 6,
      "paths": ["/Applications/Microsoft Edge.app"],
      "icon": "https://apse2.ics.services.jamfcloud.com/icon/hash_e8696f8104ff3ee2f3027faeffe9a6b541cfcaf6a24144d2da886cead0408477"
    }
  ]
}
EOF

    echo "${dialogInspectModeJSONFile}"

}



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    local stamp inputText normalized line out
    stamp="$( date '+%Y-%m-%d %H:%M:%S' )"
    inputText="${1-}"

    # If it contains literal backslash-n but no real newline, expand escapes to real newlines
    if [[ "${inputText}" == *'\n'* && "${inputText}" != *$'\n'* ]]; then
        normalized="$( printf '%b' "${inputText}" )"
    else
        normalized="${inputText}"
    fi

    if [[ "${normalized}" == *$'\n'* ]]; then
        # Multi-line: emit each line with the same timestamp
        while IFS= read -r line || [[ -n "${line}" ]]; do
            out="${organizationScriptName} (${scriptVersion}): ${stamp} - ${line}"
            printf '%s\n' "${out}"
            printf '%s\n' "${out}" >> "${tmpScriptLog}"
        done <<< "${normalized}"
    else
        # Single-line (original behavior)
        out="${organizationScriptName} (${scriptVersion}): ${stamp} - ${normalized}"
        printf '%s\n' "${out}"
        printf '%s\n' "${out}" >> "${tmpScriptLog}"
    fi
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
# Server-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Return the Jamf policy-log filepath, if we were launched by 'jamf'
function getJamfPolicyLogFile() {
    # Grab the full command used to launch us
    local cmd
    cmd="$(ps -p "${PPID}" -o command= 2>/dev/null)" || return 1
    # Prefer parsing the -policyLog flag (handles spaces cleanly)
    # Example: ... -policyLog '/path/with spaces/policy.log' ...
    if [[ "${cmd}" == *"-policyLog "* ]]; then
        # Extract the argument after -policyLog (single-quoted by jamf)
        printf '%s\n' "${cmd}" \
        | awk -F"-policyLog '" '{print $2}' \
        | awk -F"'" '{print $1}'
        return 0
    fi
    # Fallback: last single-quoted token (@isaacatmann technique)
    printf '%s\n' "${cmd}" \
    | awk -F"'" '{print $(NF-1)}'
}

# Prepend a block of text to a file using BSD sed (no temp files)
function prependToFile() {
    local file="$1" text="$2" esc
    [[ -f "$file" && -w "$file" ]] || return 0
    # Escape / and convert newlines -> \n for sed
    esc="${text//\//\\/}"
    esc="${esc//$'\n'/\\n}"
    # Insert a spacer, a divider, the text, another divider, spacer — all at top
    sed -i '' '1s/^/\n/' "$file"
    sed -i '' '1s/^/####################################################\n/' "$file"
    sed -i '' "1s/^/${esc}\n/" "$file"
    sed -i '' '1s/^/####################################################\n/' "$file"
    sed -i '' '1s/^/\n/' "$file"
}

# Reorder and write the final log (only prepends summary if errors exist)
function finalizeScriptLog() {
    local errorCount=0
    local errorLines="" errorList=""
    local summaryBlock=""

    # Collect [ERROR] and [WARNING] lines that contain a colon after the tag
    errorLines="$( grep -E '\[(ERROR|WARNING)\].*:' -- "${tmpScriptLog}" 2>/dev/null || true )"

    if [[ -n "${errorLines}" ]]; then
        # Count both ERROR and WARNING lines
        errorCount="$( printf '%s\n' "${errorLines}" | grep -E -c '\[(ERROR|WARNING)\]' || echo 0 )"

        # Format list (remove prefixing timestamp noise)
        errorList="$( printf '%s\n' "${errorLines}" | sed -E 's/^.* - \[ERROR\][[:space:]]+/- /; s/^.* - \[WARNING\][[:space:]]+/- /' )"

        summaryBlock="$(
            {
                printf '%s (%s) — [ERROR]/[WARNING] Summary\n' "${humanReadableScriptName}" "${scriptVersion}"
                printf 'Generated: %s\n\n' "$( date '+%Y-%m-%d %H:%M:%S' )"
                printf 'Total [ERROR]/[WARNING] entries: %s\n' "${errorCount}"
                printf '%s\n' "${errorList}"
            }
        )"
    fi

    # Always write the full chronological log for the local log file
    {
        [[ -n "${summaryBlock}" ]] && printf '%s\n\n' "${summaryBlock}"
        cat -- "${tmpScriptLog}"
    } > "${scriptLog}"

    # Only prepend the summary to the Jamf Policy Log if there were errors
    if [[ -n "${summaryBlock}" ]]; then
        if policyLogFile="$(getJamfPolicyLogFile)"; then
            if [[ -n "${policyLogFile}" && -f "${policyLogFile}" ]]; then
                prependToFile "${policyLogFile}" "${summaryBlock}"
            fi
        fi
    fi

    # Clean up temp log
    rm -f -- "${tmpScriptLog}" 2>/dev/null

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update the running dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdate(){
    if [[ "${operationMode}" != "Silent" ]]; then
        sleep 0.3
        echo "$1" >> "$dialogCommandFile"
    else
        # info "Operation Mode is 'Silent'; not updating dialog."
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Run command as logged-in user (thanks, @scriptingosx!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

    info "Run \"$@\" as \"$loggedInUserID\" … "
    launchctl asuser "$loggedInUserID" sudo -u "$loggedInUser" "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON via osascript and JavaScript
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function get_json_value() {
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env).$2"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Webhook Message (Microsoft Teams or Slack) (thanks, @robjschroeder! and @TechTrekkie!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function webHookMessage() {

    jamfProURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url 2>/dev/null)
    jamfProComputerURL="${jamfProURL}computers.html?query=${serialNumber}&queryType=COMPUTERS"

    timestamp="${timestamp:-$( date '+%Y-%m-%d %H:%M:%S' )}"

    # Normalize long list for webhook readability
    if [[ $(echo "${electronVulnerableApps}" | wc -w) -gt 50 ]]; then
        electronVulnerableApps="$(echo "${electronVulnerableApps}" | cut -c1-200)… (truncated)"
    fi

    if [[ $webhookURL == *"slack"* ]]; then
        
        info "Generating Slack Message …"
        
        webHookdata=$(cat <<EOF
        {
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "swiftDialog Template: '${webhookStatus}'",
                        "emoji": true
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        { "type": "mrkdwn", "text": "*Computer Name:*\n$( scutil --get ComputerName )" },
                        { "type": "mrkdwn", "text": "*Serial:*\n${serialNumber}" },
                        { "type": "mrkdwn", "text": "*Timestamp:*\n${timestamp}" },
                        { "type": "mrkdwn", "text": "*User:*\n${loggedInUser}" },
                        { "type": "mrkdwn", "text": "*OS Version:*\n${osVersion} (${osBuild})" },
                        { "type": "mrkdwn", "text": "*Health Failures:*\n${overallHealth%%; }" }
                    ]
                },
                {
                    "type": "actions",
                    "elements": [
                        {
                            "type": "button",
                            "text": {
                                "type": "plain_text",
                                "text": "View in Jamf Pro"
                            },
                            "style": "primary",
                            "url": "${jamfProComputerURL}"
                        }
                    ]
                }
            ]
        }
EOF
)

        # Send the message to Slack
        info "Send the message to Slack …"
        info "${webHookdata}"
        # Submit the data to Slack
        curl -sSX POST -H 'Content-type: application/json' --data "${webHookdata}" $webhookURL 2>&1
        webhookResult="$?"
        info "Slack Webhook Result: ${webhookResult}"

    else
        
        info "Generating Microsoft Teams Message …"

        webHookdata=$(cat <<EOF
        {
            "type": "message",
            "attachments": [
                {
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "contentUrl": null,
                    "content": {
                        "type": "AdaptiveCard",
                        "body": [
                            {
                                "type": "TextBlock",
                                "size": "Large",
                                "weight": "Bolder",
                                "text": "swiftDialog Template: ${webhookStatus}"
                            },
                            {
                                "type": "ColumnSet",
                                "columns": [
                                    {
                                        "type": "Column",
                                        "items": [
                                            {
                                                "type": "Image",
                                                "url": "https://beta.swiftdialog.app/_astro/dialog_logo.CZF0LABZ_ZjWz8w.webp",
                                                "altText": "swiftDialog Template",
                                                "size": "Small"
                                            }
                                        ],
                                        "width": "auto"
                                    },
                                    {
                                        "type": "Column",
                                        "items": [
                                            {
                                                "type": "TextBlock",
                                                "weight": "Bolder",
                                                "text": "$( scutil --get ComputerName )",
                                                "wrap": true
                                            },
                                            {
                                                "type": "TextBlock",
                                                "spacing": "None",
                                                "text": "${serialNumber}",
                                                "isSubtle": true,
                                                "wrap": true
                                            }
                                        ],
                                        "width": "stretch"
                                    }
                                ]
                            },
                            {
                                "type": "FactSet",
                                "facts": [
                                    { "title": "Timestamp", "value": "${timestamp}" },
                                    { "title": "User", "value": "${loggedInUser}" },
                                    { "title": "Operating System", "value": "${osVersion} (${osBuild})" },
                                    { "title": "Health Failures", "value": "${overallHealth%%; }" }
                                ]
                            }
                        ],
                        "actions": [
                            {
                                "type": "Action.OpenUrl",
                                "title": "View in Jamf Pro",
                                "url": "${jamfProComputerURL}"
                            }
                        ],
                        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                        "version": "1.2"
                    }
                }
            ]
        }
EOF
)

    # Send the message to Microsoft Teams
        info "Send the message to Microsoft Teams …"
        curl --silent \
            --request POST \
            --url "${webhookURL}" \
            --header 'Content-Type: application/json' \
            --data "${webHookdata}" \
            --output /dev/null

        webhookResult="$?"
        info "Microsoft Teams Webhook Result: ${webhookResult}"
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    quitOut "Exiting …"

    if [[ -n "${overallHealth}" ]]; then
        if [[ "${operationMode}" != "Silent" ]]; then
            dialogUpdate "icon: SF=xmark.circle, weight=bold, colour1=#BB1717, colour2=#F31F1F"
            dialogUpdate "title: Errors <br>as of $( date '+%d-%b-%Y %H:%M:%S' )"
        fi
        if [[ -n "${webhookURL}" ]]; then
            info "Sending webhook message"
            webhookStatus="Failures Detected (${#errorMessages[@]} errors)"
            webHookMessage
        fi
        errorOut "${overallHealth%%; }"
        exitCode="1"
    else
        if [[ "${operationMode}" != "Silent" ]]; then
            dialogUpdate "icon: SF=checkmark.circle, weight=bold, colour1=#00ff44, colour2=#075c1e"
            dialogUpdate "title: Computer Healthy <br>as of $( date '+%d-%b-%Y %H:%M:%S' )"
        fi
        exitCode="0"  # Explicitly set success status for clean exit
    fi

    if [[ "${operationMode}" != "Silent" ]]; then
        dialogUpdate "progress: 100"
        dialogUpdate "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"
        dialogUpdate "button1text: Close"
        dialogUpdate "button1: enable"
        
        sleep "${anticipationDuration}"

        # Progress countdown (thanks, @samg and @bartreadon!)
        dialogUpdate "progress: reset"
        while true; do
            if [[ ${completionTimer} -lt ${progressSteps} ]]; then
                dialogUpdate "progress: ${completionTimer}"
            fi
            dialogUpdate "progresstext: Closing automatically in ${completionTimer} seconds …"
            sleep 1
            ((completionTimer--))
            if [[ ${completionTimer} -lt 0 ]]; then break; fi
            if ! kill -0 "${dialogPID}" 2>/dev/null; then break; fi
        done
        dialogUpdate "quit:"
    fi

    # Remove the dialog command file
    rm -f "${dialogCommandFile}"

    # Remove the dialog-related JSON files
    if [[ "${operationMode}" == "Self Service" ]] || [[ "${operationMode}" == "Silent" ]]; then
        rm -f /var/tmp/dialogJSONFile_*
    else
        notice "${operationMode} mode: NOT deleting dialogJSONFile ${dialogJSONFile}"
        notice "${operationMode} mode: NOT deleting Inspect config ${dialogInspectModeJSONFile}"
    fi

    # Remove overlay icon
    if [[ -f "${overlayicon}" ]] && [[ "${overlayicon}" != "/System/Library/CoreServices/Finder.app" ]]; then
        rm -f "${overlayicon}"
    fi

    # Remove default dialog.log
    rm -f /var/tmp/dialog.log

    notice "Total Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

    quitOut "Goodbye!"

    exit "${exitCode}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Kill a specified process (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function killProcess() {
    process="$1"
    if process_pid=$( pgrep -a "${process}" 2>/dev/null ) ; then
        info "Attempting to terminate the '$process' process …"
        info "(Termination message indicates success.)"
        kill "$process_pid" 2> /dev/null
        if pgrep -a "$process" >/dev/null ; then
            error "'$process' could not be terminated."
        fi
    else
        info "The '$process' process isn’t running."
    fi
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
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# https://snelson.us\n#\n# Operation Mode: ${operationMode}\n####\n\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Computer Information
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "${computerName} (S/N ${serialNumber})"
preFlight "${loggedInUserFullname} (${loggedInUser}) [${loggedInUserID}]" 



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogInstall() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    preFlight "Installing swiftDialog..."

    # Create temporary working directory
    workDirectory=$( basename "$0" )
    tempDirectory=$( mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

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
        osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "swiftDialog Template Error" buttons {"Close"} with icon caution'
        completionActionOption="Quit"
        exitCode="1"
        quitScript

    fi

    # Remove the temporary working directory when done
    rm -Rf "$tempDirectory"

}



function dialogCheck() {

    # Check for Dialog and install if not found
    if [ ! -x "/Library/Application Support/Dialog/Dialog.app" ]; then

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

if [[ "${operationMode}" != "Silent" ]]; then
    dialogCheck
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Forcible-quit for all other running dialogs
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${operationMode}" != "Silent" ]]; then
    preFlight "Forcible-quit for all other running dialogs …"
    killProcess "Dialog"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Always publish the final, reordered log at exit (success or error)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

trap finalizeScriptLog EXIT



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Complete"



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Current Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

case ${operationMode} in

    "Debug" )

        notice "Operation Mode is ${operationMode}"

        inspectConfigPath=$(createInspectConfig)

        # Validate inspect config path
        if [[ -f "${inspectConfigPath}" ]]; then
            info "Inspect config located at: ${inspectConfigPath}"
        else
            fatal "Inspect config not found!"
        fi

        # Validate read access to inspect config
        if [[ ! -r "${inspectConfigPath}" ]]; then
            fatal "Inspect config not readable by ${loggedInUser}"
        fi

        # Run dialog with the env var in user context
        runAsUser \
            DIALOG_INSPECT_CONFIG="${inspectConfigPath}" \
            "${dialogBinary}" --inspect-mode --debug red &
        dialogPID=$!
        info "Inspect Mode PID: ${dialogPID}"

        # Wait for dialog to close before script exits
        info "Waiting for Inspect Mode (PID: ${dialogPID}) to close …"
        wait ${dialogPID}
        info "${operationMode} Operation Mode closed."

        ;;

    "Self Service" )

        notice "Operation Mode is ${operationMode}"

        inspectConfigPath=$(createInspectConfig)

        # Validate inspect config path
        if [[ -f "${inspectConfigPath}" ]]; then
            info "Inspect config located at: ${inspectConfigPath}"
        else
            fatal "Inspect config not found!"
        fi

        # Validate read access to inspect config
        if [[ ! -r "${inspectConfigPath}" ]]; then
            fatal "Inspect config not readable by ${loggedInUser}"
        fi

        # Run dialog with the env var in user context
        runAsUser \
            DIALOG_INSPECT_CONFIG="${inspectConfigPath}" \
            "${dialogBinary}" --inspect-mode &
        dialogPID=$!
        info "Inspect Mode PID: ${dialogPID}"

        # Wait for dialog to close before script exits
        info "Waiting for Inspect Mode (PID: ${dialogPID}) to close …"
        wait ${dialogPID}
        info "${operationMode} Operation Mode closed."

        ;;

    "Silent" )
        notice "Operation Mode is ${operationMode}; not displaying dialog."

        ;;

    "Test" | * )
        notice "Operation Mode is ${operationMode}"

        eval ${dialogBinary} --jsonfile ${dialogJSONFile} &
        dialogPID=$!
        info "Dialog PID: ${dialogPID}"
        dialogUpdate "progresstext: Initializing …"

        # Band-Aid for macOS 15+ `withAnimation` SwiftUI bug
        dialogUpdate "list: hide"
        dialogUpdate "list: show"

        # Display Test Mode
        dialogUpdate "title: ${humanReadableScriptName} (${scriptVersion})<br>Operation Mode: ${operationMode}"

        listitemLength=$(get_json_value "${dialogJSON}" "listitem.length")

        for (( i=0; i<listitemLength; i++ )); do

            notice "[Operation Mode: ${operationMode}] Check ${i} …"
            dialogUpdate "icon: SF=$(printf "%02d" $(($i+1))).square,${organizationColorScheme}"
            dialogUpdate "listitem: index: ${i}, icon: SF=$(printf "%02d" $(($i+1))).circle.fill $(echo "${organizationColorScheme}" | tr ',' ' '), iconalpha: 1, status: wait, statustext: Checking …"
            dialogUpdate "progress: increment"
            dialogUpdate "progresstext: [Operation Mode: ${operationMode}] • Item No. ${i} …"
            dialogUpdate "listitem: index: ${i}, icon: SF=$(printf "%02d" $(($i+1))).circle.fill weight=semibold colour=#63CA56, iconalpha: 0.6, status: success, statustext: ${operationMode}"

        done

        dialogUpdate "icon: ${icon}"
        dialogUpdate "progresstext: Final Analysis …"

        sleep "${anticipationDuration}"

        info "${operationMode} Operation Mode closed."

        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript
