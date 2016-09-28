#!/bin/bash

#make sure any local temp files are silently deleted before running -- why did I use these temp files...? FIX
rm /tmp/ext_att_post_results.xml &>/dev/null
rm /tmp/put_ext_att.xml &>/dev/null
rm /tmp/extension_attributes.xml &>/dev/null


#plist for preferences. just stores the JSS url. people don't like typing.
casfigurator_prefs=~/Library/Preferences/com.bumbletech.casfigurator.plist

echo "
###############################
Welcome to Casfigurator v0.1 - Setup!
https://github.com/bumbletech/casfigurator
Preferences are saved at:
$casfigurator_prefs

  Copyright (C) 2016 Josh Bourdon

This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

###### Warning!!! #######
You're about to run a script that requires write access to your JSS.
Granted, it will only create new items on your JSS, but that said...
if you don't know what this script does, you should open this up 
in a text editor and make sure you trust something that you got 
from some guy on the internet.

This is very much an alpha. There are more checks and error handling that 
need to be added.
Please report bugs! https://github.com/bumbletech/casfigurator/issues
"
sleep 1



#check to see if preferences exist
if [ -f "$casfigurator_prefs" ]; then
	read_jssURL=`defaults read $casfigurator_prefs jssURL`
	if [ "$read_jssURL" == "" ]; then
		echo "Your JSS url is blank. Please enter your JSS Url:"
		read newJssURL
		defaults write $casfigurator_prefs jssURL "$newJssURL"
	fi
else
	echo "Saved preferences don't exist."
	echo "Please enter your JSS URL (starting with https://):"
	read newJssURL
	if [[ "$newJssURL" != "https://"* ]]; then
		echo "Your JSSUrl does not contain https://. Try again:"
		read newJssURL
	fi
	defaults write $casfigurator_prefs jssURL "$newJssURL"; sleep 1
fi


		
saved_jssURL=`defaults read $casfigurator_prefs jssURL`

echo "Your JSS URL is saved as $saved_jssURL"; sleep 1

jssAPIpath="${saved_jssURL}/JSSResource"


echo "Please enter your JSS username:"
read apiUser


