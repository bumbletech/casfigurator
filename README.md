casphigurator
======
*Improved, wired iOS “imaging” with Configurator and Casper*

####Introduction
Casphigurator is a proof of concept AppleScript to connect Apple Configurator 2 with the Casper JSS API to allow simplified iPad setup with known app distribution lists.

This script can be run on its own after initial iPad setup, or as part of an Automator workflow to allow for a single-launch guided setup.

####Requirements
1. X 10.11 - El Capitan (tested with 10.11.5)
2. Configurator 2 (tested with v2.2.1)
3. Configurator Automation Tools Installed
4. JAMF’s Casper Suite (tested with 9.91)
5. A user with Mobile Device write access in the API
6. Comfortability with AppleScript
7. Probably a test JSS. Definitly a test JSS.

####Basic Project Goal
Give field technicians and laymen a tool to setup cart/non-user assigned iOS devices with pre-determined app distribution without having to manually create groups, and scope apps.

Essentially: Emulate Munki+DeployStudio for iPads as much as possible.

(Also, come up with a better name. Portmanteaus are great and all but…)

Setup
-----
###On the JSS

The basic goal is to try to emulate Munki-type manifests in the JSS. This is achieved by an extension attribute called “App Distribution Group” and series of smart groups.

Create your extension attribute with the following information:

1. Display Name: App Distribution Group
2. Description: Used to facilitate app assignment with Casphigurator
3. Data Type: String
4. Inventory Display: General
5. Input Type: Text Field

You'll also need to know the the proper XML the JSS API uses to use this extension attribute within your JSS. As extension attributes are custom information, the ID number will be different from system to system.

The extension attributes will be populated by space separated values that will function as “like” criteria for smart groups. If you want an app distribution group for the Google Drive apps (Drive, Docs, Sheets & Slides), you decide how you should name this distribution group. In my case it’s “GoogleDriveApps.” So, we need create a smart group where “App Distribution Group” is LIKE “GoogleDriveApps.”

With that group created, we need to make sure all of the associated Google Drive apps in the app catalog are scoped to this group.

That’s the basics of Casphigurator App distribution. Lather, rinse and repeat for any apps and distribution groups you’d like.

###On the Mac
1. Install Configuration Automation Tools:
2. Launch Configurator
3. In the drop down menus - “Apple Configurator 2 > Install Migration Tools” (check out http://krypted.com/iphone/install-the-command-line-tools-using-apple-configurator-2/ for a better guide)

If you’re using DEP, you’ll want to make sure that Configurator 2 and your JSS are using the same Supervision Identity. See Supervision Identities section in this JAMF guide: http://resources.jamfsoftware.com/documents/technical-papers/Deploying-iOS-Devices-with-the-Casper-Suite-and-Apple-Configurator-2-v9.82-or-Later.pdf

###In The Script

*(I just want to start off with a big disclaimer that despite some genericizing, this script is still very derived from the needs of my envriornment. Undoubtedly many things could be written and implemented in a better way—this is mostly a proof of concept and will require a bit of effort on your part to custom tailor it to your environment if you want to play around with it.)*

At the very top of the script we’re going to set the variable for your JSS—fairly straight forward.

There are also variables for extension attributes (and due to my lack of expertise in trying to put these variables in a more friendly place) they’re buried down in the section commented “--Define extension attributes”. What you want to set here is completely up to you-—you just need to know the right XML string for your extension attributes.

For the ExtAtDistGroup variable, you can pull the ID for you "App Distribution Group" extension atribute from the URL of it's page on the JSS:

`.../mobileDeviceExtensionAttributes.html?id=10`

There's a large section to assist the user in setting the basename for the devices. I use a basename that's [District]-[Building]-IPA-[CartNumber/Department/Room]-##. If your envionrment is not as complex as mine, you'll likely want to do a bit re-writting to simplify it.

You'll want to customize the list of items that can become the "AppList" variable to match your corresponding smart group criteria. Search for the "--Set App List Variable" comment to find this section.



