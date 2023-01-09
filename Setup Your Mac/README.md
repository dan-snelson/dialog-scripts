# Setup Your Mac via swiftDialog

> With the implementation of a recent feature request, Setup Your Mac (1.6.0) introduces additional policy validation options to help ensure critical enterprise applications are both installed and their related services are running.

![Setup Your Mac (1.6.0)](images/Setup%20Your%20Mac%201.6.0%20SYM%20dialog%20success.png "Setup Your Mac (1.6.0)")

![Setup Your Mac (1.5.0)](images/Setup_Your_Mac_1.5.0.png "Setup Your Mac (1.5.0)")

## Introduction

Apple's Automated Device Enrollment helps to streamline Mobile Device Management (MDM) enrollment and device Supervision during activation, enabling IT to manage enterprise devices with "zero touch."

**Setup Your Mac** aims to simplify initial device configuration by leveraging `swiftDialog` and Jamf Pro Policy Custom Events to allow end-users to self-complete Mac setup **post-enrollment** via Jamf Pro’s Self Service.


[Continue reading …](https://snelson.us/setup-your-mac)

## Script
- [Setup-Your-Mac-via-Dialog.bash](Setup-Your-Mac-via-Dialog.bash)


---

# &ldquo;Setup Your Mac, please&rdquo;

> When auto-launching Self Service post-enrollment isn't enough, **continually** prompt your users to _actually_ setup their Macs

While we _thought_ we'd done everything to help ensure our users had a seamless experience in setting up their new Macs, we recently realized we should **prompt** those users with computers which have successfully enrolled, but still have yet to run our **Setup Your Mac** policy.

[<img alt="Setup Your Mac, please" src="images/Setup_Your_Mac_please.png" />](https://snelson.us/2022/07/setup-your-mac-please/)

[Continue reading …](https://snelson.us/2022/07/setup-your-mac-please/)

## Script
- [Prompt-to-Setup-Your-Mac.bash](Prompt-to-Setup-Your-Mac.bash)
