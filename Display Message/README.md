# Display Message via swiftDialog

Leverages [swiftDialog](https://github.com/bartreardon/swiftDialog/releases) v1.9.1+ and Jamf Pro Policy [Script Parameters](https://docs.jamf.com/10.36.0/jamf-pro/documentation/Scripts.html#ID-0002355b) to display a message to end-users.

Based on Bart Reardon (@bartreardon)'s [Example Jamf Scripts](https://github.com/bartreardon/swiftDialog/wiki/Example-Jamf-Scripts).

---

## End-user Example
![Display Message via Dialog](images/macOS_Monterey_12_Installer_Notification.png "Display Message via Dialog")

---

## Jamf Pro Script Options

![Jamf Pro Script Options](images/Display_Message_Dialog_Script.png "Jamf Pro Script Options")

### Parameter Labels
> Labels to use for script parameters. Parameters 1 through 3 are predefined as mount point, computer name, and username

- **Parameter 4:** `Title`
- **Parameter 5:** `Message`
- **Parameter 6:** `Icon (Absolute Path; i.e., /path/to/icon.icns )`
- **Parameter 7:** `Button 1 Text (i.e., Details)`
- **Parameter 8:** `Button 2 Text (i.e., Close)`
- **Parameter 9:** `Info Button Text (i.e., KB0053872)`
- **Parameter 10:** `Extra Flags (i.e., --iconsize 128 --timer 60 --blurscreen --quitoninfo --ignorednd --overlayicon /path/to/icon.icns )`
- **Parameter 11:** `Action (i.e., jamfselfservice://content?entity=policy&id=39&action=view )`

---

## Jamf Pro Policy Script Payload

![Jamf Pro Policy Script Payload](images/Display_Message_Dialog_Policy.png "Jamf Pro Policy Script Payload")

- **Title:** `macOS Monterey:** High powered meets “Hi everyone.”`
- **Message:** `**macOS** Monterey  \n\n**Connect, share, and create like never before.**  \n\nSay hello to exciting new FaceTime updates. Explore a redesigned Safari. Discover and invent powerful new ways to work using Universal Control and Shortcuts. Stay in the moment with Focus. And so much more.  \n\nClick **Details** to learn more before upgrading.  \n\nIf you need assistance, please contact the Global Services Department,  \n+1 (801) 555-1212, and mention KB0070400.`
- **Icon:** `/Applications/Install macOS Monterey.app/Contents/Resources/InstallAssistant.icns`
- **Button 1 Text:** `Details` 
- **Button 2 Text:** `Close`
- **Info Button Text:** `KB0070400`
- **Extra Flags:** `--timer 60 --blurscreen --quitoninfo --ignorednd --overlayicon /path/to/icon.icns`
- **Action:** `jamfselfservice:**//content?entity=policy&id=363&action=view`

---

## Tips-and-Tricks

### Jamf Pro's Self Service Icon

#### `appPath` (Thanks to @bartreardon)

```
appPath=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path)
dialog --title "Title goes here" --message "Message goes here" --icon "$appPath"
```

#### `brandingimage.png` (Thanks to @smithjw)
```
dialog --title "Title goes here" --message "Message goes here" --icon /Users/$(/usr/bin/stat -f%Su /dev/console)/Library/Application\ Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png
```