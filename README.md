# Filewave-macOS-Updates

The purpose of this project is to provide a different method for installing macOS updates via Filewave. This method will perform a scripted install using the softwareupdates command, instead of using Filewave's built-in method of deploying updates. This method is largely adapted from https://github.com/bp88/JSS-Scripts/blob/master/AppleSoftwareUpdate.sh

Why?

I haven't had great luck with Filewave's built-in OS updater for macOS.
Works fine for Windows, but with changes Apple has made for update catalogs, bridgeOS updates, various delta's, etc, it seems harder and harder for Filewave to handle this. LANrev was having similar problems before its demise.

The other reason is to have a set-it-and-forget-it model. If you want your fleet to install updates without needing your approval, this model works great. Combine it with a software update delay profile if you don't want updates installed as soon as they come out.

## Setup

The original script, intended for Jamf Pro, has been broken out to 3 scripts. Create a fileset with an empty payload. Add these three scripts to the appropriate script section.

![Filewave Script window](https://github.com/patgmac/Filewave-macOS-Updates/blob/main/images/scripts_window.png?raw=true)

Set the Properties for the fileset to only work with the macOS platform. As well as check the "Requires Reboot" checkbox.

### fw_softwareupdates_verification.sh

This script will determine if updates are required. As well as check that other conditions are met, such as confirming the device is connected to power, filevault is not in the process of encrypting, and there are no power assertions (presentation or web conferencing apps)

### fw_softwareupdate_activation.sh

This activation script is what performs the installation of the updates that were previously updated.

## Contributing

I would love to get community feedback on this. Feel free to file an issue if you have a problem or submit a PR if you have improvements!
