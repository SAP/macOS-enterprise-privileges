#!/bin/bash

# SAPCorp_Privileges2_Uninstall.sh, 0.2.4
# (c) 2016-2025, SAP SE

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#  
# http://www.apache.org/licenses/LICENSE-2.0
#  
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# latest change: 2025/04/15


# redirect all output to /dev/null
exec >/dev/null 2>&1

currentUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')

if [[ -n "$currentUser" && "$currentUser" != "root" ]]; then

	# make sure the current user has admin rights after uninstallation
	isNotAdmin=$(/usr/bin/dsmemberutil checkmembership -U "$currentUser" -G admin | /usr/bin/grep -i "is not")

	if [[ -n "$isNotAdmin" ]]; then
		/usr/sbin/dseditgroup -o edit -a "$currentUser" -t user admin
	fi
	
	# unload the launch agent and quit all of our applications
	/bin/launchctl bootout gui/$(/usr/bin/id -u "$currentUser") /Library/LaunchAgents/corp.sap.privileges.agent.plist
	/bin/sleep 2 && /usr/bin/sudo -u "$currentUser" /usr/bin/killall "Privileges" "PrivilegesAgent" "PrivilegesCLI"
		
	# delete user-specific files
	userHome=$(/usr/bin/dscl . -read "/Users/$currentUser" NFSHomeDirectory | /usr/bin/sed 's/^[^\/]*//g')
	
	if [[ -d "$userHome" && "$userHome" != "/var/empty" ]]; then
	
		/usr/bin/sudo -u "$currentUser" /usr/bin/defaults delete corp.sap.privileges
		/usr/bin/sudo -u "$currentUser" /usr/bin/defaults delete corp.sap.privileges.agent
		/usr/bin/sudo -u "$currentUser" /usr/bin/defaults delete corp.sap.privileges.docktileplugin
		
		/bin/rm -rf "${userHome}/Library/Preferences/corp.sap.privileges"* \
					"${userHome}/Library/Containers/corp.sap.privileges"* \
					"${userHome}/Library/Group Containers/7R5ZEU67FQ.corp.sap.privileges" \
					"${userHome}/Library/Application Scripts/corp.sap.privileges"*
	fi
fi

# unload the launch daemons and quit them
/bin/launchctl bootout system "/Library/LaunchDaemons/corp.sap.privileges.daemon.plist"
/bin/launchctl bootout system "/Library/LaunchDaemons/corp.sap.privileges.watcher.plist"
/usr/bin/killall PrivilegesDaemon PrivilegesWatcher

# remove the global stuff
/bin/rm -rf "/Library/LaunchDaemons/corp.sap.privileges"* \
			"/Library/LaunchAgents/corp.sap.privileges"* \
			"/Library/Application Support/Privileges" \
			"/Applications/Privileges.app" \
			"/private/etc/paths.d/PrivilegesCLI" \
			"/Library/Scripts/VoiceOver/Privileges Time Left.scpt" \
			"/Library/Application Support/JAMF/Receipts/Privileges_"*.pkg

# remove the package receipt
/usr/sbin/pkgutil --forget "corp.sap.privileges.pkg"

exit 0
