# CHANGELOG

## 1.6.0
### 09-Jan-2023
[Release-specific Blog Post](https://snelson.us/2023/01/setup-your-mac-via-swiftdialog-1-6-0/)
- Addresses [Issue No. 21](https://github.com/dan-snelson/dialog-scripts/issues/21)
  - 🔥 **Breaking Change** 🔥 (for users of Setup Your Mac prior to `1.6.0`)
      - `policy_array`'s "`path`" has been replaced with "`validation`"
  - 🆕 The `confirmPolicyExecution` function confirms if the policy needs to be executed for `filepath` validations
    - A validation of `None` always executes the Jamf Pro trigger when `debug mode` is set to `false`
  - 🆕 The `validatePolicyResult` function validates if the policy succeeded and the related service is _running_, based on the specified `validation` option
    - [Feature-specific Blog Post](https://snelson.us/2023/01/setup-your-mac-validation/)
    - **Validation Options:**
       - {absolute path} (simulates pre-`1.6.0` behavior, for example: `"/Applications/Microsoft Teams.app/Contents/Info.plist"`)
       - `Local` (for validation within this script, for example: `"filevault"`)
       - `Remote` (for validation validation via a single-script Jamf Pro policy, for example: `"symvGlobalProtect"`)
       - `None` (for triggers which don't require validation, for example: `recon`; always evaluates as successful)
- Enhanced policy logging options to address [Issue No. 25](https://github.com/dan-snelson/dialog-scripts/issues/25)
  - Search for and comment-out: `eval "${jamfBinary} policy -trigger ${trigger}"`
  - Uncomment: `eval "${jamfBinary} policy -trigger ${trigger} -verbose | tee -a ${scriptLog}"`
  - Ensure `debug mode` is set to `false`
- Added Rosetta 2 policy execution and validation
- Enhanced Logging
  - Addresses [Issue No. 29](https://github.com/dan-snelson/dialog-scripts/issues/29)


##  1.5.1
### 07-Dec-2022
[Release-specific Blog Post](https://snelson.us/2022/12/setup-your-mac-via-swiftdialog-1-5-1/)
- Updates to "Pre-flight Checks"
  - Moved section to start of script
  - :new: Added additional check for Setup Assistant (for Mac Admins using an "Enrollment Complete" trigger)

##  1.5.0
### 28-Nov-2022
[Release-specific Blog Post](https://snelson.us/2022/11/setup-your-mac-via-swiftdialog-1-5-0/)
- :new: Prompt user for additional fields at Welcome dialog
  - New fields are included in a single `welcomeJSON` variable (thanks for all your efforts and feedback, @drtaru and @Andrew!)
    - See [welcomeScreenTesting.bash](JSON/welcomeScreenTesting.bash) (thanks, @bartreardon!)
    - In **Debug Mode**, changes are logged only (thanks, @Andrew!)
  - Dynamic `reconOptions` based on user's input at the **Welcome** dialog
  - Thanks for your patience, @remusache, @midiman1000, @erikmadams, @colorenz and @benphilware
- :fire: **Breaking Changes** :fire: (for users of **Setup Your Mac** prior to `1.5.0`)
  - Script Parameter Reordering (sorry; I'll strive not to ever do this again)
    - **Parameter 4:** Script Log Location [ `/var/tmp/org.churchofjesuschrist.log` ]
    - **Parameter 5:** Debug Mode [ `true` (default) | `false` ]
    - **Parameter 6:** Welcome dialog [ `true` (default) | `false` ]
    - **Parameter 7:** Completion Action [ `wait` | `sleep` (with seconds) | `Shut Down` | `Shut Down Attended` | `Shut Down Confirm` | `Restart` |  **`Restart Attended`(default)** | `Restart Confirm` | `Log Out` | `Log Out Attended` | `Log Out Confirm` ]
- Miscellaneous Improvements
  - Moved code blocks and variables to better reflect the **Welcome** > **Setup Your Mac** > **Failure** workflow
  - Random code clean-up


## 1.4.0
### 21-Nov-2022
[Release-specific Blog Post](https://snelson.us/2022/11/setup-your-mac-via-swiftdialog-1-3-1)
- Significantly enhanced **Completion Action** options
  - :white_check_mark: Addresses [Issue 15](https://github.com/dan-snelson/dialog-scripts/issues/15) (thanks, @mvught, @riddl0rd, @iDrewbs and @master-vodawagner)
  - :tada: Dynamically set `button1text` based on the value of `completionActionOption` (thanks, @jared-a-young)
  - :partying_face: Dynamically set `progresstext` based on the value of `completionActionOption` (thanks, @iDrewbs)
  - :new: Three new flavors: **Shut Down**, **Restart** or **Log Out**
    - :rotating_light: **Forced:** Zero user-interaction
      - Added brute-force `killProcess "Self Service"`
      - Added `hack` to allow Policy Logs to be shipped to Jamf Pro server
    - :warning: **Attended:** Forced, but only _after_ user-interaction (thanks, @owainiorwerth)
      - Added `hack` to allow Policy Logs to be shipped to Jamf Pro server
    - :bust_in_silhouette: **Confirm:** Displays built-in macOS _user-dismissible_ dialog box
  - Sleep
  - Wait (default)
- Improved **Debug Mode** behavior
  - :bug: `DEBUG MODE |` now only displayed as `infotext` (i.e., bottom, left-hand corner)
  - `completionAction` informational-only with simple dialog box (thanks, @_____???)
  - Swapped `blurscreen` for `moveable`
  - General peformance increases
- Miscellaneous Improvements
  - Removed `jamfDisplayMessage` function and reverted `dialogCheck` function to use `osascript` (with an enhanced error message)
  - Replaced "Installing …" with "Updating …" for `recon`-flavored `trigger`
  - Changed "Updating Inventory" to "Computer Inventory" for `recon`-flavored `listitem`
  - Changed exit code to `1` when user quits "Welcome" screen
  - Changed `welcomeIcon` URLs
  - Changed URL for Harvesting Self Service icons screencast (thanks, @nstrauss)



## 1.3.0
### 09-Nov-2022
[Release-specific Blog Post](https://snelson.us/2022/11/setup-your-mac-via-swiftdialog-1-3-0/)
- **Script Parameter Changes:**
  - :warning: **Parameter 4:** `debug` mode **enabled** by default
  - :new: **Parameter 7:** Script Log Location
- :new: Embraced _**drastic**_ speed improvements in :bullettrain_front:`swiftDialog v2`:dash:
- Caffeinated script (thanks, @grahampugh!)
- Enhanced `wait` exiting logic
- General script standardization

## 1.2.10
### 05-Oct-2022 
- Modifications for swiftDialog v2 (thanks, @bartreardon!)
  - Added I/O pause to `dialog_update_setup_your_mac`
  - Added `list: show` when displaying policy_array
  - Re-ordered Setup Your Mac progress bar commands
- More specific logging for various dialog update functions
- Confirm Setup Assistant complete and user at Desktop (thanks, @ehemmete!)

## 1.2.9
### 03-Oct-2022
- Added `setupYourMacPolicyArrayIconPrefixUrl` variable (thanks for the idea, @mani2care!)
- Removed unnecessary `listitem` icon updates (thanks, @bartreardon!)
- Output swiftDialog version when running in debug mode
- Updated URL for Zoom icon
## 1.2.8
### 19-Sep-2022

- Replaced "ugly" `completionAction` `if … then … else` with "more readabale" `case` statement (thanks, @pyther!)
- Updated "method for determining laptop/desktop" (thanks, @acodega and @scriptingosx!)
- Additional tweaks discovered during internal production deployment
## 1.2.7
### 10-Sep-2022
[Release-specific Blog Post](https://snelson.us/2022/09/setup-your-mac-via-swiftdialog-1-2-7/)
- Added "completionAction" (Script Parameter 6) to address [Pull Request No. 5](https://github.com/dan-snelson/dialog-scripts/pull/5)
- Added "Failure" dialog to address [Issue No. 6](https://github.com/dan-snelson/dialog-scripts/issues/6)
## 1.2.6
### 29-Aug-2022
- Adjust I/O timing (for policy_array loop)
## 1.2.5
### 24-Aug-2022
- Resolves https://github.com/dan-snelson/dialog-scripts/issues/3 (thanks, @pyther!)

## 1.2.4

### 18-Aug-2022
[Release-specific Blog Post](https://snelson.us/2022/06/setup-your-mac-via-swiftdialog-1-2-1/)
- Swap "Installing …" and "Pending …" status indicators (thanks, @joncrain)
## 1.2.3
### 15-Aug-2022
- Updates for switftDialog v1.11.2
- Report failures in Jamf Pro Policy Triggers

## 1.2.2
### 07-Jun-2022
- Added "dark mode" for logo (thanks, @mm2270)
- Added "compact" for `--liststyle`

## 1.2.1
### 01-Jun-2022
- Made Asset Tag Capture optional (via Jamf Pro Script Paramter 5)

## 1.2.0
### 30-May-2022
- Changed `--infobuttontext` to `--infotext`
- Added `regex` and `regexerror` for Asset Tag Capture
- Replaced @adamcodega's `apps` with @smithjw's `policy_array`
- Added progress update
- Added filepath validation

## 1.1.0
### 19-May-2022
- Added initial "Welcome Screen" with Asset Tag Capture and Debug Mode

## 1.0.0
### 30-Apr-2022
-  First "official" release