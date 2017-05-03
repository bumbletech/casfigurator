with timeout of (60 * 60) seconds
	
	try
		display dialog "Welcome to the Casfigurator v0.1.1!
Created by Josh Bourdon
github.com/bumbletech/casfigurator
	
This script will change app distribution groups for iPads by name. Devices do not need to be plugged into your computer as this searches for devices on the JSS by name. If a device is incorrectly named or reverted to 'iPad', there will be no change.
	
Preferences are saved at ~/Library/Preferences/com.bumbletech.casfigurator.plist"
		--script
	on error
		error number -128
	end try
	
	
	try
		set yourJSSurl to do shell script "defaults read ~/Library/Preferences/com.bumbletech.casfigurator.plist jssURL"
	on error
		display dialog "Preferences for JSS URL not found! Please enter your JSS URL:" default answer "https://" with icon caution
		set yourJSSurl to (the text returned of the result)
		do shell script "defaults write ~/Library/Preferences/com.bumbletech.casfigurator.plist jssURL " & yourJSSurl
	end try
	
	
	display dialog "JSS url is " & yourJSSurl & " Enter your JSS username" default answer ""
	set jssUser to (the text returned of the result)
	
	display dialog "Enter your password" default answer "" with hidden answer
	if length of (text returned of the result) is not 0 then
		set jssPass to (the text returned of the result)
	else
		display dialog "You didn't enter a password! Re-run this script again." buttons ["OK"] default button 1 with icon caution
		error number -128
	end if
	
	set apiUser to jssUser & ":" & jssPass
	
	
	
	set curlCommand to "curl -s -u " & apiUser & " " & yourJSSurl
	
	set Authcheck to do shell script curlCommand & "/JSSResource/categories"
	
	
	if "Unauthorized" is in Authcheck then
		display dialog "Username or password incorrect. Exiting workflow. Please try again or contact the Apple Administrator. (Some special characters cause scipts to fail!)" with icon caution
		error "Could not authenticate to the JSS with provided username and password."
		error number -128
		exit repeat
	else
		display dialog "JSS connection successful!"
	end if
	
	
	
	
	
	--display dialog "Enter your JSS username" default answer ""
	--set apiUser to (the text returned of the result)
	
	
	
	set progress description to "iPad Setup"
	set progress additional description to "Collecting Extension Attribute Data from the JSS"
	
	set AppDistGroupIdCommand to curlCommand & "/JSSResource/mobiledeviceextensionattributes | xpath '//mobile_device_extension_attributes/mobile_device_extension_attribute' 2>&1 | grep \"App Distribution Group\"| awk -F'<id>|</id>' '{print $2}'"
	
	set AppDistExtAttID to do shell script AppDistGroupIdCommand
	
	try
		set AppDistExtAttIDNum to AppDistExtAttID as number
	end try
	
	if AppDistExtAttIDNum is greater than 0 then
		display dialog "App Distribution Group Extension Attribute ID is: " & AppDistExtAttID
	else
		display dialog "Couldn't find the ID for the Mobile Device Extension Attribute - \"App Distribution Group\". Exiting... Double check your JSS at " & yourJSSurl & "/mobileDeviceExtensionAttributes.html and if \"App Distribution Group\" is missing, please run the casfigurator_jss_setup.sh script." buttons ["OK"] default button 1 with icon caution
		error number -128
	end if
	
	display dialog "Enter the cart name of the devices for which you'd like to update:" default answer ""
	set CartName to (the text returned of the result)
	
	set CartNameURLencoded to do shell script "/usr/bin/python -c 'import sys, urllib; print urllib.quote(sys.argv[1])' " & quoted form of CartName
	
	
	set oldDelim to AppleScript's text item delimiters
	set AppleScript's text item delimiters to " "
	set progress description to "Checking JSS..."
	set curlCommand to "curl -s -u " & apiUser & " "
	set matchApiPath to yourJSSurl & "/JSSResource/mobiledevices/match/" & CartNameURLencoded & "* | xpath '//mobile_devices/mobile_device/name' 2>&1 | awk -F'<name>|</name>' '{print $2}' | tail -n +3 | sort"
	set getCartDevices to do shell script curlCommand & matchApiPath
	set AppleScript's text item delimiters to return
	set deviceList to text items of getCartDevices
	set listSize to count of deviceList
	display dialog "Found " & listSize & " devices (if devices are not named correctly they will not show up):
