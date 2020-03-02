# Managing Privileges

As of Privileges 1.5.0, it is possible to manage the following settings for **Privileges.app** or the **PrivilegesCLI** command line tool:

Preference domain: **corp.sap.privileges**

Key: **DockToggleTimeout**
 
Value: **Integer**
 
Description: Set a fixed timeout for the Dock tile's `Toggle Privileges` command. After this time, the admin rights are removed and set back to standard user rights. A value of **0** disables the timeout and allows the user to permanently toggle privileges.



Key: **EnforcePrivileges**
 
Value: `admin`, `user` or `none`

*Note: This is a string value.*

Description: Enforces certain privileges. Whenever **Privileges.app** or the **PrivilegesCLI** command line tool are launched,the corresponding privileges are set.  

* **admin**: administrator rights always set by Privileges.
* **user**: standard user rights are always set by Privileges.
* **none**: **Privileges.app** and the **PrivilegesCLI** command line tool are disabled and it is not possible to change user privileges using these tools.


Key: **LimitToGroup**
 
Value: a string containing the name of a specified group

*Note: This is a string value.*

Description: Limits the usage of **Privileges.app** to the given user group. 


Key: **LimitToUser**
 
Value: a string containing a specified user account's short name

*Note: This is a string value.*

Description: Limits the usage of **Privileges.app** to the given user account. 

*Note: If used with a client management system that supports variables in configuration profiles, variables like `$USERNAME` may be used here.*




Key: **ReasonRequired**
 
Value: `true` or `false`

*Note: This is a boolean value.*

Accompanying Key: **ReasonMinLength**

Value: **Integer**


Description: If `ReasonRequired` is set to `true`, the user must provide a reason for needing admin rights. 

If using `ReasonRequired`, then the `ReasonMinLength` key must also be set. The `ReasonMinLength` key specifies the minimum number of characters the user has to enter as the reason for becoming an admin. If not set, the value defaults to 10. The text field is limited to amaximum of 100 characters, so values greater than 100 have no effect.

*Note: If setting `ReasonRequired`, the `Toggle Privilges` option is automatically disabled.*



Key: **RemoteLogging**
 
Value: A dictionary array containing the relevant server information


Accompanying Key: **ServerType**

Value: a string specifying the type of the logging server

*Note: This is a string value. As of now, `syslog` is the only supported value. Others may be supported in future releases.*

Accompanying Key: **ServerAddress**

Value: a string specifying the address of the logging server

*Note: This is a string value. This will usually be an IP address, unless the syslog server is set up to respond using a DNS hostname.*

Accompanying Key: **ServerPort**

Value: **Integer**

*Note: This is an integer specifying the port of the logging server. By default, port 514 is used.*


Accompanying Key: **EnableTCP**

Value: `true` or `false`

*Note: This is a boolean value. If set to true, the log messages are sent via TCP instead of UDP. By default, messages are sent via UDP.*

Accompanying Key: **EnableTCP**

Value: `true` or `false`

*Note: This is a boolean value. If set to true, the log messages are sent via TCP instead of UDP. By default, messages are sent via UDP.*

Accompanying Key: **SyslogOptions**

Value: a dictionary containing syslog-specific options.

Please see [https://tools.ietf.org/html/rfc5424#section-6.1 ](https://tools.ietf.org/html/rfc5424#section-6.1 )
for further information on the options used in the `SyslogOptions` key.

```
key: LogFacility
value: an integer specifying the syslog facility

key: LogSeverity
value: an integer specifying the syslog severity

If not specified, facility defaults to 4 (security) and severity defaults to 6 (informational). Please see https://tools.ietf.org/html/rfc5424#section-6.2.1 for further information.

key: MaximumMessageSize
value: an integer specifying the maximum size of the  syslog message (header + event message)

If not specified, the value defaults to 480 which is the 
minimum maximum message size a syslog server must support.
If the syslog message is larger than the specified maximum,
the message will be truncated at the end.
```







Description: If `RemoteLogging` is used, this will send the logging for **Privileges.app** to a remote syslog server. 

If using `RemoteLogging`, then the following subsidiary keys must also be set:

* `ServerType`
* `ServerAddress`
* `ServerPort`
* `EnableTCP`
* `SyslogOptions`
* `LogFacility`
* `LogSeverity`
* `MaximumMessageSize`



Key: **RequireAuthentication**
 
Value: a string containing a specified user account's short name

Value: `true` or `false`

*Note: This is a boolean value.*

Description: Requires authentication before using  **Privileges.app**. If set to `true`, the logged-in user is prompted to authenticate via Touch ID or by entering their account password. 




Example configuration profiles are available via the links below:

* [Privileges DockToggleTimeout macOS Configuration Profile](example_profiles/DockToggleTimeout/Example_DockToggleTimeout.mobileconfig)
* [Privileges EnforcePrivileges macOS Configuration Profile](example_profiles/EnforcePrivileges/Example_EnforcePrivileges.mobileconfig)
* [Privileges LimitToGroup macOS Configuration Profile](example_profiles/LimitToGroup/Example_LimitToGroup.mobileconfig)
* [Privileges LimitToUser macOS Configuration Profile](example_profiles/LimitToUser/Example_LimitToUser.mobileconfig)
* [Privileges ReasonRequired macOS Configuration Profile](example_profiles/ReasonRequired/Example_ReasonRequired.mobileconfig)
* [Privileges RemoteLogging macOS Configuration Profile](example_profiles/RemoteLogging/Example_RemoteLogging.mobileconfig)
* [Privileges RequireAuthentication macOS Configuration Profile](example_profiles/RequireAuthentication/Example_RequireAuthentication.mobileconfig)


Dock Icon
===================================

The **Privileges.app** dock icon will change colors from the standard color scheme if **Privileges.app** is being managed by a macOS configuration profile which is using one or more of the following management keys:

* **EnforcePrivileges**
* **LimitToGroup**
* **LimitToUser**
* **ReasonRequired**
* **RemoteLogging**
* **RequireAuthentication**

*Note: The `DockToggleTimeout` management key does not trigger the custom color scheme.*


The icon is black with a green outline and displays a locked padlock icon when you are a standard user.

![](readme_images/icon_bk1.png)

The icon is black with a yellow outline and displays an unlocked padlock icon when you are an administrator.

![](readme_images/icon_bk2.png)

This color change will not occur if only the **DockToggleTimeout** key is being managed. This color change is specific to **Privileges.app** and the **PrivilegesCLI** command line tool being managed by the **EnforcePrivileges** key.

Support
===================================
This project is 'as-is' with no support, no changes being made.  You are welcome to make changes to improve it but we are not available for questions or support of any kind.
