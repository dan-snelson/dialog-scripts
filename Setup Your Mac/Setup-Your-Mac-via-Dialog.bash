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
#   Version 1.5.1, 07-Dec-2022, Dan K. Snelson (@dan-snelson)
#   - Updates to "Pre-flight Checks"
#     - Moved section to start of script
#     - Added additional check for Setup Assistant
#       (for Mac Admins using an "Enrollment Complete" trigger)
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
# Determine Processor Type
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

cpu=$(sysctl -a | grep brand | awk '{print $2}')
echo "CPU vendor is $cpu"
if [[ $cpu = "Apple"  ]]; then
    type="arm"
else
    type="intel"
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

scriptVersion="1.5.1"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
scriptLog="${4:-"/var/tmp/org.ec.log"}"
debugMode="${5:-"true"}"                           # [ true (default) | false ]
welcomeDialog="${6:-"true"}"                       # [ true (default) | false ]
completionActionOption="${7:-"Restart Attended"}"  # [ wait | sleep (with seconds) | Shut Down | Shut Down Attended | Shut Down Confirm | Restart | Restart Attended (default) | Restart Confirm | Log Out | Log Out Attended | Log Out Confirm ]
reconOptions=""                                    # Initialize dynamic recon options; built based on user's input at Welcome dialog
exitCode="0"

org_name="$8"
if [[ $org_name = "Emerson Collective" ]]; then
    org_short_name="EC"
    echo "Org short name is $org_short_name for $org_name"
elif [[ $org_name = "XQ Institute" ]]; then
    org_short_name="XQ"
    echo "Org short name is $org_short_name for $org_name"
elif [[ $org_name = *"CRED"* ]]; then
    org_short_name="CC"
    echo "Org short name is $org_short_name for $org_name"
else
    org_short_name="EC"
    org_name="Emerson Collective"
    echo "Defaulting to $org_short_name for $org_name"
fi

logo_file="/Library/${org_short_name}/logo.png"
if [[ -e "$logo_file" ]]; then
    echo "logo file exists at ${logo_file}"
else
    echo "logo file not found, running appropriate JAMF policy to install"
    jamf policy -trigger install_${org_short_name}_logos
fi


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

welcomeTitle="Welcome to the Collective, ${loggedInUserFirstname}!"
welcomeMessage="To begin, please select 'OK' and the computer setup process will begin. If you need assistance, please email ithelp@emersoncollective.com. The process will begin in 5 minutes automatically"

# Welcome icon set to either light or dark, based on user's Apperance setting (thanks, @mm2270!)
appleInterfaceStyle=$( /usr/bin/defaults read /Users/"${loggedInUser}"/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>&1 )
if [[ "${appleInterfaceStyle}" == "Dark" ]]; then
    welcomeIcon="https://cdn-icons-png.flaticon.com/512/740/740878.png"
else
    welcomeIcon="https://cdn-icons-png.flaticon.com/512/979/979585.png"
fi



## # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
## "Welcome" JSON (thanks, @bartreardon!)
## # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#"title" : "Welcome To The Collective",
#"message" : "'"${welcomeMessage}"'",
#"icon" : '/Library/EC/logo.png',
#"iconsize" : "198.0",
#"button1text" : "Continue",
#"button2text" : "Get Help",
#"infotext" : "'"${scriptVersion}"'",
#"blurscreen" : "false",
#"ontop" : "true",
#"titlefont" : "size=26",
#"messagefont" : "size=16",
#welcomeJSON='{
#   "title" : "'"${welcomeTitle}"'",
#   "message" : "'"${welcomeMessage}"'",
#   "icon" : '/Library/EC/logo.png',
#   "iconsize" : "198.0",
#   "button1text" : "Continue",
#   "button2text" : "Get Help",
#   "infotext" : "'"${scriptVersion}"'",
#   "blurscreen" : "false",
#   "ontop" : "true",
#   "titlefont" : "size=26",
#   "messagefont" : "size=16",
#   "textfield" : [
#       {   "title" : "Comment",
#           "required" : false,
#           "prompt" : "Enter a comment",
#           "editor" : true
#       },
#       {   "title" : "Computer Name",
#           "required" : false,
#           "prompt" : "Computer Name"
#       },
#       {   "title" : "User Name",
#           "required" : false,
#           "prompt" : "User Name"
#       },
#       {   "title" : "Asset Tag",
#           "required" : true,
#           "prompt" : "Please enter the seven-digit Asset Tag",
#           "regex" : "^(AP|IP)?[0-9]{7,}$",
#           "regexerror" : "Please enter (at least) seven digits for the Asset Tag, optionally preceed by either AP or IP."
#       }
#   ],
# "selectitems" : [
#       {   "title" : "Department",
#           "default" : "Please select your department",
#           "values" : [
#               "Please select your department",
#               "Asset Management",
#               "Australia Area Office",
#               "Board of Directors",
#               "Business Development",
#               "Corporate Communications",
#               "Creative Services",
#               "Customer Service / Customer Experience",
#               "Engineering",
#               "Finance / Accounting",
#               "General Management",
#               "Human Resources",
#               "Information Technology / Technology",
#               "Investor Relations",
#               "Legal",
#               "Marketing",
#               "Operations",
#               "Product Management",
#               "Production",
#               "Project Management Office",
#               "Purchasing / Sourcing",
#               "Quality Assurance",
#               "Risk Management",
#               "Sales",
#               "Strategic Initiatives & Programs",
#               "Technology"
#           ]
#       },
#       {   "title" : "Select B",
#           "values" : [
#               "B1",
#               "B2",
#               "B3"
#           ]
#       },
#       {   "title" : "Select C",
#           "values" : [
#               "C1",
#               "C2",
#               "C3"
#           ]
#       }
#   ],
#   "height" : "635"
#}'



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
--height '70%' \
--position 'centre' \
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
# - path: The filepath for validation
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# The fully qualified domain name of the server which hosts your icons, including any required sub-directories
# (P.S. I tried to come up with a longer variable name, but couldn't.)
setupYourMacPolicyArrayIconPrefixUrl="https://ics.services.jamfcloud.com/icon/hash_"

# shellcheck disable=SC1112 # use literal slanted single quotes for typographic reasons

