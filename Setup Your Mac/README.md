# Setup Your Mac via swiftDialog

> Leverages [swiftDialog](https://github.com/bartreardon/swiftDialog/releases) v1.11.0.2758 (or later) and Jamf Pro Policy [Custom Events](https://docs.jamf.com/10.36.0/jamf-pro/documentation/Policy_Management.html?hl=custom%2Cevent#ID-0001f43f) to allow end-users to self-complete Mac setup **post-enrollment** via Jamf Pro's Self Service. (See Jamf Pro Known Issues `PI100009 - PI-004775`.)

Inspired by:
- Rich Trouton ([@rtrouton](https://github.com/rtrouton))
- Bart Reardon ([@bartreardon](https://github.com/bartreardon))
- James Smith ([@smithjw](https://github.com/smithjw))

Based on:
- Adam Codega ([@adamcodega](https://github.com/acodega))'s [MDMAppsDeploy.sh](https://github.com/acodega/dialog-scripts/blob/main/MDMAppsDeploy.sh)
- James Smith ([@smithjw](https://github.com/smithjw))'s [swiftEnrolment](https://github.com/smithjw/swiftEnrolment)

---

## Screencasts

### Setup Your Mac

[<img alt="Setup Your Mac via swiftDialog" width="650px" src="images/screencast_still_image.png" />](https://rumble.com/v16vwbj-setup-your-mac-via-swiftdialog-1.2.0.html)

### Harvesting Self Service Icons

[<img alt="Setup Your Mac via swiftDialog" width="650px" src="images/Harvesting_Self_Service_Icons.png" />](https://rumble.com/v119x6y-harvesting-self-service-icons.html)

---

## Features

### Asset Tag Capture

Version `1.1.0` prompts the user to provide an Asset Tag, which is captured and reported in the **Setting up your Mac** screen and submitted near the end of the scipt when inventory is updated via `jamf recon -assetTag ${assetTag}`.

#### Asset Tag Capture Optional

Version `1.2.1` _requires_ a Jamf Pro Administrator to **specifically enable** Asset Tag Capture by setting Script Parameter `5` to `true` (i.e., default is to **not** prompt the user for an Asset Tag).

![Asset Tag Capture](images/Asset_Tag_Capture.png "Asset Tag Capture")
 ### Debug Mode

Version `1.1.0` introduces **Debug Mode**, which may prove helpful during initial deployment or for ongoing troubleshooting.

When Debug Mode is set to `true` — and only `true` — you will observe the following behavior changes:
- The `--title` in the **Setting up your Mac** screen will be preceeded by **DEBUG MODE |**
- Jamf Pro policies will **not** execute, but will output to the Jamf Pro Policy Log what _would_ have executed had Debug Mode not been set to `true`
- Computer inventory will **not** be updated, but will output to the Jamf Pro Policy Log what _would_ have been submitted (i.e., user-entered Asset Tag)

**Note:** When Debug Mode is set to `true`, you should expect to observe multiple failures in the **Setting up your Mac** screen as the policies which install the so-called `filepath for validation` don't actually execute.

![Debug Mode](images/Debug_Mode.png "Debug Mode")

---

## Configuration

You should be comfortable _modifying_ scripts before using this approach (i.e., customizing existing settings to your needs).

If the core functionality of this script meets your needs, **writing** code should not be required.

### Script Modifications

#### `policy_array` Variable

For each configuration step, specify:
- `listitem` The text to be displayed in the list
- `icon` The [hash](https://rumble.com/v119x6y-harvesting-self-service-icons.html) of the icon to be displayed on the left
- `progresstext` The text to be displayed below the progress bar 
- `trigger` The Jamf Pro Policy Custom Event Name
- `path` The filepath for validation

##### Example

```
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
                    "path": "/Library/Preferences/com.apple.fdesetup.plist"
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
                    "path": "/Applications/Sophos/Sophos Endpoint.app/Contents/Info.plist"
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
                    "path": "/Applications/GlobalProtect.app/Contents/Info.plist"
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
                    "path": "/Applications/Microsoft Teams.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Zoom",
            "icon": "92b8d3c448e7d773457532f0478a428a0662f694fbbfc6cb69e1fab5ff106d97",
            "progresstext": "Zoom is a videotelephony software program developed by Zoom Video Communications.",
            "trigger_list": [
                {
                    "trigger": "zoom",
                    "path": "/Applications/zoom.us.app/Contents/Info.plist"
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
                    "path": "/Applications/Google Chrome.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Final Configuration",
            "icon": "00d7c19b984222630f20b6821425c3548e4b5094ecd846b03bde0994aaf08826",
            "progresstext": "Finalizing Church Configuration …",
            "trigger_list": [
                {
                    "trigger": "finalConfiguration",
                    "path": ""
                },
                {
                    "trigger": "reconAtReboot",
                    "path": ""
                },
                {
                    "trigger": "computerNameSet",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Update Inventory",
            "icon": "90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296",
            "progresstext": "The listing of your computer’s installed apps and settings — its inventory — is automatically sent to the Jamf Pro server daily.",
            "trigger_list": [
                {
                    "trigger": "recon",
                    "path": ""
                }
            ]
        }
    ]
}
')
```

### Jamf Pro Script Options

![Jamf Pro Script Options](images/Parameter_Labels.png "Jamf Pro Script Options")

> Labels to use for script parameters. Parameters 1 through 3 are predefined as mount point, computer name, and username

- **Parameter 4:** `Debug Mode ( true | false, blank)`
- **Parameter 5:** `Asset Tag Capture ( true | false, blank)`

### Jamf Pro Policy Script Payload

![Jamf Pro Policy Script Payload](images/Policy_Script_Payload.png "Jamf Pro Policy Script Payload")

- **Debug Mode:** `true` to enable Debug Mode; defaults to disabled
- **Asset Tag Capture:** `true` to prompt user to provide an Asset Tag; defaults to **not** prompting the user to provide an Asset Tag