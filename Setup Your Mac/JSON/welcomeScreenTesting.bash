#!/bin/bash

# Source:
# https://github.com/bartreardon/swiftDialog-scripts/blob/main/JSON/get_json_value.sh

# This function can be used to parse JSON results from a dialog command
function get_json_value_welcomeScreen () {
    # usage: get_json_value_welcomeScreen "$JSON" "key 1" "key 2" "key 3"
    for var in "${@:2}"; do jsonkey="${jsonkey}['${var}']"; done
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env)$jsonkey"
}

# Logged-in User Variables
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | cut -d " " -f 1 )

# Welcome Screen Variables
welcomeTitle="Welcome to your new Mac, ${loggedInUserFirstname}!"
welcomeMessage="To begin, please enter your Mac's **Asset Tag**, then click **Continue** to start applying Church settings to your new Mac.  \n\nOnce completed, the **Quit** button will be re-enabled and you'll be prompted to restart your Mac.  \n\nIf you need assistance, please contact the Help Desk: +1 (801) 555-1212."
welcomeIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )


# Welcome Screen JSON
# shellcheck disable=SC2089
UserPromptJSON='{
    "bannerimage" : "/System/Library/Desktop Pictures/hello Orange.heic",
    "title" : "'"${welcomeTitle}"'",
        "titlefont" : "size=26,colour=#F69324,name=Verdana-Bold",
    "message" : "'"${welcomeMessage}"'",
        "messagefont" : "size=16,name=Georgia",
    "icon" : "'"${welcomeIcon}"'",
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
        {   "title" : "Select A",
            "values" : [
                "A1",
                "A2",
                "A3"
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
    "alignment" : "left",
    "button1text" : "Next",
    "moveable" : true,
    "infotext" : true,
    "height" : "775"
}'


# make a temp file for storing our JSON
tempfile=$(mktemp)
echo $UserPromptJSON > $tempfile

dialogcmd="/usr/local/bin/dialog"

# run dialog and store the JSON results in a variable
#${dialogcmd} --jsonfile $tempfile --json
#exit
results=$(${dialogcmd} --jsonfile $tempfile --json)
# clean up
rm $tempfile

# extract the various values from the results JSON
comment=$(get_json_value_welcomeScreen "$results" "Comment")
computerName=$(get_json_value_welcomeScreen "$results" "Computer Name")
userName=$(get_json_value_welcomeScreen "$results" "User Name")
assetTag=$(get_json_value_welcomeScreen "$results" "Asset Tag")
selectA=$(get_json_value_welcomeScreen "$results" "Select A" "selectedValue")
selectB=$(get_json_value_welcomeScreen "$results" "Select B" "selectedValue")
selectC=$(get_json_value_welcomeScreen "$results" "Select C" "selectedValue")

echo "Comment: $comment"
echo "Computer Name: $computerName"
echo "User Name: $userName"
echo "Asset Tag: $assetTag"
echo "Select A: $selectA"
echo "Select B: $selectB"
echo "Select C: $selectC"


# continue processing from here ...
