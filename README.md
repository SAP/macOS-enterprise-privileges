# Privileges.app

Description 
===================================

**Privileges.app** for macOS is designed to allow users to work as a standard user for day-to-day use, by providing a quick and easy way to get administrator rights when needed. When you do need admin rights, you can get them by clicking on the **Privileges** icon in your Dock.

We believe all users, including all developers, can benefit from using **Privileges.app**. Working as a standard user instead of an administrator adds another layer of security to your Mac and is considered a security best practice. **Privileges.app** helps enable users to act as administrators of the system only when required.



Installation
===================================

1. Log into your Mac using an account with admin privileges

2. Download **Privileges.app**.

3. Copy **Privileges.app** to to the Applications folder on your Mac.
<br>
<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_103_installed.png)
<br>
4. Launch **Privileges.app** and click the `Remove Privileges` button.
<br>
5. Install the helper tool when prompted.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/privileges_103_installation.gif)
<p></p>
<p></p>
The logged-in account should now be a standard user account.
<p></p>


**Note:** To use all of **Privileges.app**'s functions, we recommend adding **Privileges.app** to the dock.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_in_Dock.png)
<p></p>
Using Privileges.app
===================================

If you are a standard user and want admin rights, verify that **Privileges.app** is installed then use the following procedure:

1. Launch **Privileges.app** 
2. Click the `Request Privileges` button.
3. The **Privileges** dock icon should change to look like a yellow unlocked padlock.
4. A **Privileges have been changed successfully** message should appear.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/privileges_get_admin_rights.gif)
<p></p>
5. The logged-in account should now have admin rights.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/user_account_with_admin_user_privileges.png)
<p></p>


If you are a admin user and want to remove admin rights, verify that **Privileges.app** is installed then use the following procedure:

1. Launch **Privileges.app** 
2. Click the `Remove Privileges` button.
3. The **Privileges** dock icon should change to look like a green locked padlock.
4. A **Privileges have been changed successfully** message should appear.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/privileges_remove_admin_rights.gif)
<p></p> 
5. The logged-in account should now be a standard user account.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/user_account_with_standard_user_privileges.png)
<p></p>


Helper Tools
===================================

The following helper tools are installed to allow **Privileges.app** the necessary access rights to grant or remove admin rights:

`/Library/PrivilegedHelperTools/corp.sap.privileges.helper`

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_privileged_helper_app.png)
<br>

`/Library/LaunchDaemons/corp.sap.privileges.helper.plist`

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_helper_app_LaunchDaemon.png)
<br>

For more information on privilege elevation using a privileged helper app and LaunchDaemon, please see the link below:

[https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/AccessControl.html](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/AccessControl.html)


Frequently Asked Questions
===================================


### Why does the icon for Privileges.app change colors in the Dock?

This is by design. The icon is green and displays a locked padlock icon when you are a standard user. 

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_icon_locked.png)
<br>

The icon is yellow and displays an unlocked padlock icon when you are an administrator.

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_icon_unlocked.png)
<br>

### By default, is there a time limit on the admin rights granted by Privileges.app?

No. Admin rights are granted until some process (like running **Privileges.app** again) takes them away.

### Can I set Privileges.app to give me administrator rights for a defined amount of time?

Yes. You can use the **Toggle Privileges** option on the dock icon to get admin rights for a set amount of time (the default amount is 20 minutes.)

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Toggle_Privileges.png)
<br>

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_toggled_for_20_minutes.png)
<br>

To set the amount of time used by the **Toggle Privileges** option, use the following procedure:

1. Launch **Privileges.app**
2. Click on the **Privileges** menu and select **Preferences**
3. Select the desired amount of time from the available options.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/set_privileges_toggle_time_limit.gif)

### What actions do the Lock Screen and Login Window toggle options perform?

The **Lock Screen** toggle option locks your screen.

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/privileges_toggle_locked_screen.gif)
<br>

The **Login Window** toggle option returns you to the Login Window without logging you out.

<br>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/privileges_toggle_login_window.gif)
<br>


### How do I use Privileges.app in a script or from the command line?

**Privileges.app** supports command line use. To use the **PrivilegesCLI** command line tool, run `/Applications/Privileges.app/Contents/Resources/PrivilegesCLI` followed by the option you want to use.

The **PrivilegesCLI** command line tool currently supports the following options:

* `/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add`: Adds the logged-in user to the admin group.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/PrivilegesCLI_add.png)
<p></p> 
* `/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove`: Removes the logged-in user from the admin group.
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/PrivilegesCLI_remove.png)
<p></p> 


For assistance, please run the following command to display all available options:

`/Applications/Privileges.app/Contents/Resources/PrivilegesCLI`

![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/PrivilegesCLI_help.png)




### How do I uninstall Privileges.app?

1. Ensure that your user account has admin rights. If needed, launch **Privileges.app** one final time to make sure you have them.
2. Remove the following files:

* `/Applications/Privileges.app`
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_103_installed.png)
<p></p>
* `/Library/PrivilegedHelperTools/corp.sap.privileges.helper`
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_privileged_helper_app.png)
<p></p>
* `/Library/LaunchDaemons/corp.sap.privileges.helper.plist`
<p></p>
![](https://github.com/SAP/mac-enterprise-privileges/blob/master/readme_images/Privileges_helper_app_LaunchDaemon.png)
<p></p>




Support
===================================
This project is 'as-is' with no support, no changes being made.  You are welcome to make changes to improve it but we are not available for questions or support of any kind.