" & deviceList
	
	if listSize is 0 then
		display dialog "No devices found! Exiting!"
		error number -128
	end if
	
	set progress additional description to "Getting App lists..."
	
	set curlCommand to "curl -s -u " & apiUser & " \"Accept: application/xml\" "
	set oldDelim to AppleScript's text item delimiters
	set AppleScript's text item delimiters to return
	set JSSAppGroupIds to curlCommand & yourJSSurl & "/JSSResource/mobiledevicegroups | xpath '//mobile_device_groups/mobile_device_group' 2>&1 | grep '<name>App Distribution Group -' | awk -F'<id>|</id>' '{print $2}' | sort"
	set getJSSAppGroupIds to do shell script JSSAppGroupIds
	
	set GroupIds to text items of getJSSAppGroupIds
	
	set AppleScript's text item delimiters to " "
	
	set groupLists to {}
	
	set rawGrouops to GroupIds
	repeat with groupID in rawGrouops
		--display dialog "group id:" & groupId
		--display dialog "command: " & curlCommand & yourJSSurl & "/JSSResource/mobiledevicegroups/id/" & groupId & " | xpath '//mobile_device_group/criteria/criterion' 2>&1 | grep 'App Distribution Group' | awk -F'<value>|</value>' '{print $2}'"
		set groupCriteria to do shell script curlCommand & yourJSSurl & "/JSSResource/mobiledevicegroups/id/" & groupID & " | xpath '//mobile_device_group/criteria/criterion' 2>&1 | grep 'App Distribution Group' | awk -F'<value>|</value>' '{print $2}'"
		--display dialog "Group Criteria: " & groupCriteria
		set groupLists to groupLists & groupCriteria
	end repeat
	
	set AppList to choose from list groupLists with title "App Distribution Lists" with prompt "Select app lists this iPad should subscribe to. Hold down the command key to choose more than one." with multiple selections allowed and empty selection allowed
	
	if AppList is false then
		error number -128
	end if
	
	try
		display dialog "You have selected: " & AppList
	on error
		error number -128
	end try
	
	try
		set curlCommand to "curl -s -u " & apiUser & " "
		set oldDelim to AppleScript's text item delimiters
		set AppleScript's text item delimiters to " "
		set extAtAppDistGroup to "<extension_attribute><id>10</id><name>App Distribution Group</name><type>String</type><value>" & AppList & "</value></extension_attribute>"
		set PutXMLforFile to "echo \"<mobile_device><extension_attributes>" & extAtAppDistGroup & "</extension_attributes></mobile_device>\" > /tmp/deviceConfigPutTemp.xml"
		do shell script PutXMLforFile
		set progress description to "Checking JSS..."
		set matchApiPath to yourJSSurl & "/JSSResource/mobiledevices/match/" & CartName & "* | xpath '//mobile_devices/mobile_device/id' 2>&1 | awk -F'<id>|</id>' '{print $2}' | tail -n +3"
		set getCartDevices to do shell script curlCommand & matchApiPath
		display dialog getCartDevices
		set AppleScript's text item delimiters to return
		set deviceList to text items of getCartDevices
		set counter to 0
		repeat with nextLine in deviceList
			set counter to counter + 1
			set progress additional description to "Sending Data - Device #" & counter
			set thisDeviceAPIpath to yourJSSurl & "/JSSResource/mobiledevices/id/" & nextLine & " "
			set putRequest to curlCommand & thisDeviceAPIpath & "-T \"/tmp/deviceConfigPutTemp.xml\" -X PUT"
			--display dialog "URL:
			--" & putRequest & "
			--" & PutXMLforFile
			display dialog putRequest
			do shell script putRequest
		end repeat
		
		display dialog "All Done!"
	end try
	
end timeout
