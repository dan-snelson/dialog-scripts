#!/bin/bash

####################################################################################################
#
# Display Message via swiftDialog
#
# Purpose: Displays an end-user message via swiftDialog
# See: https://snelson.us/2023/03/display-message-0-0-7-via-swiftdialog/
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 18-Feb-2022, Dan K. Snelson (@dan-snelson)
#   Original version
#
# Version 0.0.2, 06-Apr-2022, Dan K. Snelson (@dan-snelson)
#   Default icon to Jamf Pro Self Service if not specified
#
# Version 0.0.3, 19-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Validate Operating System
#   Check for / install dialog (thanks, @acodega)
#   Added Client-side Script Logging
#   Changed Jamf Pro Script Parameters
#   - Friendly error message when Title or Message are not populated
#   - Changed Action (Parameter 11) to be optional (thanks for the idea, @eosrebel!)
#
# Version 0.0.4, 03-Nov-2022, Dan K. Snelson (@dan-snelson)
#   Reverted `action` code to version 0.0.2
#
# Version 0.0.5, 05-Dec-2022, Dan K. Snelson (@dan-snelson)
#   Added `returncode` of `20` for "Do Not Disturb"
#
# Version 0.0.6, 28-Dec-2022, Dan K. Snelson (@dan-snelson)
#   - Hard-code `overlayicon` to use Self Service's icon (to help overcome the inability to include
#     spaces in Jamf Pro Script Parameters)
#
# Version 0.0.7, 21-Mar-2023, Dan K. Snelson (@dan-snelson)
#   - Overlayicon can now be included via: `--overlayicon /var/tmp/overlayicon.icns`
#   - Updates from Setup Your Mac code
#   - Revised default dialog instructions
#
# Version 0.0.8, 30-Mar-2023, Dan K. Snelson (@dan-snelson)
#   - Updated default dialog instructions to include an `action`
#
# Version 0.0.9, 09-Sep-2023, Dan K. Snelson (@dan-snelson)
#   - Updated `dialogURL`
#
# Version 0.0.10, 01-Nov-2023, Dan K. Snelson (@dan-snelson)
#   - Updated `osascript` error message
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.10"
scriptLog="/var/tmp/org.churchofjesuschrist.log"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
osVersion=$( sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
dialogBinary="/usr/local/bin/dialog"
dialogMessageLog=$( mktemp /var/tmp/dialogWelcomeLog.XXX )
if [[ -n ${4} ]]; then titleoption="--title"; title="${4}"; fi
if [[ -n ${5} ]]; then messageoption="--message"; message="${5}"; fi
if [[ -n ${6} ]]; then iconoption="--icon"; icon="${6}"; fi
if [[ -n ${7} ]]; then button1option="--button1text"; button1text="${7}"; fi
if [[ -n ${8} ]]; then button2option="--button2text"; button2text="${8}"; fi
if [[ -n ${9} ]]; then infobuttonoption="--infobuttontext"; infobuttontext="${9}"; fi
extraflags="${10}"
action="${11}"

# Create `overlayicon` from Self Service's custom icon (thanks, @meschwartz!)
xxd -p -s 260 "$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path)"/Icon$'\r'/..namedfork/rsrc | xxd -r -p > /var/tmp/overlayicon.icns
overlayicon="/var/tmp/overlayicon.icns"

# Default icon to Jamf Pro Self Service if not specified
if [[ -z ${icon} ]]; then
    iconoption="--icon"
    icon="/var/tmp/overlayicon.icns"
fi



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
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\n###\n# Display Message via swiftDialog (${scriptVersion})\n###\n"
updateScriptLog "PRE-FLIGHT CHECK: Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    updateScriptLog "PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; proceeding ..."
else
    updateScriptLog "PRE-FLIGHT CHECK: macOS ${osVersion} installed; exiting."
    osascript -e 'display dialog "Display Message via swiftDialog ('"${scriptVersion}"')\rby Dan K. Snelson (https://snelson.us)\r\rmacOS '"${osVersion}"' installed; macOS Big Sur 11\r(or later) required" buttons {"OK"} with icon caution with title "Display Message via swiftDialog: Error"'
    exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        updateScriptLog "PRE-FLIGHT CHECK: Dialog not found. Installing..."

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
            updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} installed; proceeding..."

        else

            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Display Message via Dialog: Error" buttons {"Close"} with icon caution'
            quitScript "1"

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version $(${dialogBinary} --version) found; proceeding..."

    fi

}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    dialogCheck
else
    updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version $(${dialogBinary} --version) found; proceeding..."
