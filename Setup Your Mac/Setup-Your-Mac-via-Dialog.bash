#!/bin/bash

####################################################################################################
#
# Setup Your Mac via swiftDialog
# https://snelson.us/setup-your-mac/
#
####################################################################################################
#
# HISTORY
#
#   Version 1.6.0, 09-Jan-2023, Dan K. Snelson (@dan-snelson)
#   - Addresses Issue Nos. 21 & 25
#
####################################################################################################



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
# Ensure computer does not go to sleep while running this script (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "Caffeinating this script (PID: $$)"
caffeinate -dimsu -w $$ &



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Setup Assistant has completed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

while pgrep -q -x "Setup Assistant"; do
    echo "Setup Assistant is still running; pausing for 2 seconds"
    sleep 2
done

echo "Setup Assistant is no longer running; proceeding …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm Dock is running / user is at Desktop
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

until pgrep -q -x "Finder" && pgrep -q -x "Dock"; do
    echo "Finder & Dock are NOT running; pausing for 1 second"
    sleep 1
done

echo "Finder & Dock are running; proceeding …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

if [[ -z "${loggedInUser}" || "${loggedInUser}" == "loginwindow" ]]; then
    echo "No user logged-in; exiting."
    exit 1
else
    loggedInUserID=$(id -u "${loggedInUser}")
fi



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version, Jamf Pro Script Parameters and default Exit Code
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="1.6.0-rc10"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
scriptLog="${4:-"/var/tmp/org.churchofjesuschrist.log"}"
debugMode="${5:-"true"}"                           # [ true (default) | false ]
welcomeDialog="${6:-"true"}"                       # [ true (default) | false ]
completionActionOption="${7:-"Restart Attended"}"  # [ wait | sleep (with seconds) | Shut Down | Shut Down Attended | Shut Down Confirm | Restart | Restart Attended (default) | Restart Confirm | Log Out | Log Out Attended | Log Out Confirm ]
reconOptions=""                                    # Initialize dynamic recon options; built based on user's input at Welcome dialog
exitCode="0"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Reflect Debug Mode in `infotext` (i.e., bottom, left-hand corner of each dialog)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${debugMode}" == "true" ]]; then
    scriptVersion="DEBUG MODE | Dialog: v$(dialog --version) • Setup Your Mac: v${scriptVersion}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog path, Command Files, JAMF binary, log files and currently logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogApp="/usr/local/bin/dialog"
welcomeCommandFile=$( mktemp /var/tmp/dialogWelcome.XXX )
setupYourMacCommandFile=$( mktemp /var/tmp/dialogSetupYourMac.XXX )
failureCommandFile=$( mktemp /var/tmp/dialogFailure.XXX )
jamfBinary="/usr/local/bin/jamf"
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | cut -d " " -f 1 )



####################################################################################################
#
# Welcome dialog
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome" dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeTitle="Welcome to your new Mac, ${loggedInUserFirstname}!"
welcomeMessage="To begin, please enter the required information below, then click **Continue** to start applying settings to your new Mac.  \n\nOnce completed, the **Quit** button will be re-enabled and you'll be prompted to restart your Mac.  \n\nIf you need assistance, please contact the Help Desk: +1 (801) 555-1212."

# Welcome icon set to either light or dark, based on user's Apperance setting (thanks, @mm2270!)
appleInterfaceStyle=$( /usr/bin/defaults read /Users/"${loggedInUser}"/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>&1 )
if [[ "${appleInterfaceStyle}" == "Dark" ]]; then
    welcomeIcon="https://cdn-icons-png.flaticon.com/512/740/740878.png"
else
    welcomeIcon="https://cdn-icons-png.flaticon.com/512/979/979585.png"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome" JSON (thanks, @bartreardon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeJSON='{
    "title" : "'"${welcomeTitle}"'",
    "message" : "'"${welcomeMessage}"'",
    "icon" : "'"${welcomeIcon}"'",
    "iconsize" : "198.0",
    "button1text" : "Continue",
    "button2text" : "Quit",
    "infotext" : "'"${scriptVersion}"'",
    "blurscreen" : "true",
    "ontop" : "true",
    "titlefont" : "size=26",
    "messagefont" : "size=16",
    "textfield" : [
        {   "title" : "Comment",
            "required" : false,
            "prompt" : "Enter a comment",
            "editor" : true
        },
        {   "title" : "Computer Name",
            "required" : false,
            "prompt" : "Computer Name"
        },
        {   "title" : "User Name",
            "required" : false,
            "prompt" : "User Name"
        },
        {   "title" : "Asset Tag",
            "required" : true,
            "prompt" : "Please enter the seven-digit Asset Tag",
            "regex" : "^(AP|IP)?[0-9]{7,}$",
            "regexerror" : "Please enter (at least) seven digits for the Asset Tag, optionally preceed by either AP or IP."
        }
    ],
  "selectitems" : [
        {   "title" : "Department",
            "default" : "Please select your department",
            "values" : [
                "Please select your department",
                "Asset Management",
                "Australia Area Office",
                "Board of Directors",
                "Business Development",
                "Corporate Communications",
                "Creative Services",
                "Customer Service / Customer Experience",
                "Engineering",
                "Finance / Accounting",
                "General Management",
                "Human Resources",
                "Information Technology / Technology",
                "Investor Relations",
                "Legal",
                "Marketing",
                "Operations",
                "Product Management",
                "Production",
                "Project Management Office",
                "Purchasing / Sourcing",
                "Quality Assurance",
                "Risk Management",
                "Sales",
                "Strategic Initiatives & Programs",
                "Technology"
            ]
        },
        {   "title" : "Select B",
            "values" : [
                "B1",
                "B2",
                "B3"
            ]
        },
        {   "title" : "Select C",
            "values" : [
                "C1",
                "C2",
                "C3"
            ]
        }
    ],
    "height" : "635"
}'



