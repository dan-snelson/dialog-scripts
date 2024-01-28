#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2317

####################################################################################################
#
# ABOUT
#
#   swiftDialog Notifications
#
#   See: https://snelson.us/?s=swiftdialog
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.4, 28-Jan-2024, Dan K. Snelson (@dan-snelson)
#       - Updated for swiftDialog v2.4.0
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Global Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Script Version & Client-side Log
scriptVersion="0.0.4"
scriptLog="/var/tmp/org.churchofjesuschrist.log"

# swiftDialog Binary & Log 
dialogBinary="/usr/local/bin/dialog"
dialogNotificationLog=$( mktemp -u /var/tmp/dialogNotificationLog.XXXX )

# Current logged-in user
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Title
title="${4:-"Title [Parameter 4]"}"

# Parameter 5: Message
message="${5:-"Message [Parameter 5]"}"

# Parameter 6: Button 1 Text
if [[ -n ${6} ]]; then button1TextOption="--button1text"; button1text="${6}"; fi

# Parameter 7: Button 1 Action
if [[ -n ${7} ]]; then button1ActionOption="--button1action"; button1action="${7}"; fi

# Parameter 8: Button 2 Text
if [[ -n ${8} ]]; then button2TextOption="--button2text"; button2text="${8}"; fi

# Parameter 9: Button 2 Action
if [[ -n ${9} ]]; then button2ActionOption="--button2action"; button2action="${9}"; fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readable Name
humanReadableScriptName="swiftDialog Notifications"

# Organization's Script Name
organizationScriptName="sdNotify"



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
    exit #1
}

function quitOut(){
    updateScriptLog "[QUIT]            ${1}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    notice "*** QUITTING ***"

    # Remove dialogNotificationLog
    if [[ -f "${dialogNotificationLog}" ]]; then
        logComment "Removing ${dialogNotificationLog} …"
        rm "${dialogNotificationLog}"

    fi

    logComment "Goodbye!"
    exit "${1}"

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

preFlight "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# https://snelson.us/\n###\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${loggedInUser}" || "${loggedInUser}" == "loginwindow" ]]; then
    fatal "No user logged-in; exiting"
fi


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${title}" || "${title}" == "Title [Parameter 4]" ]] ; then

    warning "Title [Parameter 4] is either empty or NOT set; displaying instructions …"

    title="Title [Parameter 4]: swiftDialog Wiki"

    message="Message [Parameter 5]: Have you checked Bart's Wiki?"

    button1TextOption="--button1text"
    button1text="Button 1 Text [Parameter 6]: No"

    button1ActionOption="--button1action"
    button1action="https://github.com/swiftDialog/swiftDialog/wiki"

    button2TextOption="--button2text"
    button2text="Button 2 Text [Parameter 8]: Yes"

    button2ActionOption="--button2action"
    button2action="https://snelson.us/?s=swiftdialog"

else

    updateScriptLog "Parameter 4, \"title,\" is populated; proceeding ..."

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
# Display Notification
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "*** DISPLAY NOTIFICATION ***"

logComment "Title (Parameter 4):           ${title}"
logComment "Message (Parameter 5):         ${message}"

if [[ -n "${button1text}" ]]; then logComment "Button 1 Text (Parameter 6):   ${button1text}" ; fi
if [[ -n "${button1action}" ]]; then logComment "Button 1 Action (Parameter 7): ${button1action}" ; fi
if [[ -n "${button2text}" ]]; then logComment "Button 2 Text (Parameter 8):   ${button2text}" ; fi
if [[ -n "${button2action}" ]]; then logComment "Button 2 Action (Parameter 9): ${button2action}" ; fi

${dialogBinary} \
    --notification \
    --title "${title}" \
    --message "${message}" \
    "${button1TextOption}" "${button1text}" \
    "${button1ActionOption}" "${button1action}" \
    "${button2TextOption}" "${button2text}" \
    "${button2ActionOption}" "${button2action}" \
    --commandfile "$dialogNotificationLog}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "0"