fi



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Quitting …"
    echo "quit:" >> "${dialogMessageLog}"

    sleep 1
    updateScriptLog "Exiting …"

    # Remove dialogMessageLog
    if [[ -f ${dialogMessageLog} ]]; then
        updateScriptLog "Removing ${dialogMessageLog} …"
        rm "${dialogMessageLog}"
    fi

    # Remove overlayicon
    if [[ -f ${overlayicon} ]]; then
        updateScriptLog "Removing ${overlayicon} …"
        rm "${overlayicon}"
    fi

    updateScriptLog "Goodbye!"
    exit "${1}"

}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${title}" ]] || [[ -z "${message}" ]]; then

    updateScriptLog "Either Parameter 4 or Parameter 5 are NOT populated; displaying instructions …"

    extraflags="--width 825 --height 400 --moveable --timer 75 --position topright --blurscreen --titlefont size=26 --messagefont size=13 --iconsize 125 --overlayicon /var/tmp/overlayicon.icns --quitoninfo"

    titleoption="--title"
    title="Title [Parameter 4] goes here"

    messageoption="--message"
    message="### Message [Parameter 5] goes here  \n\n- [Dialog](https://github.com/bartreardon/swiftDialog) v\`$(${dialogBinary} --version)\`  \n- [Display Message via swiftDialog](https://snelson.us/2023/03/display-message-0-0-7-via-swiftdialog/) v\`${scriptVersion}\`  \n- Displaying with the following \`extraflags\`:  \n\n\`${extraflags}\`  \n\nThank you, [Bart Reardon](https://www.buymeacoffee.com/bartreardon), for making \`swiftDialog\`!  \n\n---\n\n**Note:** Please review this [blog post](https://snelson.us/2023/03/display-message-0-0-7-via-swiftdialog/) for additional information."

    button1option="--button1text"
    button1text="Button 1 [Parameter 7]"

    button2option="--button2text"
    button2text="Button 2 [Parameter 8]"

    infobuttonoption="--infobuttontext"
    infobuttontext="Infobutton [Paramter 9]"

    action="https://snelson.us/2023/03/display-message-0-0-7-via-swiftdialog/"

else

    updateScriptLog "Both \"title\" and \"message\" Parameters are populated; proceeding ..."

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Message: Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Title: ${title}"
updateScriptLog "Message: ${message}"
updateScriptLog "Extra Flags: ${extraflags}"

# shellcheck disable=SC2086
${dialogBinary} \
    ${titleoption} "${title}" \
    ${messageoption} "${message}" \
    ${iconoption} "${icon}" \
    ${button1option} "${button1text}" \
    ${button2option} "${button2text}" \
    ${infobuttonoption} "${infobuttontext}" \
    --infobuttonaction "https://servicenow.company.com/support?id=kb_article_view&sysparm_article=${infobuttontext}" \
    --messagefont "size=14" \
    --commandfile "$dialogMessageLog}" \
    ${extraflags}

returncode=$?
updateScriptLog "Return Code: ${returncode}"

case ${returncode} in

    0)  ## Process exit code 0 scenario here
        echo "${loggedInUser} clicked ${button1text}"
        updateScriptLog "${loggedInUser} clicked ${button1text};"
        if [[ -n "${action}" ]]; then
            su - "${loggedInUser}" -c "open \"${action}\""
        fi
        quitScript "0"
        ;;

    2)  ## Process exit code 2 scenario here
        echo "${loggedInUser} clicked ${button2text}"
        updateScriptLog "${loggedInUser} clicked ${button2text};"
        quitScript "0"
        ;;

    3)  ## Process exit code 3 scenario here
        echo "${loggedInUser} clicked ${infobuttontext}"
        updateScriptLog "${loggedInUser} clicked ${infobuttontext};"
        ;;

    4)  ## Process exit code 4 scenario here
        echo "${loggedInUser} allowed timer to expire"
        updateScriptLog "${loggedInUser} allowed timer to expire;"
        ;;

    20) ## Process exit code 20 scenario here
        echo "${loggedInUser} had Do Not Disturb enabled"
        updateScriptLog "${loggedInUser} had Do Not Disturb enabled"
        quitScript "0"
        ;;

    *)  ## Catch all processing
        echo "Something else happened; Exit code: ${returncode}"
        updateScriptLog "Something else happened; Exit code: ${returncode};"
        quitScript "${returncode}"
        ;;

esac

updateScriptLog "End-of-line."

quitScript "0"