####################################################################################################
#
# Setup Your Mac dialog
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" dialog Title, Message, Overlay Icon and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Setting up ${loggedInUserFirstname}'s Mac"
message="Please wait while the following apps are installed …"
overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )

# Set initial icon based on whether the Mac is a desktop or laptop
if system_profiler SPPowerDataType | grep -q "Battery Power"; then
    icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
    icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSetupYourMacCMD="$dialogApp \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress \
--progresstext \"Initializing configuration …\" \
--button1text \"Wait\" \
--button1disabled \
--infotext \"$scriptVersion\" \
--titlefont 'size=28' \
--messagefont 'size=14' \
--height '80%' \
--position 'centre' \
--blurscreen \
--ontop \
--overlayicon \"$overlayicon\" \
--quitkey k \
--commandfile \"$setupYourMacCommandFile\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" policies to execute (Thanks, Obi-@smithjw!)
#
# For each configuration step, specify:
# - listitem: The text to be displayed in the list
# - icon: The hash of the icon to be displayed on the left
#   - See: https://vimeo.com/772998915
# - progresstext: The text to be displayed below the progress bar
# - trigger: The Jamf Pro Policy Custom Event Name
# - validation: [ {absolute path} | Local | Remote | None ]
#   See: https://snelson.us/2023/01/setup-your-mac-validation/
#       - {absolute path} (simulates pre-v1.6.0 behavior, for example: "/Applications/Microsoft Teams.app/Contents/Info.plist")
#       - Local (for validation within this script, for example: "filevault")
#       - Remote (for validation validation via a single-script Jamf Pro policy, for example: "symvGlobalProtect")
#       - None (for triggers which don't require validation, for example: recon)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# The fully qualified domain name of the server which hosts your icons, including any required sub-directories
setupYourMacPolicyArrayIconPrefixUrl="https://ics.services.jamfcloud.com/icon/hash_"