function JSSpassCheck() {
echo "Please enter your JSS password:
(Some special characters don't do well in scripts)"
read -s apiPassword

#make sure that file is deleted if we use this more than once -- TO FIX - don't use the local files. This was a dumb idea that sounded great at the time.
rm $local_ext_att_path &>/dev/null

#sets the curl options because the commands get pretty long
curl_options="-s -k -u $apiUser:$apiPassword -H \"Accept: application/xml\""

#path for intial check and extension attribute data output
#currently we need to do the initial check twice, so this saves an extra API call
local_ext_att_path=/tmp/extension_attributes.xml

#check to make sure username and password works
ext_att_check=`curl $curl_options ${jssAPIpath}/mobiledeviceextensionattributes > $local_ext_att_path`

local_ext_att=`cat $local_ext_att_path`

#check if JSS connection failed. Pass will return XML. Fail will return HTML.
if [[ "$local_ext_att" == *"<html>"* ]]; then
	echo "JSS connection failed! Try again! User: $apiUser"
	echo ""
	passwordStatus="failed"
else
	echo "JSS connection Successful!"; sleep 1
	passwordStatus="passed"
fi
}

#run password check 
JSSpassCheck

COUNTER=1
while [[ "$passwordStatus" == "failed" ]]; do
	JSSpassCheck
	if [[ "$passwordStatus" != "passed" ]]; then
		let COUNTER=COUNTER+1
		if [ $COUNTER == 4 ]; then
			echo "Password failed too many times. Check JSS URL, username, password and try again."
			exit 1
		fi
	else
		#exit the loop
		break
	fi
done
			

#variable to get the App Distribution Group extension attribute
app_group_ext_att=`cat $local_ext_att_path | xpath '//mobile_device_extension_attributes/mobile_device_extension_attribute' 2>&1 | grep "App Distribution Group"`

#check if App Distribution Group extension attribute exists
#add it if it doesn't
if [[ "$app_group_ext_att" == "" ]]; then
	echo "Extension Attribute \"App Distribution Group\" NOT FOUND."; sleep 1
	echo "###### Warning ######"
	echo "This script will now attempt to POST a Mobile Device extension attribute"
	echo "to your JSS via the API."
	echo "#####################"; sleep 1
	read -r -p "Would you like to proceed? [y/N] " response
	if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
	then
		app_dist_group_put_xml="<mobile_device_extension_attribute><name>App Distribution Group</name><description>Used to facilitate app assignment during Assisted Configurator Setup</description><data_type>String</data_type><input_type><type>Text Field</type></input_type><inventory_display>General</inventory_display></mobile_device_extension_attribute>"
		echo $app_dist_group_put_xml > /tmp/put_ext_att.xml
		echo "Submitting XML data to JSS for Mobile Device extension attribute:"
		echo "App Distribution Group..."
		
		#Post extension attribute xml to JSS - also send output to file to verify it was successful
		#This command is really long but works - to change
		curl -s -X POST -H "Accept: application/xml" -H "Content-type: application/xml" -k -u $apiUser:$apiPassword -T /tmp/put_ext_att.xml ${jssAPIpath}/mobiledeviceextensionattributes/id/0 | tee -a /tmp/ext_att_post_results.xml
		app_group_ext_att=`cat /tmp/ext_att_post_results.xml`
		echo ""
		
	else
		echo "User has chosen not to add extension attribute to the JSS. Exiting..."
		exit 1
	fi
fi

sleep 1

#get the extension attribute ID
app_group_ext_att_id=`echo $app_group_ext_att | awk -F'<id>|</id>' '{print $2}'`

#make sure we did a good job and check if it's a number	
numbercheck='^[0-9]+$'
if ! [[ $app_group_ext_att_id =~ $numbercheck ]]; then
   echo "Your Extension Attribute ID Not A Number. Not sure how that happened."; sleep 1
   echo "ID is: $app_group_ext_att_id"; sleep 1
   echo "Exiting... Sorry about that..."; sleep 1
   exit 2
else
	echo "App Distribution Group ID is: $app_group_ext_att_id"; sleep 1
fi

#This function will get list the existing app distribution group criteria
#We'll use again when the user is done so a function seems like a good idea
function getAppDistGroups() {

#gets app group ids so we can parse each individual groups criteria later
get_app_group_ids=`curl $curl_options ${jssAPIpath}/mobiledevicegroups | xpath '//mobile_device_groups/mobile_device_group' 2>&1 | grep '<name>App Distribution Group -' | awk -F'<id>|</id>' '{print $2}' | sort`


#clear grouplists variable - if the function gets used again this needs to start with a fresh slate--I think.
group_lists=""

#get App Distribution Group criteria from each smart group
for group_id in $get_app_group_ids
do
	exiting_group_criteria=`curl $curl_options ${jssAPIpath}/mobiledevicegroups/id/$group_id | xpath '//mobile_device_group/criteria/criterion' 2>&1 | grep "App Distribution Group" | awk -F'<value>|</value>' '{print $2}'`
	group_lists="${group_lists}\n${exiting_group_criteria}"
done

echo "$group_lists" | sort
}

echo "Getting App Distribution Groups. Please wait..."
getAppDistGroups

#Check if results are empty. Assume no groups exist and notify user.
if [[ "$get_app_group_ids" == "" ]]; then 
	echo "No App Distribution Groups found!
	"
	sleep 1
fi

echo ""
echo "###### Warning ######
This script will now attempt to POTST App Distribution Groups
to your JSS via the API.
#####################"; sleep 1

read -r -p "
Would you like to add an App Distribution Group group?
This will loop until you say no) [y/N] " response

#loop to add app distribution groups
while [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
do
		echo "Enter the name/criteria for your App Distribution Group:"
		echo "(Don't use spaces)"
			read app_group_criteria 
		echo "<mobile_device_group>
				  <name>App Distribution Group - ${app_group_criteria}</name>
				  <is_smart>true</is_smart>
				  <criteria>
					<size>1</size>
					<criterion>
					  <name>App Distribution Group</name>
					  <priority>0</priority>
					  <and_or>and</and_or>
					  <search_type>like</search_type>
					  <value>${app_group_criteria}</value>
					</criterion>
				  </criteria>
				</mobile_device_group>" > "/tmp/app_group_post_tmp.xml"
	curl -s -X POST -H "Accept: application/xml" -H "Content-type: application/xml" -k -u $apiUser:$apiPassword -T /tmp/app_group_post_tmp.xml ${jssAPIpath}/mobiledevicegroups/id/0 | tee -a /tmp/app_group_tmp_result.xml
	sleep 1
	echo ""
	read -r -p "Would you like to add an App Distribution Group group? [y/N] " response
done

echo "Here's your updated list of App Distribution Groups..."


getAppDistGroups 

echo "\n\nExiting Casfigurator Setup. Thanks for stopping by!" 



