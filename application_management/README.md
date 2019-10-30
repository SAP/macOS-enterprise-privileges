# Managing Privileges

As of Privileges 1.0.5, it is possible to manage the following settings for **Privileges.app** or the **PrivilegesCLI** command line tool:

Key: **DockToggleTimeout**
 
Value: **Integer**
 
Description: Set a fixed timeout for the Dock tile's `Toggle Privileges` command. After this time, the admin rights are removed and set back to standard user rights. A value of **0** disables the timeout and allows the user to permanently toggle privileges.



Key: **EnforcePrivileges**
 
Value: `admin`, `user` or `none`

*Note: This is a string value.*

Description: Enforces certain privileges. Whenever **Privileges.app** or the **PrivilegesCLI** command line tool are launched,the corresponding privileges are set.  

* **admin**: Logged-in user has admin privileges.
* **user**: Logged-in user has standard user privileges
* **none**: **Privileges.app** and the **PrivilegesCLI** command line tool are disabled and it is not possible anymore to change from admin user to standard user using these tools.

An example configuration profile is available via the link below:

[Privileges macOS Configuration Profile](example_profile/Privileges.mobileconfig)

Dock Icon
===================================

The **Privileges.app** dock icon will change colors from the standard color scheme if **Privileges.app** is being managed by a macOS configuration profile which is using the **EnforcePrivileges** key.

The icon is black with a green outline and displays a locked padlock icon when you are a standard user.

![](readme_images/icon_bk1.png)

The icon is black with a yellow outline and displays an unlocked padlock icon when you are an administrator.

![](readme_images/icon_bk2.png)

This color change will not occur if only the **DockToggleTimeout** key is being managed. This color change is specific to **Privileges.app** and the **PrivilegesCLI** command line tool being managed by the **EnforcePrivileges** key.

Support
===================================
This project is 'as-is' with no support, no changes being made.  You are welcome to make changes to improve it but we are not available for questions or support of any kind.