# shellcheck disable=SC1112 # use literal slanted single quotes for typographic reasons
policy_array=('
{
    "steps": [
        {
            "listitem": "FileVault Disk Encryption",
            "icon": "f9ba35bd55488783456d64ec73372f029560531ca10dfa0e8154a46d7732b913",
            "progresstext": "FileVault is built-in to macOS and provides full-disk encryption to help prevent unauthorized access to your Mac.",
            "trigger_list": [
                {
                    "trigger": "filevault",
                    "validation": "Local"
                }
            ]
        },
        {
            "listitem": "Sophos Endpoint",
            "icon": "c70f1acf8c96b99568fec83e165d2a534d111b0510fb561a283d32aa5b01c60c",
            "progresstext": "You’ll enjoy next-gen protection with Sophos Endpoint which doesn’t rely on signatures to catch malware.",
            "trigger_list": [
                {
                    "trigger": "sophosEndpoint",
                    "validation": "/Applications/Sophos/Sophos Endpoint.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Sophos Endpoint Services (Local)",
            "icon": "c05d087189f0b25a94f02eeb43b0c5c928e5e378f2168f603554bce2b5c71209",
            "progresstext": "Locally validating Sophos Endpoint Services …",
            "trigger_list": [
                {
                    "trigger": "sophosEndpointServices",
                    "validation": "Local"
                }
            ]
        },
        {
            "listitem": "Sophos Endpoint Services (Remote)",
            "icon": "c05d087189f0b25a94f02eeb43b0c5c928e5e378f2168f603554bce2b5c71209",
            "progresstext": "Remotely validating Sophos Endpoint Services …",
            "trigger_list": [
                {
                    "trigger": "symvSophosEndpointRTS",
                    "validation": "Remote"
                }
            ]
        },
        {
            "listitem": "Palo Alto GlobalProtect",
            "icon": "fcccf5d72ad9a4f6d3a4d780dcd8385378a0a8fd18e8c33ad32326f5bd53cca0",
            "progresstext": "Use Palo Alto GlobalProtect to establish a Virtual Private Network (VPN) connection to Church headquarters.",
            "trigger_list": [
                {
                    "trigger": "globalProtect",
                    "validation": "/Applications/GlobalProtect.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Palo Alto GlobalProtect Services (Local)",
            "icon": "709e8bdf0019e8faf9df85ec0a68545bfdb8bfa1227ac9bed9bba40a1fa8ff42",
            "progresstext": "Locally validating Palo Alto GlobalProtect Services …",
            "trigger_list": [
                {
                    "trigger": "globalProtect",
                    "validation": "Local"
                }
            ]
        },
        {
            "listitem": "Palo Alto GlobalProtect Services (Remote)",
            "icon": "709e8bdf0019e8faf9df85ec0a68545bfdb8bfa1227ac9bed9bba40a1fa8ff42",
            "progresstext": "Remotely validating Palo Alto GlobalProtect Services …",
            "trigger_list": [
                {
                    "trigger": "symvGlobalProtect",
                    "validation": "Remote"
                }
            ]
        },
        {
            "listitem": "Microsoft Teams",
            "icon": "dcb65709dba6cffa90a5eeaa54cb548d5ecc3b051f39feadd39e02744f37c19e",
            "progresstext": "Microsoft Teams is a hub for teamwork in Office 365. Keep all your team’s chats, meetings and files together in one place.",
            "trigger_list": [
                {
                    "trigger": "microsoftTeams",
                    "validation": "/Applications/Microsoft Teams.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Zoom",
            "icon": "be66420495a3f2f1981a49a0e0ad31783e9a789e835b4196af60554bf4c115ac",
            "progresstext": "Zoom is a videotelephony software program developed by Zoom Video Communications.",
            "trigger_list": [
                {
                    "trigger": "zoom",
                    "validation": "/Applications/zoom.us.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Google Chrome",
            "icon": "12d3d198f40ab2ac237cff3b5cb05b09f7f26966d6dffba780e4d4e5325cc701",
            "progresstext": "Google Chrome is a browser that combines a minimal design with sophisticated technology to make the Web faster.",
            "trigger_list": [
                {
                    "trigger": "googleChrome",
                    "validation": "/Applications/Google Chrome.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Final Configuration",
            "icon": "00d7c19b984222630f20b6821425c3548e4b5094ecd846b03bde0994aaf08826",
            "progresstext": "Finalizing Configuration …",
            "trigger_list": [
                {
                    "trigger": "finalConfiguration",
                    "validation": "None"
                },
                {
                    "trigger": "reconAtReboot",
                    "validation": "None"
                }
            ]
        },
        {
            "listitem": "Computer Inventory",
            "icon": "90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296",
            "progresstext": "A listing of your Mac’s apps and settings — its inventory — is sent automatically to the Jamf Pro server daily.",
            "trigger_list": [
                {
                    "trigger": "recon",
                    "validation": "None"
                }
            ]
        }
    ]
}
')



####################################################################################################
#
# Failure dialog
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

failureTitle="Failure Detected"
failureMessage="Placeholder message; update in the 'finalise' function"
failureIcon="SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogFailureCMD="$dialogApp \
--moveable \
--title \"$failureTitle\" \
--message \"$failureMessage\" \
--icon \"$failureIcon\" \
--iconsize 125 \
--width 625 \
--height 500 \
--position topright \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--titlefont 'size=22' \
--messagefont 'size=14' \
--overlayicon \"$overlayicon\" \
--commandfile \"$failureCommandFile\" "



#------------------------ With the execption of the `finalise` function, -------------------------#
#------------------------ edits below these line are optional. -----------------------------------#



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dynamically set `button1text` based on the value of `completionActionOption`
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case ${completionActionOption} in

    "Shut Down" )
        button1textCompletionActionOption="Shutting Down …"
        progressTextCompletionAction="shut down and "
        ;;

    "Shut Down "* )
        button1textCompletionActionOption="Shut Down"
        progressTextCompletionAction="shut down and "
        ;;

    "Restart" )
        button1textCompletionActionOption="Restarting …"
        progressTextCompletionAction="restart and "
        ;;

    "Restart "* )
        button1textCompletionActionOption="Restart"
        progressTextCompletionAction="restart and "
        ;;

    "Log Out" )
        button1textCompletionActionOption="Logging Out …"
        progressTextCompletionAction="log out and "
        ;;

    "Log Out "* )
        button1textCompletionActionOption="Log Out"
        progressTextCompletionAction="log out and "
        ;;

    "Sleep"* )
        button1textCompletionActionOption="Close"
        progressTextCompletionAction=""
        ;;

    "Quit" )
        button1textCompletionActionOption="Quit"
        progressTextCompletionAction=""
        ;;

    * )
        button1textCompletionActionOption="Close"
        progressTextCompletionAction=""
        ;;

esac



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
# Run command as logged-in user (thanks, @scriptingosx!)
# shellcheck disable=SC2145
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

    updateScriptLog "Run \"$@\" as \"$loggedInUserID\" … "
    launchctl asuser "$loggedInUserID" sudo -u "$loggedInUser" "$@"

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
        if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

            /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
            sleep 2
            updateScriptLog "swiftDialog version $(dialog --version) installed; proceeding..."

        else

            # Display a so-called "simple" dialog if Team ID fails to validate
            runAsUser osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
            completionActionOption="Quit"
            exitCode="1"
            quitScript

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        updateScriptLog "swiftDialog version $(dialog --version) found; proceeding..."

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update the "Welcome" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateWelcome(){
    updateScriptLog "WELCOME DIALOG: $1"
    echo "$1" >> "$welcomeCommandFile"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update the "Setup Your Mac" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateSetupYourMac() {
    updateScriptLog "SETUP YOUR MAC DIALOG: $1"
    echo "$1" >> "$setupYourMacCommandFile"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update the "Failure" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateFailure(){
    updateScriptLog "FAILURE DIALOG: $1"
    echo "$1" >> "$failureCommandFile"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Finalise User Experience
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function finalise(){

    if [[ "${jamfProPolicyTriggerFailure}" == "failed" ]]; then

        killProcess "caffeinate"
        updateScriptLog "Jamf Pro Policy Name Failures: ${jamfProPolicyPolicyNameFailures}"
        dialogUpdateSetupYourMac "title: Sorry ${loggedInUserFirstname}, something went sideways"
        dialogUpdateSetupYourMac "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
        dialogUpdateSetupYourMac "progresstext: Failures detected. Please click Continue for troubleshooting information."
        dialogUpdateSetupYourMac "button1text: Continue …"
        dialogUpdateSetupYourMac "button1: enable"
        dialogUpdateSetupYourMac "progress: complete"

        # Wait for user-acknowledgment due to detected failure
        wait

        dialogUpdateSetupYourMac "quit:"
        eval "${dialogFailureCMD}" & sleep 0.3

        dialogUpdateFailure "message: A failure has been detected, ${loggedInUserFirstname}.  \n\nPlease complete the following steps:\n1. Reboot and login to your Mac  \n2. Login to Self Service  \n3. Re-run any failed policy listed below  \n\nThe following failed:  \n${jamfProPolicyPolicyNameFailures}  \n\n\n\nIf you need assistance, please contact the Help Desk,  \n+1 (801) 555-1212, and mention [KB86753099](https://servicenow.company.com/support?id=kb_article_view&sysparm_article=KB86753099#Failures). "
        dialogUpdateFailure "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
        dialogUpdateFailure "button1text: ${button1textCompletionActionOption}"

        # Wait for user-acknowledgment due to detected failure
        wait

        dialogUpdateFailure "quit:"
        quitScript "1"

    else

        dialogUpdateSetupYourMac "title: ${loggedInUserFirstname}'s Mac is ready!"
        dialogUpdateSetupYourMac "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
        dialogUpdateSetupYourMac "progresstext: Complete! Please ${progressTextCompletionAction}enjoy your new Mac, ${loggedInUserFirstname}!"
        dialogUpdateSetupYourMac "progress: complete"
        dialogUpdateSetupYourMac "button1text: ${button1textCompletionActionOption}"
        dialogUpdateSetupYourMac "button1: enable"

        # If either "wait" or "sleep" has been specified for `completionActionOption`, honor that behavior
        if [[ "${completionActionOption}" == "wait" ]] || [[ "${completionActionOption}" == "[Ss]leep"* ]]; then
            updateScriptLog "Honoring ${completionActionOption} behavior …"
            eval "${completionActionOption}" "${dialogSetupYourMacProcessID}"
        fi

        quitScript "0"

    fi

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
# Parse JSON via osascript and JavaScript for the Welcome dialog (thanks, @bartreardon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function get_json_value_welcomeDialog () {
    for var in "${@:2}"; do jsonkey="${jsonkey}['${var}']"; done
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env)$jsonkey"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute Jamf Pro Policy Custom Events (thanks, @smithjw)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function run_jamf_trigger() {

    trigger="$1"

    if [[ "${debugMode}" == "true" ]]; then

        updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: TRIGGER: $jamfBinary policy -trigger $trigger"
        if [[ "$trigger" == "recon" ]]; then
            updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: RECON: $jamfBinary recon ${reconOptions}"
        fi
        sleep 1

    elif [[ "$trigger" == "recon" ]]; then

        dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Updating …, "
        updateScriptLog "SETUP YOUR MAC DIALOG: Updating computer inventory with the following reconOptions: \"${reconOptions}\" …"
        eval "${jamfBinary} recon ${reconOptions}"

    else

        updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary policy -trigger $trigger"
        eval "${jamfBinary} policy -trigger ${trigger}"                                     # Add comment for policy testing
        # eval "${jamfBinary} policy -trigger ${trigger} -verbose | tee -a ${scriptLog}"    # Remove comment for policy testing

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm Policy Execution
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function confirmPolicyExecution() {

    trigger="${1}"
    validation="${2}"

    updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: '${trigger}' '${validation}'"

    case ${validation} in

        */* ) # If the validation variable contains a forward slash (i.e., "/"), presume it's a path and check if that path exists on disk
            if [[ -f "${validation}" ]]; then
                updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation} exists, moving on"
                if [[ "${debugMode}" == "true" ]]; then sleep 0.5; fi
            else
                run_jamf_trigger "${trigger}"
            fi
            ;;

        "None" )
            updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation}"
            ;;

        * )
            updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution Catch-all: ${validation}"
            ;;

    esac

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Policy Result
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validatePolicyResult() {

    trigger="${1}"
    validation="${2}"

    updateScriptLog "SETUP YOUR MAC DIALOG: Validate Policy Result: '${trigger}' '${validation}'"

    case ${validation} in

        ###
        # Absolute Path
        # Simulates pre-v1.6.0 behavior, for example: "/Applications/Microsoft Teams.app/Contents/Info.plist"
        ###

        */* ) 
            updateScriptLog "SETUP YOUR MAC DIALOG: Validate Policy Result: Testing for \"$validation\" …"
            if [[ -f "${validation}" ]]; then
                dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Installed"
            else
                dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                jamfProPolicyTriggerFailure="failed"
                exitCode="1"
                jamfProPolicyPolicyNameFailures+="• $listitem  \n"
            fi
            ;;



        ###
        # Local
        # Validation within this script, for example: "filevault"
        ###

        "Local" )
            case ${trigger} in
                filevault )
                   updateScriptLog "Validate FileVault … "
                    dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Checking …"
                    if [[ -f /Library/Preferences/com.apple.fdesetup.plist ]]; then
                        fileVaultStatus=$( fdesetup status -extended -verbose 2>&1 )
                        case ${fileVaultStatus} in
                            *"FileVault is On."* ) 
                                updateScriptLog "FileVault: FileVault is On."
                                dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Enabled"
                                ;;
                            *"Deferred enablement appears to be active for user"* )
                                updateScriptLog "FileVault: Enabled"
                                dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Enabled (next login)"
                                ;;
                            *  )
                                dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Unknown"
                                jamfProPolicyTriggerFailure="failed"
                                exitCode="1"
                                jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                                ;;
                        esac
                    else
                        updateScriptLog "'/Library/Preferences/com.apple.fdesetup.plist' NOT Found"
                        dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                        jamfProPolicyTriggerFailure="failed"
                        exitCode="1"
                        jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                    fi
                    ;;
                sophosEndpointServices )
                    updateScriptLog "Validate Sophos Endpoint RTS Status … "
                    dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Checking …"
                    if [[ -d /Applications/Sophos/Sophos\ Endpoint.app ]]; then
                        if [[ -f /Library/Preferences/com.sophos.sav.plist ]]; then
                            sophosOnAccessRunning=$( /usr/bin/defaults read /Library/Preferences/com.sophos.sav.plist OnAccessRunning )
                            case ${sophosOnAccessRunning} in
                                "0" ) 
                                    updateScriptLog "Sophos Endpoint RTS Status: Disabled"
                                    dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                                    jamfProPolicyTriggerFailure="failed"
                                    exitCode="1"
                                    jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                                    ;;
                                "1" )
                                    updateScriptLog "Sophos Endpoint RTS Status: Enabled"
                                    dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Running"
                                    ;;
                                *  )
                                    updateScriptLog "Sophos Endpoint RTS Status: Unknown"
                                    dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Unknown"
                                    jamfProPolicyTriggerFailure="failed"
                                    exitCode="1"
                                    jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                                    ;;
                            esac
                        else
                            updateScriptLog "Sophos Endpoint Not Found"
                            dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                            jamfProPolicyTriggerFailure="failed"
                            exitCode="1"
                            jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                        fi
                    else
                        dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                        jamfProPolicyTriggerFailure="failed"
                        exitCode="1"
                        jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                    fi
                    ;;
                globalProtect )
                    updateScriptLog "Validate Palo Alto Networks GlobalProtect Status … "
                    dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Checking …"
                    if [[ -d /Applications/GlobalProtect.app ]]; then
                        updateScriptLog "Pausing for 10 seconds to allow Palo Alto Networks GlobalProtect Services … "
                        sleep 10 # Arbitrary value; tuning needed
                        if [[ -f /Library/Preferences/com.paloaltonetworks.GlobalProtect.settings.plist ]]; then
                            globalProtectStatus=$( /usr/libexec/PlistBuddy -c "print :Palo\ Alto\ Networks:GlobalProtect:PanGPS:disable-globalprotect" /Library/Preferences/com.paloaltonetworks.GlobalProtect.settings.plist )
                            case "${globalProtectStatus}" in
                                "0" )
                                    updateScriptLog "Palo Alto Networks GlobalProtect Status: Enabled"
                                    dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Running"
                                    ;;
                                "1" )
                                    updateScriptLog "Palo Alto Networks GlobalProtect Status: Disabled"
                                    dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                                    jamfProPolicyTriggerFailure="failed"
                                    exitCode="1"
                                    jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                                    ;;
                                *  )
                                    updateScriptLog "Palo Alto Networks GlobalProtect Status: Unknown"
                                    dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Unknown"
                                    jamfProPolicyTriggerFailure="failed"
                                    exitCode="1"
                                    jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                                    ;;
                            esac
                        else
                            updateScriptLog "Palo Alto Networks GlobalProtect Not Found"
                            dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                            jamfProPolicyTriggerFailure="failed"
                            exitCode="1"
                            jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                        fi
                    else
                        dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                        jamfProPolicyTriggerFailure="failed"
                        exitCode="1"
                        jamfProPolicyPolicyNameFailures+="• $listitem  \n"
                    fi
                    ;;
                * ) updateScriptLog "SETUP YOUR MAC DIALOG: Validate Policy Results Local Catch-all: ${validation}" ;;
            esac
            ;;



        ###
        # Remote
        # Validation via a Jamf Pro policy which has a single-script payload, for example: "symvGlobalProtect"
        # See: https://vimeo.com/782561166
        ###

        "Remote" )
            updateScriptLog "Validate '${trigger}' '${validation}'"
            dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Checking …"
            result=$( "${jamfBinary}" policy -trigger "${trigger}" | grep "Script result:" )
            if [[ "${result}" == *"Running"* ]]; then
                dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Running"
            else
                dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
                jamfProPolicyTriggerFailure="failed"
                exitCode="1"
                jamfProPolicyPolicyNameFailures+="• $listitem  \n"
            fi
            ;;



        ###
        # None
        # For triggers which don't require validation, for example: recon
        ###

        "None" )
            updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation}"
            dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Installed"
            if [[ "${trigger}" == "recon" ]]; then
                dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Updating …, "
                updateScriptLog "SETUP YOUR MAC DIALOG: Updating computer inventory with the following reconOptions: \"${reconOptions}\" …"
                if [[ "${debugMode}" == "true" ]]; then
                    updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: eval ${jamfBinary} recon ${reconOptions}"
                else
                    eval "${jamfBinary} recon ${reconOptions}"
                fi
                dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Updated"
            fi
            ;;



        ###
        # Catch-all
        ###

        * )
            updateScriptLog "SETUP YOUR MAC DIALOG: Validate Policy Results Catch-all: ${validation}"
            dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
            jamfProPolicyTriggerFailure="failed"
            exitCode="1"
            jamfProPolicyPolicyNameFailures+="• $listitem  \n"
            ;;

    esac

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Kill a specified process (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function killProcess() {
    process="$1"
    if process_pid=$( pgrep -a "${process}" 2>/dev/null ) ; then
        updateScriptLog "Attempting to terminate the '$process' process …"
        updateScriptLog "(Termination message indicates success.)"
        kill "$process_pid" 2> /dev/null
        if pgrep -a "$process" >/dev/null ; then
            updateScriptLog "ERROR: '$process' could not be terminated."
        fi
    else
        updateScriptLog "The '$process' process isn't running."
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Completion Action (i.e., Wait, Sleep, Logout, Restart or Shutdown)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function completionAction() {

    if [[ "${debugMode}" == "true" ]]; then

        # If Debug Mode is enabled, ignore specified `completionActionOption`, display simple dialog box and exit
        runAsUser osascript -e 'display dialog "Setup Your Mac is operating in Debug Mode.\r\r• completionActionOption == '"'${completionActionOption}'"'\r\r" with title "Setup Your Mac: Debug Mode" buttons {"Close"} with icon note'
        exitCode="0"

    else

        shopt -s nocasematch

        case ${completionActionOption} in

            "Shut Down" )
                updateScriptLog "Shut Down sans user interaction"
                killProcess "Self Service"
                # runAsUser osascript -e 'tell app "System Events" to shut down'
                sleep 5 && runAsUser osascript -e 'tell app "System Events" to shut down' &
                # shutdown -h +1 &
                ;;

            "Shut Down Attended" )
                updateScriptLog "Shut Down, requiring user-interaction"
                killProcess "Self Service"
                wait
                # runAsUser osascript -e 'tell app "System Events" to shut down'
                sleep 5 && runAsUser osascript -e 'tell app "System Events" to shut down' &
                # shutdown -h +1 &
                ;;

            "Shut Down Confirm" )
                updateScriptLog "Shut down, only after macOS time-out or user confirmation"
                runAsUser osascript -e 'tell app "loginwindow" to «event aevtrsdn»'
                ;;

            "Restart" )
                updateScriptLog "Restart sans user interaction"
                killProcess "Self Service"
                # runAsUser osascript -e 'tell app "System Events" to restart'
                sleep 5 && runAsUser osascript -e 'tell app "System Events" to restart' &
                # shutdown -r +1 &
                ;;

            "Restart Attended" )
                updateScriptLog "Restart, requiring user-interaction"
                killProcess "Self Service"
                wait
                # runAsUser osascript -e 'tell app "System Events" to restart'
                sleep 5 && runAsUser osascript -e 'tell app "System Events" to restart' &
                # shutdown -r +1 &
                ;;

            "Restart Confirm" )
                updateScriptLog "Restart, only after macOS time-out or user confirmation"
                runAsUser osascript -e 'tell app "loginwindow" to «event aevtrrst»'
                ;;

            "Log Out" )
                updateScriptLog "Log out sans user interaction"
                killProcess "Self Service"
                # runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
                sleep 5 && runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»' &
                # launchctl bootout user/"${loggedInUserID}"
                ;;

            "Log Out Attended" )
                updateScriptLog "Log out sans user interaction"
                killProcess "Self Service"
                wait
                # runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
                sleep 5 && runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»' &
                # launchctl bootout user/"${loggedInUserID}"
                ;;

            "Log Out Confirm" )
                updateScriptLog "Log out, only after macOS time-out or user confirmation"
                runAsUser osascript -e 'tell app "System Events" to log out'
                ;;

            "Sleep"* )
                sleepDuration=$( awk '{print $NF}' <<< "${1}" )
                updateScriptLog "Sleeping for ${sleepDuration} seconds …"
                sleep "${sleepDuration}"
                killProcess "Dialog"
                updateScriptLog "Goodnight!"
                ;;

            "Quit" )
                updateScriptLog "Quitting script"
                exitCode="0"
                ;;

            * )
                updateScriptLog "Using the default of 'wait'"
                wait
                ;;

        esac

        shopt -u nocasematch

    fi

    exit "${exitCode}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Exiting …"

    # Stop `caffeinate` process
    updateScriptLog "De-caffeinate …"
    killProcess "caffeinate"

    # Remove welcomeCommandFile
    if [[ -e ${welcomeCommandFile} ]]; then
        updateScriptLog "Removing ${welcomeCommandFile} …"
        rm "${welcomeCommandFile}"
    fi

    # Remove setupYourMacCommandFile
    if [[ -e ${setupYourMacCommandFile} ]]; then
        updateScriptLog "Removing ${setupYourMacCommandFile} …"
        rm "${setupYourMacCommandFile}"
    fi

    # Remove failureCommandFile
    if [[ -e ${failureCommandFile} ]]; then
        updateScriptLog "Removing ${failureCommandFile} …"
        rm "${failureCommandFile}"
    fi

    # Remove any default dialog file
    if [[ -e /var/tmp/dialog.log ]]; then
        updateScriptLog "Removing default dialog file …"
        rm /var/tmp/dialog.log
    fi

    # Check for user clicking "Quit" at Welcome dialog
    if [[ "${welcomeReturnCode}" == "2" ]]; then
        exitCode="1"
        exit "${exitCode}"
    else
        updateScriptLog "Executing Completion Action Option: '${completionActionOption}' …"
        completionAction "${completionActionOption}"
    fi

}



