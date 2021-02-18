#!/bin/bash

# fw_softwareupdates_verification.sh


ListOfSoftwareUpdates="/tmp/ListOfSoftwareUpdates"
LoggedInUser="$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }')"

fvStatusCheck (){
    # Check to see if the encryption process is complete
    FVStatus="$(/usr/bin/fdesetup status)"
    if [[ $(/usr/bin/grep -q "Encryption in progress" <<< "$FVStatus") ]]; then
        echo "The encryption process is still in progress."
        echo "$FVStatus"
        exit 13
    fi
}


powerCheck (){
    # This is meant to be used when doing CLI update installs.
      if [[ "$(/usr/bin/pmset -g ps | /usr/bin/grep "Battery Power")" = "Now drawing from 'Battery Power'" ]]; then
          echo "No AC power"
          exit 1
      fi
}


# Function to do best effort check if using presentation or web conferencing is active
checkForDisplaySleepAssertions() {
    Assertions="$(/usr/bin/pmset -g assertions | /usr/bin/awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ {gsub(/^\ +/,"",$0); print};')"

    # There are multiple types of power assertions an app can assert.
    # These specifically tend to be used when an app wants to try and prevent the OS from going to display sleep.
    # Scenarios where an app may not want to have the display going to sleep include, but are not limited to:
    #   Presentation (KeyNote, PowerPoint)
    #   Web conference software (Zoom, Webex)
    #   Screen sharing session
    # Apps have to make the assertion and therefore it's possible some apps may not get captured.
    # Some assertions can be found here: https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes
    if [[ "$Assertions" ]]; then
        echo "The following display-related power assertions have been detected:"
        echo "$Assertions"
        echo "Exiting script to avoid disrupting user while these power assertions are active."

        exit 1
    fi
}


/usr/sbin/softwareupdate -l 2>&1 > "$ListOfSoftwareUpdates"


UpdatesNoRestart=$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep recommended | /usr/bin/grep -v restart | /usr/bin/cut -d , -f 1 | /usr/bin/sed -e 's/^[[:space:]]*//' | /usr/bin/sed -e 's/^Title:\ *//')
RestartRequired=$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep restart | /usr/bin/grep -v '\*' | /usr/bin/cut -d , -f 1 | /usr/bin/sed -e 's/^[[:space:]]*//' | /usr/bin/sed -e 's/^Title:\ *//')


# Let's make sure FileVault isn't encrypting before proceeding any further
fvStatusCheck

# If there are no system updates, reset timer and exit script
if [[ "$UpdatesNoRestart" == "" ]] && [[ "$RestartRequired" == "" ]]; then
    echo "No updates at this time."
    exit 1
fi

# If we get to this point, there are updates available.
# If there is no one logged in, let's try to run the updates.
if [[ "$LoggedInUser" == "" ]]; then
    powerCheck
else
    checkForDisplaySleepAssertions
    powerCheck
fi

# If reboot is not required for an update, we assume it's because of Safari. So if Safari
# is running, quit. If you'd rather not do this, remove this section.
if [[ "$UpdatesNoRestart" != "" ]] && [[ ! "$(/bin/ps -axc | /usr/bin/grep -e Safari$)" ]]; then
    echo "Safari is running"
    exit 1
fi

/usr/sbin/softwareupdate -d -a
