#!/bin/bash

# fw_softwareupdate_activation.sh
# Modified to work with Filewave by Patrick Gallagher
# Original comments retained, but much of it does not apply to this version.


# This script is meant to be used with Jamf Pro and makes use of Jamf Helper.
# The idea behind this script is that it alerts the user that there are required OS
# updates that need to be installed. Rather than forcing updates to take place through the
# command line using "softwareupdate", the user is encouraged to use the GUI to update.
# In recent OS versions, Apple has done a poor job of testing command line-based workflows
# of updates and failed to account for scenarios where users may or may not be logged in.
# The update process through the GUI has not suffered from these kind of issues. The
# script will allow end users to postpone/defer updates X amount of times and then will
# give them one last change to postpone.
# This script should work rather reliably going back to 10.12 and maybe further, but at
# this point the real testing has only been done on 10.14.
# Please note, that this script does NOT cache updates in advance. The reason for this is
# that sometimes Apple releases updates that get superseded in a short time frame.
# This can result in downloaded updates that are in the /Library/Updates path that cannot
# be removed in 10.14+ due to System Integrity Protection.
#
#
# Here is the expected workflow with this script:
# If no user is logged in, the script will install updates through the command line and
#    shutdown/restart as required.
# If a user is logged in and there are updates that require a restart, the user will get
#    prompted to update or to postpone.
# If a user is logged in and there are no updates that require a restart, the updates will
#    get installed in the background (unless either Safari or iTunes are running.)
#
# There are a few exit codes in this script that may indicate points of failure:
# 11: No power source detected while doing CLI update.
# 12: Software Update failed.
# 13: FV encryption is still in progress.
# 14: Incorrect deferral type used.
# 15: Insufficient space to perform update.

# Potential feature improvement
# Allow user to postpone to a specific time with a popup menu of available times

###### ACTUAL WORKING CODE  BELOW #######


OSMajorVersion="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d '.' -f 2)"
OSMinorVersion="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d '.' -f 3)"


# Path to temporarily store list of software updates. Avoids having to re-run the softwareupdate command multiple times.
ListOfSoftwareUpdates="/tmp/ListOfSoftwareUpdates"


updateCLI (){
    # Install all software updates
    /usr/sbin/softwareupdate -ia --verbose 1>> "$ListOfSoftwareUpdates" 2>> "$ListOfSoftwareUpdates" &

    ## Get the Process ID of the last command run in the background ($!) and wait for it to complete (wait)
    # If you don't wait, the computer may take a restart action before updates are finished
    SUPID=$(echo "$!")

    wait $SUPID

    SU_EC=$?

    echo $SU_EC

    return $SU_EC
}


updateRestartAction (){
    # On T2 hardware, we need to shutdown on certain updates
    # Verbiage found when installing updates that require a shutdown:
    #   To install these updates, your computer must shut down. Your computer will automatically start up to finish installation.
    #   Installation will not complete successfully if you choose to restart your computer instead of shutting down.
    #   Please call halt(8) or select Shut Down from the Apple menu. To automate the shutdown process with softwareupdate(8), use --restart.
    if [[ "$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep -E "Please call halt")" || "$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep -E "your computer must shut down")" ]] && [[ "$SEPType" ]]; then
        if [[ "$OSMajorVersion" -eq 13 && "$OSMinorVersion" -ge 4 ]] || [[ "$OSMajorVersion" -ge 14 ]]; then
            # Resetting the deferral count
            echo "Restart Action: Shutdown/Halt"

            /sbin/shutdown -h now
            exit 0
        fi
    fi

    # If no shutdown is required then let's go ahead and restart
    echo "Restart Action: Restart"

    /sbin/shutdown -r now
    exit 0
}


runUpdates (){
    SU_EC="$(updateCLI)"

    # softwareupdate does not exit with error when insufficient space is detected
    # which is why we need to get ahead of that error
    if [[ "$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep -E "Not enough free disk space")" ]]; then
        SpaceError=$(echo "$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep -E "Not enough free disk space" | /usr/bin/tail -n 1)")
        AvailableFreeSpace=$(/bin/df -g / | /usr/bin/awk '(NR == 2){print $4}')

        echo "$SpaceError"
        echo "Disk has $AvailableFreeSpace GB of free space."

        return 15
    fi

    if [[ "$SU_EC" -eq 0 ]]; then
        updateRestartAction
    else
        echo "/usr/bin/softwareupdate failed. Exit Code: $SU_EC"

        return 12
    fi

    exit 0
}


UpdatesNoRestart=$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep recommended | /usr/bin/grep -v restart | /usr/bin/cut -d , -f 1 | /usr/bin/sed -e 's/^[[:space:]]*//' | /usr/bin/sed -e 's/^Title:\ *//')
RestartRequired=$(/bin/cat "$ListOfSoftwareUpdates" | /usr/bin/grep restart | /usr/bin/grep -v '\*' | /usr/bin/cut -d , -f 1 | /usr/bin/sed -e 's/^[[:space:]]*//' | /usr/bin/sed -e 's/^Title:\ *//')

# Determine Secure Enclave version
SEPType="$(/usr/sbin/system_profiler SPiBridgeDataType | /usr/bin/awk -F: '/Model Name/ { gsub(/.*: /,""); print $0}')"

if [[ "$RestartRequired" != "" ]]; then

  runUpdates
  RunUpdates_EC=$?

  if [[ $RunUpdates_EC -ne 0 ]]; then
      exit $RunUpdates_EC
  fi
fi


# Install updates that do not require a restart
# Future Fix: Might want to see if Safari and iTunes are running as sometimes these apps sometimes do not require a restart but do require that the apps be closed
# A simple stop gap to see if either process is running.
if [[ "$UpdatesNoRestart" != "" ]]; then
    updateCLI &>/dev/null
fi

exit 0