####################################################################################################
#
# Program
#
####################################################################################################

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

if [[ "${debugMode}" == "true" ]]; then
    updateScriptLog "\n\n###\n# ${scriptVersion}\n###\n"
else
    updateScriptLog "\n\n###\n# Setup Your Mac (${scriptVersion})\n###\n"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# If Debug Mode is enabled, replace `blurscreen` with `movable`
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${debugMode}" == "true" ]]; then
    welcomeJSON=${welcomeJSON//blurscreen/moveable}
    dialogSetupYourMacCMD=${dialogSetupYourMacCMD//blurscreen/moveable}
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Write Welcome JSON to disk
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "$welcomeJSON" > "$welcomeCommandFile"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Welcome dialog and capture user's input
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${welcomeDialog}" == "true" ]]; then

    welcomeResults=$( ${dialogApp} --jsonfile "$welcomeCommandFile" --json )
    if [[ -z "${welcomeResults}" ]]; then
        welcomeReturnCode="2"
    else
        welcomeReturnCode="0"
    fi

    case "${welcomeReturnCode}" in

        0)  # Process exit code 0 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} entered information and clicked Continue"

            ###
            # Extract the various values from the welcomeResults JSON
            ###

            comment=$(get_json_value_welcomeDialog "$welcomeResults" "Comment")
            computerName=$(get_json_value_welcomeDialog "$welcomeResults" "Computer Name")
            userName=$(get_json_value_welcomeDialog "$welcomeResults" "User Name")
            assetTag=$(get_json_value_welcomeDialog "$welcomeResults" "Asset Tag")
            department=$(get_json_value_welcomeDialog "$welcomeResults" "Department" "selectedValue")
            selectB=$(get_json_value_welcomeDialog "$welcomeResults" "Select B" "selectedValue")
            selectC=$(get_json_value_welcomeDialog "$welcomeResults" "Select C" "selectedValue")



            ###
            # Output the various values from the welcomeResults JSON to the log file
            ###

            updateScriptLog "WELCOME DIALOG: • Comment: $comment"
            updateScriptLog "WELCOME DIALOG: • Computer Name: $computerName"
            updateScriptLog "WELCOME DIALOG: • User Name: $userName"
            updateScriptLog "WELCOME DIALOG: • Asset Tag: $assetTag"
            updateScriptLog "WELCOME DIALOG: • Department: $department"
            updateScriptLog "WELCOME DIALOG: • Select B: $selectB"
            updateScriptLog "WELCOME DIALOG: • Select C: $selectC"



            ###
            # Evaluate Various User Input
            ###

            # Computer Name
            if [[ -n "${computerName}" ]]; then

                # UNTESTED, UNSUPPORTED "YOYO" EXAMPLE
                updateScriptLog "WELCOME DIALOG: Set Computer Name …"
                currentComputerName=$( scutil --get ComputerName )
                currentLocalHostName=$( scutil --get LocalHostName )

                # Sets LocalHostName to a maximum of 15 characters, comprised of first eight characters of the computer's
                # serial number and the last six characters of the client's MAC address
                firstEightSerialNumber=$( system_profiler SPHardwareDataType | awk '/Serial\ Number\ \(system\)/ {print $NF}' | cut -c 1-8 )
                lastSixMAC=$( ifconfig en0 | awk '/ether/ {print $2}' | sed 's/://g' | cut -c 7-12 )
                newLocalHostName=${firstEightSerialNumber}-${lastSixMAC}

                if [[ "${debugMode}" == "true" ]]; then

                    updateScriptLog "WELCOME DIALOG: DEBUG MODE: Renamed computer from: \"${currentComputerName}\" to \"${computerName}\" "
                    updateScriptLog "WELCOME DIALOG: DEBUG MODE: Renamed LocalHostName from: \"${currentLocalHostName}\" to \"${newLocalHostName}\" "

                else

                    # Set the Computer Name to the user-entered value
                    scutil --set ComputerName "${computerName}"

                    # Set the LocalHostName to `newLocalHostName`
                    scutil --set LocalHostName "${newLocalHostName}"

                    # Delay required to reflect change …
                    # … side-effect is a delay in the "Setup Your Mac" dialog appearing
                    sleep 5
                    updateScriptLog "WELCOME DIALOG: Renamed computer from: \"${currentComputerName}\" to \"$( scutil --get ComputerName )\" "
                    updateScriptLog "WELCOME DIALOG: Renamed LocalHostName from: \"${currentLocalHostName}\" to \"$( scutil --get LocalHostName )\" "

                fi

            else

                updateScriptLog "WELCOME DIALOG: ${loggedInUser} did NOT specify a new computer name"
                updateScriptLog "WELCOME DIALOG: • Current Computer Name: \"$( scutil --get ComputerName )\" "
                updateScriptLog "WELCOME DIALOG: • Current Local Host Name: \"$( scutil --get LocalHostName )\" "

            fi

            # User Name
            if [[ -n "${userName}" ]]; then
                # UNTESTED, UNSUPPORTED "YOYO" EXAMPLE
                reconOptions+="-endUsername \"${userName}\" "
            fi

            # Asset Tag
            if [[ -n "${assetTag}" ]]; then
                reconOptions+="-assetTag \"${assetTag}\" "
            fi

            # Department
            if [[ -n "${department}" ]]; then
                # UNTESTED, UNSUPPORTED "YOYO" EXAMPLE
                reconOptions+="-department \"${department}\" "
            fi

            # Output `recon` options to log
            updateScriptLog "WELCOME DIALOG: reconOptions: ${reconOptions}"

            ###
            # Display "Setup Your Mac" dialog (and capture Process ID)
            ###

            eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
            dialogSetupYourMacProcessID=$!
            ;;

        2)  # Process exit code 2 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} clicked Quit at Welcome dialog"
            completionActionOption="Quit"
            quitScript "1"
            ;;

        3)  # Process exit code 3 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} clicked infobutton"
            osascript -e "set Volume 3"
            afplay /System/Library/Sounds/Glass.aiff
            ;;

        4)  # Process exit code 4 scenario here
            updateScriptLog "WELCOME DIALOG: ${loggedInUser} allowed timer to expire"
            quitScript "1"
            ;;

        *)  # Catch all processing
            updateScriptLog "WELCOME DIALOG: Something else happened; Exit code: ${welcomeReturnCode}"
            quitScript "1"
            ;;

    esac

