casfigurator
======
*Improved, wire-facilitated but over-the-air iOS “imaging” with Configurator and Casper*

###**_Now on version 0.1!_**
You can find it on the [releases page](https://github.com/bumbletech/casfigurator/releases)

####Introduction
Casphigurator is a collection of scripts that allow you to connect Apple Configurator 2 with the Casper JSS API to allow guided iPad setup and add App Distribution Lists to your device records.

This script can be run on its own after initial iPad setup, or as part of an Automator workflow to allow for a single-launch guided setup.

[Here's a video overview and demo of version v0.1](https://youtu.be/taqDR3x-GC4)

[View the orignal proof-of-concept video and demo here](https://www.youtube.com/watch?v=g98iwQDwUb0)

####Requirements
1. X 10.11 - El Capitan (tested with 10.11.5)
2. Configurator 2 (tested with v2.2.1-v2.3)
3. Configurator Automation Tools Installed
4. JAMF’s Casper Suite (tested with 9.91-v9.96)
5. A user with Mobile Device write access in the API
7. Probably a test JSS. Definitly a test JSS.

####Basic Project Goal
Give field technicians and laymen a tool to setup cart/non-user assigned iOS devices with pre-determined app distribution without having to manually create groups, and scope apps.

Essentially: Emulate Munki+DeployStudio for iPads as much as possible.

(Also, come up with a better name. Portmanteaus are great and all but…)


A few words of caution
-----

This has been tested on a fresh JSS as well as my test and production JSSes. While I'm confident you will not break anything that already exists, your experince may vary. The script still make some assumptions (like your JSS being available, your devices being supervised, etc). So far, I've handled a few major errors—some will just pass the error on to you and quit. [Please, report any bugs.](https://github.com/bumbletech/casfigurator/issues)

Setup
-----
###On the JSS

The basic goal is to try to emulate Munki-type manifests in the JSS. This is achieved by an extension attribute called “App Distribution Group” and series of smart groups.

Version 0.1 comes with "casfigurator_jss_setup.sh"—a bash script that will add the proper extension attributes and help you create smart groups with the proper criteria. All you need is your JSS URL and a JSS account with write access to the API.

Otherwise, you can create your extension attribute with the following information:

1. Display Name: "App Distribution Group"
2. Description: Used to facilitate app assignment with Casphigurator
3. Data Type: String
4. Inventory Display: General
5. Input Type: Text Field

The setup script will also help you create your App Distribution Smart groups, but you can create them manually as well:

1. Display Name: "App Distribution Group - (criteria/name)"
2. Criteria: "App Distribution Group" is LIKE "(criteria-string)" <- This criteria string can't contain spaces

You will then need to scope apps to your smart groups on the JSS. For now, you'll have to do that the old fashined way.

###On the Mac
Install Configuration Automation Tools:
1. Launch Configurator
2. In the drop down menus - “Apple Configurator 2 > Install Migration Tools” (check out http://krypted.com/iphone/install-the-command-line-tools-using-apple-configurator-2/ for a better guide)

If you’re using DEP, you’ll want to make sure that Configurator 2 and your JSS are using the same Supervision Identity. See Supervision Identities section in this JAMF guide: http://resources.jamfsoftware.com/documents/technical-papers/Deploying-iOS-Devices-with-the-Casper-Suite-and-Apple-Configurator-2-v9.82-or-Later.pdf

###The Client-side AppleScripts

Casfigurator_iPad_Setup_Name_and_AppGroups.app
Casfigurator_Unplugged-Change_AppGroups

Version v0.1 reads your extension attribute for "App Distribution Groups" and smart groups with names  like "App Distribution Group" from the JSS API. You will not need to edit this script.

All you will need is your JSS URL, a JSS account with write access to the API and a copy of Configurator 2 with the proper supervision authoriy over the connected iPads.

There is also an "Unplugged" AppleScript that will allow you to change App Distribution Group criteria written to your device records without devices being connected to Configurator 2. This uses the JSS API's match function to find devices by their basename and then overwrite the "App Distribution Group" field on each device record with your newly entered selections.



