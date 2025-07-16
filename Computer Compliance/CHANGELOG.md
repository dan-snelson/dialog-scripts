# Computer Compliance
## CHANGELOG

### 1.9.0 (10-Jun-2025)
- Updates for macOS 26

### 1.8.0 (17-May-2025)
- Added "warning" when logged-in user is a member of `admin`

### 1.7.0 (07-May-2025)
- Updated `checkOS` function to display macOS version and build to user
- Removed OS version from `infobox`

### 1.6.0 (30-Apr-2025)
- Added countdown progress bar to `quitScript` function (thanks, @samg and @bartreadon!)

### 1.5.0 (29-Apr-2025)
- Added `jamf recon` as final "check"
- Improved logging output

### 1.4.0 (28-Apr-2025)
- Added `timer` option to swiftDialog
- Added forcible-quit for all other running dialogs

### 1.3.0 (23-Apr-2025)
 - Added sudoers check

### 1.2.0 (19-Apr-2025)
- Added `operationMode` [ test | production ]

### 1.1.0 (17-Apr-2025)
- Added output of `/usr/libexec/mdmclient AvailableOSUpdates` to `$scriptLog`

### 1.0.0 (15-Apr-2025)
- First "official" release

---

### 0.0.17 (14-Apr-2025)
- Better control the caching of the networkQuality test (See: `networkQualityTestMaximumAge`)

### 0.0.16 (11-Apr-2025)
- Cache `networkQuality` test results

### 0.0.15 (11-Apr-2025)
- Supressed various error messages (i.e., `2>/dev/null` is your friend)

### 0.0.14 (11-Apr-2025)
- Supressed extraneous output from `checkAvailableSoftwareUpdates`

### 0.0.13 (11-Apr-2025)
- Dialog is now "ontop" and can be minimized
- Added `checkAvailableSoftwareUpdates`
- Added `locationServicesStatus` to quitScript output
- Moved `batteryCycleCount` to quitScript output
- Moved `jamfProID` to quitScript output
- Moved `networkTimeServer` to quitScript output
- Removed `kerberosSSOeResult` from `helpmessage`
- Removed `localHostName` from `helpmessage`
- Removed `computerModel` from `helpmessage`
- Removed `tmStatus` from `helpmessage`

### 0.0.12 (10-Apr-2025)
- Added `excessiveUptimeAlertStyle` varible (so excessive uptime will result in a "warning" or "error")
- Added `organizationColorScheme` to more easily brand the various SF Symbols

### 0.0.11 (10-Apr-2025)
- Added computer information to pre-flight section of logs

### 0.0.10 (10-Apr-2025)
- Modified Uptime Check to use `warning` for excessive uptime
- Removed stray occurrences of `results`

### 0.0.9 (10-Apr-2025)
- Added check for System Integrity Protection
- Added check for built-in firewall
- Added check for APNs
    - Renamed the previous, so-called "MDM" checks to "Jamf Pro"
- Replaced `errorOut "${1}"` in indvidual checks with more verbose, specific log output

### 0.0.8 (08-Apr-2025)
- Added JSS Built-in Certificate Authority expiration check (thanks, @isaacatmann!) [JNUC 2024](https://github.com/mannconsulting/JNUC2024/)

### 0.0.7 (08-Apr-2025)
- Added multiple drive support to Time Machine check (thanks, obi-@bartreadon!) [Issue #65](#65)

### 0.0.6 (07-Apr-2025)
- Added check for the Jamf Pro MDM Profile
- Improved `checkSetupYourMacValidation` logic

### 0.0.5 (07-Apr-2025)
- Added check for Microsoft OneDrive's last sync time

### 0.0.4 (07-Apr-2025)
- Added `infobuttontext` and `infobuttonaction` for the Knowledge Base article (in main dialog)

### 0.0.3 (07-Apr-2025)
- Added `exitCode` variable (to better report failures as errors in the Jamf Pro policy)
- Adjusted `tmLastBackup` message (for when no Time Machine destination is configured)

### 0.0.2 (04-Apr-2025)
- Replaced manually created variables with swiftDialog built-ins (thanks for the reminder, @bartreadon!)
- Applied Band-Aid for macOS 15 `withAnimation` SwiftUI bug
- Included the output of several "helpmessage" variables to ${scriptLog}
- Skipped Compliant OS Version check for Beta OSes

### 0.0.1 (03-Apr-2025)
- Original, proof-of-concept version inspired by @robjschroeder