else

    ###
    # Display "Setup Your Mac" dialog (and capture Process ID)
    ###

    eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
    dialogSetupYourMacProcessID=$!

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Iterate through policy_array JSON to construct the list for swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialog_step_length=$(get_json_value "${policy_array[*]}" "steps.length")
for (( i=0; i<dialog_step_length; i++ )); do
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    list_item_array+=("$listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    icon_url_array+=("$icon")
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set progress_total to the number of steps in policy_array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_total=$(get_json_value "${policy_array[*]}" "steps.length")
updateScriptLog "SETUP YOUR MAC DIALOG: progress_total=$progress_total"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# The ${array_name[*]/%/,} expansion will combine all items within the array adding a "," character at the end
# To add a character to the start, use "/#/" instead of the "/%/"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

list_item_string=${list_item_array[*]/%/,}
dialogUpdateSetupYourMac "list: ${list_item_string%?}"
for (( i=0; i<dialog_step_length; i++ )); do
    dialogUpdateSetupYourMac "listitem: index: $i, icon: ${setupYourMacPolicyArrayIconPrefixUrl}${icon_url_array[$i]}, status: pending, statustext: Pending …"
done
dialogUpdateSetupYourMac "list: show"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set initial progress bar
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_index=0
dialogUpdateSetupYourMac "progress: $progress_index"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Close Welcome dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogUpdateWelcome "quit:"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# This for loop will iterate over each distinct step in the policy_array array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

for (( i=0; i<dialog_step_length; i++ )); do

    # Increment the progress bar
    dialogUpdateSetupYourMac "progress: $(( i * ( 100 / progress_total ) ))"

    # Creating initial variables
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    progresstext=$(get_json_value "${policy_array[*]}" "steps[$i].progresstext")

    trigger_list_length=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list.length")

    # If there's a value in the variable, update running swiftDialog
    if [[ -n "$listitem" ]]; then dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Installing …, "; fi
    if [[ -n "$icon" ]]; then dialogUpdateSetupYourMac "icon: ${setupYourMacPolicyArrayIconPrefixUrl}${icon}"; fi
    if [[ -n "$progresstext" ]]; then dialogUpdateSetupYourMac "progresstext: $progresstext"; fi
    if [[ -n "$trigger_list_length" ]]; then

        for (( j=0; j<trigger_list_length; j++ )); do

            # Setting variables within the trigger_list
            trigger=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].trigger")
            validation=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].validation")
            case ${validation} in
                "Local" | "Remote" )
                    updateScriptLog "SETUP YOUR MAC DIALOG: Skipping Policy Execution due to '${validation}' validation"
                    ;;
                * )
                    confirmPolicyExecution "${trigger}" "${validation}"
                    ;;
            esac

        done

    fi

    validatePolicyResult "${trigger}" "${validation}"

done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete processing and enable the "Done" button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

finalise
