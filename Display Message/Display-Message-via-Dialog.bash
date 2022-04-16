#!/bin/bash

####################################################################################################
#
#	Display Message via Dialog
#
#	Purpose: Displays an end-user message via Dialog
#	See: https://github.com/bartreardon/Dialog/wiki/Example-Jamf-Scripts
#
####################################################################################################
#
# HISTORY
#
# 	Version 0.0.1, 18-Feb-2022, Dan K. Snelson (@dan-snelson)
#		Original version
#
#	Version 0.0.2, 06-Apr-2022, Dan K. Snelson (@dan-snelson)
#		Default icon to Jamf Pro Self Service if not specified
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.2"
scriptResult="Version ${scriptVersion};"
loggedInUser=$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }' )
dialogPath="/usr/local/bin/dialog"
if [[ -n ${4} ]]; then titleoption="--title"; title="${4}"; fi
if [[ -n ${5} ]]; then messageoption="--message"; message="${5}"; fi
if [[ -n ${6} ]]; then iconoption="--icon"; icon="${6}"; fi
if [[ -n ${7} ]]; then button1option="--button1text"; button1text="${7}"; fi
if [[ -n ${8} ]]; then button2option="--button2text"; button2text="${8}"; fi
if [[ -n ${9} ]]; then infobuttonoption="--infobuttontext"; infobuttontext="${9}"; fi
extraflags=${10}
action=${11}

# Default icon to Jamf Pro Self Service if not specified
if [[ -z ${icon} ]]; then
	iconoption="--icon"
	icon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
fi


####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logging preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptResult="${scriptResult} Display Message via Dialog (${scriptVersion})"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate a value has been specified for all parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -n "${title}" ]] && [[ -n "${message}" ]]; then
	scriptResult="${scriptResult} Parameters 4 and 5 populated; proceeding ..."
else
	scriptResult="${scriptResult} Error: Parameters 4 or 5 not populated; exiting."
	echo "${scriptResult}"
	exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Message: Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptResult="${scriptResult} Message Title: ${title};"

${dialogPath} \
	${titleoption} "${title}" \
	${messageoption} "${message}" \
	${iconoption} "${icon}" \
	${button1option} "${button1text}" \
	${button2option} "${button2text}" \
	${infobuttonoption} "${infobuttontext}" \
	--infobuttonaction "https://servicenow.company.com/support?id=kb_article_view&sysparm_article=${infobuttontext}" \
	--messagefont "size=14" \
	${extraflags}

returncode=$?



case ${returncode} in

	0)  ## Process exit code 0 scenario here
		echo "${loggedInUser} clicked ${button1text}"
		scriptResult="${scriptResult} ${loggedInUser} clicked ${button1text};"
		/usr/bin/su - "${loggedInUser}" -c "/usr/bin/open \"${action}\""
		echo "${scriptResult}"
		exit 0
		;;

	2)  ## Process exit code 2 scenario here
		echo "${loggedInUser} clicked ${button2text}"
		scriptResult="${scriptResult} ${loggedInUser} clicked ${button2text};"
		echo "${scriptResult}"
		exit 0
		;;

	3)  ## Process exit code 3 scenario here
		echo "${loggedInUser} clicked ${infobuttontext}"
		scriptResult="${scriptResult} ${loggedInUser} clicked ${infobuttontext};"
		;;

	4)  ## Process exit code 4 scenario here
		echo "${loggedInUser} allowed timer to expire"
		scriptResult="${scriptResult} ${loggedInUser} allowed timer to expire;"
		;;

	*)  ## Catch all processing
		echo "Something else happened; Exit code: ${returncode}"
		scriptResult="${scriptResult} Something else happened; Exit code: ${returncode};"
		echo "${scriptResult}"
		exit 1
		;;
esac

scriptResult="${scriptResult} End-of-line."

echo "${scriptResult}"

exit 0