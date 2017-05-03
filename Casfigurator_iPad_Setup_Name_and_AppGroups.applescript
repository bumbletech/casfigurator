with timeout of (60 * 60) seconds
	
	try
		display dialog "Welcome to the Casfigurator v0.1.1!
Created by Josh Bourdon
github.com/bumbletech/casfigurator

This script will help you setup iPads by naming them sequentially (with double digit numbers so devices will sort correctly on your JSS) and \"subscribing\" iPads to App Distribution Groups. Make sure that you've run casfigurator_jss_setup.sh and have active App Distribution Groups available before running this script.


Preferences are saved at ~/Library/Preferences/com.bumbletech.casfigurator.plist"
		--script
	on error
		error number -128
	end try
	
	
	tell application "Finder"
		if not (exists POSIX file "/usr/local/bin/cfgutil") then
			display dialog "Configurator 2 automation tools not found!
 Please install them.
 Here's a guide: http://krypted.com/iphone/install-the-command-line-tools-using-apple-configurator-2/"
			error number -128
		end if
	end tell
	
	
	
	try
		set yourJSSurl to do shell script "defaults read ~/Library/Preferences/com.bumbletech.casfigurator.plist jssURL"
	on error
		display dialog "Preferences for JSS URL not found! Please enter your JSS URL:" default answer "https://" with icon caution
		set yourJSSurl to (the text returned of the result)
		do shell script "defaults write ~/Library/Preferences/com.bumbletech.casfigurator.plist jssURL " & yourJSSurl
	end try
	
	
	display dialog "JSS url is " & yourJSSurl & ".

 Enter your JSS username" default answer ""
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
		display dialog "Username or password incorrect. Exiting workflow. Please try again or contact your JSS Administrator. (Some special characters cause scipts to fail!)" with icon caution
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
		display dialog "App Distribution Group Extension Attribute ID is: " & AppDistExtAttID & ". If this is incorrect, please cancel."
	else
		display dialog "Couldn't find the ID for the Mobile Device Extension Attribute - \"App Distribution Group\". Exiting... Double check your JSS at " & yourJSSurl & "/mobileDeviceExtensionAttributes.html and if \"App Distribution Group\" is missing, please run the casfigurator_jss_setup.sh script." buttons ["OK"] default button 1 with icon caution
		error number -128
	end if
	
	set progress additional description to "Gathering Naming Information"
	
	repeat
		--Prompt for Name/Basename from user 
		display dialog "Please enter the basename you'd like to apply to these devices:" default answer ""
		set baseName to the text returned of the result
		if baseName is not "" then exit repeat
	end repeat
	
	try
		display dialog "Base name is set to \"" & baseName & "\". If you'd like to start over, hit cancel."
	on error
		error number -128
	end try
	
	
	--prompt the user to enter what number to start numbering devices at		
	repeat
		set SequenceMessage1 to "Casfigurator will add a number sequentially to each device. Enter a number to start the sequence. Ex: Starting at \"1\" will name the devices:
"
		set SequenceMessage2 to baseName & " 01
" & baseName & " 02
" & baseName & " 03..."
		display dialog SequenceMessage1 & SequenceMessage2 default answer "1"
		try
			set startingNumber to (the text returned of the result) as integer
			if startingNumber is greater than 0 then exit repeat
		on error
			error number -128
		end try
	end repeat
	
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
		set groupCriteria to do shell script curlCommand & yourJSSurl & "/JSSResource/mobiledevicegroups/id/" & groupID & " | xpath '//mobile_device_group/criteria/criterion' 2>&1 | grep 'App Distribution Group' | awk -F'<value>|</value>' '{print $2}'"
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
	
	set progress description to "iPad Setup"
	set progress additional description to "Renaming Devices in Configurator"
	
	set progress description to "iPad Setup"
	set progress additional description to "Collecting Information on iPads"
	tell script "Configuration Utility"
		-- get data of chosen devices
		copy CNFGconnectedDevices(false) to ¬
			{deviceCount ¬
				, propertyTitles ¬
				, theseDeviceECIDs ¬
				, theseDeviceClasses ¬
				, theseDeviceTypes ¬
				, theseDeviceNames}
	end tell
	try
		tell script "Configuration Utility"
			-- rename the devices
			set devicesInfo to CNFGrenameSpecifiedDevicesUsingNumericSuffix(theseDeviceECIDs, baseName, startingNumber, 2, "-")
		end tell
	on error errorMessage number errorNumber
		if errorMessage = "cfgutil: error: Cannot set value on device.
