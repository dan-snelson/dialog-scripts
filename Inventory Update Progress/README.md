# Inventory Update Progress with swiftDialog

> Provide your users more detailed feedback when updating inventory via Jamf Pro Self Service

![swiftDialog Inventory Update Progress)](images/Self_Service_Inventory_Update_Progress_with_swiftDialog.png "swiftDialog Inventory Update Progress)")

## Background

While conducting some internal training earlier this week, one of our TSRs asked: "Is updating inventory where the blue circle just spins and spins but doesn't appear to do anything?"

"Yes," was my deflated reply.

Hopefully after implementing this script, you'll never have to be asked that question again.

[Continue reading …](https://snelson.us/2022/10/inventory-update-progress/)

## Script

> :fire: **Breaking Change** for users prior to `0.0.7` :fire:
> 
> Version `0.0.7` modifies the Script Parameter Label for `scriptLog` — changing it to a hard-coded variable in the script (as it should have been all along) — Sorry for any Dan-induced headaches.

- [swiftDialog-Inventory-Update-Progress.zsh](swiftDialog-Inventory-Update-Progress.zsh)