policy_array=('
{
    "steps": [
        {
            "listitem": "Install Rosetta",
            "icon": "0db9d24f6393b42c0299708b26ce756789fa2437ed24df4f25dcf67d95eb443c",
            "progresstext": "Install Rosetta 2.",
            "trigger_list": [
                {
                    "trigger": "install_rosetta",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Microsoft Office 365",
            "icon": "46ef03648ff5d1e4c12530e766bff4d8d3d3c6d2ab933045348c79795aee8bc6",
            "progresstext": "Utilize the full Microsoft 365 suite of applicaitons.",
            "trigger_list": [
                {
                    "trigger": "install_365",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Zoom",
            "icon": "be66420495a3f2f1981a49a0e0ad31783e9a789e835b4196af60554bf4c115ac",
            "progresstext": "Zoom is a videotelephony software program developed by Zoom Video Communications.",
            "trigger_list": [
                {
                    "trigger": "install_zoom",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Google Chrome",
            "icon": "12d3d198f40ab2ac237cff3b5cb05b09f7f26966d6dffba780e4d4e5325cc701",
            "progresstext": "Browse the Internet with ease",
            "trigger_list": [
                {
                    "trigger": "install_google_chrome",
                    "path": "/Applications/Google Chrome.app/Contents/Info.plist"
                }
            ]
        },

        {
            "listitem": "Re-name Computer",
            "icon": "90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296",
            "progresstext": "A listing of your Mac’s apps and settings — its inventory — is sent automatically to the Jamf Pro server daily.",
            "trigger_list": [
                {
                    "trigger": "rename_computer",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Conditional Access Tool",
            "icon": "7a97c3926c07d26c111a1f5c3d11fcaeb8471f6046e7b289d67bac74669f916a",
            "progresstext": "Ensure that Collective data is accessed by approved devices.",
            "trigger_list": [
                {
                    "trigger": "'okta_cba_${type}'",
                    "path": ""
                }
            ]
        },       
        {
            "listitem": "Install Code42",
            "icon": "c6eea7e3663ad37c248dc6881ed97498048f502da8a427caefaf6d31963f3681",
            "progresstext": "Install The Computer Backup System",
            "trigger_list": [
                {
                    "trigger": "'code42_${type}'",
                    "path": ""
                }
            ]
        },        
        {
            "listitem": "Install Slack",
            "icon": "a1ecbe1a4418113177cc061def4996d20a01a1e9b9adf9517899fcca31f3c026",
            "progresstext": "Install Slack Messaging System",
            "trigger_list": [
                {
                    "trigger": "install_slack",
                    "path": ""
                }
            ]
        },{
            "listitem": "Install Crowdstrike Falcon",
            "icon": "5dbbf8eebbecb20ac443f958bfb3aa9a44ed23ce4f49005a12b29a8f33522c8b",
            "progresstext": "Install The Computer Security Software",
            "trigger_list": [
                {
                    "trigger": "install_crowdstrike",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Enable Filevault 2",
            "icon": "90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296",
            "progresstext": "Install and Configure macOS FileVault 2.",
            "trigger_list": [
                {
                    "trigger": "enable_filevault",
                    "path": ""
                }
            ]
        },             
        {
            "listitem": "Install Google Drive",
            "icon": "a6954a50da661bd785407e23f83c6a1ac27006180eae1813086e64f4d6e65dcc",
            "progresstext": "The Preferred Cloud Storage Of The Collective.",
            "trigger_list": [
                {
                    "trigger": "install_google_drive",
                    "path": ""
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
--height 400 \
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

        dialogUpdateFailure "message: A failure has been detected, ${loggedInUserFirstname}.  \n\The following failed to install:  \n${jamfProPolicyPolicyNameFailures}  \n\n\n\nIf you need assistance, please ithelp@emersoncollective.com,"
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

        updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: TRIGGER: $jamfBinary policy -event $trigger"
        if [[ "$trigger" == "recon" ]]; then
            updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: RECON: $jamfBinary recon ${reconOptions}"
        fi
        sleep 1

    elif [[ "$trigger" == "recon" ]]; then

        dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Updating …, "
        updateScriptLog "SETUP YOUR MAC DIALOG: Updating computer inventory with the following reconOptions: \"${reconOptions}\" …"
        eval "${jamfBinary} recon ${reconOptions}"

    else

        updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary policy -event $trigger"
        "$jamfBinary" policy -event "$trigger"

    fi

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
            path=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].path")

            # If the path variable has a value, check if that path exists on disk
            if [[ -f "$path" ]]; then
                updateScriptLog "SETUP YOUR MAC DIALOG: INFO: $path exists, moving on"
                if [[ "${debugMode}" == "true" ]]; then sleep 0.5; fi
            else
                run_jamf_trigger "$trigger"
            fi
        done
    fi

    # Validate the expected path exists
    updateScriptLog "SETUP YOUR MAC DIALOG: Testing for \"$path\" …"
    if [[ -f "$path" ]] || [[ -z "$path" ]]; then
        dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Installed"
        if [[ "$trigger" == "recon" ]]; then
            dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Updated"
        fi
    else
        dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
        jamfProPolicyTriggerFailure="failed"
        exitCode="1"
        jamfProPolicyPolicyNameFailures+="• $listitem  \n"
    fi

done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete processing and enable the "Done" button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

finalise