(Domain: com.apple.configurator.MobileDeviceKit.amd.error Code: -402653161)" then
			display alert "ERROR" message "Profile installed preventing name change" buttons {"Cancel"} default button 1 cancel button 1
		else if errorNumber is not -128 then
			display alert "ERROR" message errorMessage & "
(This error hasn't been caught yet by Casfigurator, so the first sentence you see is the error coming from Configurator—hopefully.)" buttons {"Cancel"} default button 1 cancel button 1
		end if
	end try
	
	set progress description to "iPad Setup"
	set progress additional description to "Sending Data to the JSS"
	
	tell script "Configuration Utility"
		
		copy CNFGvaluesOfSpecifiedProperties("all", {"ECID", "serialNumber", "name"}, false) to ¬
			{deviceCount ¬
				, propertyTitles ¬
				, theseDeviceECIDs ¬
				, theseSerialNumbers ¬
				, theseNames}
		
		
		
		set jssAPIpath to yourJSSurl & "/JSSResource/mobiledevices/serialnumber/"
		repeat with i from 1 to the deviceCount
			set thisECID to item i of theseDeviceECIDs
			set thisSerialNumber to item i of theseSerialNumbers
			set thisName to item i of theseNames
			set thisDeviceAPIpath to yourJSSurl & "/JSSResource/mobiledevices/serialnumber/" & thisSerialNumber & " "
			set curlCommand to "curl -s -u " & apiUser & " "
			set AppleScript's text item delimiters to " "
			
			
			--Define extension attributes
			--since extension attributes vary from system to system, I've tried to define them here to make it (maybe?) a little easier.		
			--set groupSite to "<site><id>8</id><name>Josh's Test Site</name></site>"
			set extAtAppDistGroup to "<extension_attribute><id>" & AppDistExtAttIDNum & "</id><name>App Distribution Group</name><type>String</type><value>" & AppList & "</value></extension_attribute>"
			
			
			set PutXMLforFile to "echo \"<mobile_device><general><display_name>" & thisName & "</display_name><device_name>" & thisName & "</device_name><name>" & thisName & "</name></general><extension_attributes>" & extAtAppDistGroup & "</extension_attributes></mobile_device>\" > /tmp/deviceConfigPutTemp.xml"
			do shell script PutXMLforFile
			set AppleScript's text item delimiters to ""
			set putRequest to curlCommand & thisDeviceAPIpath & "-T \"/tmp/deviceConfigPutTemp.xml\" -X PUT"
			set ThePutRequest to do shell script putRequest
			
			
			if "The server has not found anything matching the request URI" is in ThePutRequest then
				display dialog "The iPad " & thisSerialNumber & " could not be found on the JSS: '" & yourJSSurl & "'. Please make sure this device is enrolled. The script will try the next iPad." with icon caution
				error "Could not find iPad" & thisSerialNumber & " on the JSS: '" & yourJSSurl & "'"
			end if
			
		end repeat
		
		set progress description to "iPad Setup"
		set progress additional description to "Sending Update Device Commands to JSS"
		
		
		set baseNameURLencoded to do shell script "/usr/bin/python -c 'import sys, urllib; print urllib.quote(sys.argv[1])' " & quoted form of baseName
		
		set getJSSdeviceIDs to do shell script "curl -s -u \"Accept: application/xml\" " & apiUser & " " & yourJSSurl & "/JSSResource/mobiledevices/match/" & baseNameURLencoded & "* | xpath '//mobile_devices/mobile_device/id' 2>&1 | awk -F'<id>|</id>' '{print $2}' | tail -n +3"
		
		set oldDelim to AppleScript's text item delimiters
		
		set AppleScript's text item delimiters to return
		
		set theList to text items of getJSSdeviceIDs
		
		set AppleScript's text item delimiters to ","
		
		set theListString to theList as string
		
		set JSScommandURLupdate to yourJSSurl & "/JSSResource/mobiledevicecommands/command/UpdateInventory/id/"
		
		set JSScommandURLblankPush to yourJSSurl & "/JSSResource/mobiledevicecommands/command/BlankPush/id/"
		
		set updateDevices to do shell script "curl -s -u \"Accept: application/xml\" " & apiUser & " " & JSScommandURLupdate & theListString & " -X POST"
		
		set blankPush to do shell script "curl -s -u \"Accept: application/xml\" " & apiUser & " " & JSScommandURLblankPush & theListString & " -X POST"
		
		--creates update commands to force the JSS to recalculate the devices smart groups
		updateDevices
		--creates blank push because everybody likes a big fat placebo. Right, Brent?
		delay 2
		blankPush
		
		
	end tell
	
	tell application "Apple Configurator 2"
		activate
	end tell
	
	display dialog "All done! Don't forget those wallpaper blueprints with name tokens and beautiful QR codes."
	
end timeout
