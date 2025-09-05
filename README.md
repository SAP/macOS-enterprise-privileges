![](https://github.com/SAP/macOS-enterprise-privileges/blob/main/readme_images/github%20banner%20new.png)

<br/>

# Privileges

[![REUSE status](https://api.reuse.software/badge/github.com/SAP/macOS-enterprise-privileges)](https://api.reuse.software/info/github.com/SAP/macOS-enterprise-privileges)

_Privileges_ is an application for macOS which allows users to work as a standard user for day-to-day tasks, by providing a quick and easy way to request administrator rights. Users can set a timeframe in the application’s settings to perform specific tasks, such as installing or removing an application. To request admin rights, simply click on the _Privileges_ icon in your Dock. 

Working as standard user instead of an administrator adds another layer of security to your Mac and is considered a security best practice. We believe all users, including all developers, can benefit from using _Privileges_.

**Privileges supports the following macOS versions:**

* macOS 15.x
* macOS 14.x
* macOS 13.x (*)
* macOS 12.x
* macOS 11.x

<br/>

>[!NOTE]
>It seems that macOS 13 erroneously reports a launch constraint violation and immediately terminates the application. Therefore, starting with version 2.2, we are providing two versions of the application: one with launch constraints and one without. However, we recommend using the version with launch constraints whenever possible.
<br/>

# Features

🛠️ Easy install

:rocket: Perfect for day-to-day use

:alarm_clock: Turn on admin rights anytime

:closed_lock_with_key: Enjoy standard user security

:fire: Command line use supported

<br/>

## New Privileges 2 features 🔥

📦 Installer package

⛔️ Revoke admin rights at login

⏳ Unified expiration interval for administrator privileges

🔁 Renew expiring administrator privileges

🪪 Smart card support

▶️ Run actions on privilege change

🔒 Status item

👆 Command line tool now supports Touch ID

⚙️ AppleScript support

🪝 Webhooks

🔠 Localized in 41 languages

<br/>

# Demo

⚡️ Have a look at how quick and easy you can request admin rights

![](https://github.com/SAP/macOS-enterprise-privileges/blob/main/readme_images/DemoGIF.gif)

<br/>

# Application Management
As of _Privileges_ 1.5.0, it is possible to manage settings for _Privileges_ or the _PrivilegesCLI_ command line tool using a macOS configuration profile. [For details, please click here](https://github.com/SAP/macOS-enterprise-privileges/wiki/Managing-Privileges).

<br/>

# Articles

See who's talking about _Privileges_…

2025
* [Leveling Up - Managing admin rights in the enterprise - Rich Trouton's session at MacAD.UK 2025](https://youtu.be/JSnCdmV_N5U)
* [9To5Mac: Privileges 2.1 continues to be one of the must-have macOS apps in the enterprise](https://9to5mac.com/2025/03/15/privileges-2-1-continues-to-be-one-of-the-must-have-macos-apps-in-the-enterprise/)
* [Caschys Blog: Privileges 2.3.0: Mehr Sicherheit und Kontrolle für Mac-Admins (German language)](https://stadt-bremerhaven.de/privileges-2-3-0-mehr-sicherheit-und-kontrolle-fuer-mac-admins/)

2022
* [Mac & i: SAP-Werkzeug erleichtert Arbeit als Standardnutzer (German language)](https://www.heise.de/-7192631)
* [ifun.de: Privileges.app von SAP: Nur noch auf Zuruf zum Admin (German language)](https://www.ifun.de/privileges-app-von-sap-nur-noch-auf-zuruf-zum-admin-191491/)
* [Leveling Up - Rich Trouton's session at MacSysAdmin 2022](https://docs.macsysadmin.se/2022/video/day1session2.mp4)
* [The Great Debate: Admin or Standard Users? - A talk hosted by Kandji](https://youtu.be/LCj59EIKFDg)

2019
* [9To5Mac: Privileges for macOS is the open source tool that all Apple IT departments need](https://9to5mac.com/2019/11/16/privileges-app-for-macos/)

<br/>

# Documentation

📚 If you want to learn more about _Privileges_ features, make sure to take a look at our [wiki](https://github.com/SAP/macOS-enterprise-privileges/wiki) or the links below:

* [Installation](https://github.com/SAP/macOS-enterprise-privileges/wiki/Installation)
* [Uninstallation](https://github.com/SAP/macOS-enterprise-privileges/wiki/Uninstallation)
* [Using Privileges](https://github.com/SAP/macOS-enterprise-privileges/wiki/Using-Privileges)
* [Managing Privileges](https://github.com/SAP/macOS-enterprise-privileges/wiki/Managing-Privileges)
* [Frequently Asked Questions](https://github.com/SAP/macOS-enterprise-privileges/wiki/Frequently-Asked-Questions)

<br/>

# License

Copyright (c) 2018-2025 SAP SE or an SAP affiliate company and macOS-enterprise-privileges contributors. Please see our [LICENSE](LICENSE) for copyright and license information. Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/SAP/macOS-enterprise-privileges).

<br/>

# Security

>[!IMPORTANT]
>Local administrators on macOS have extensive capabilities to make changes to a Mac. This can include completely removing the _Privileges_ application. Therefore, _Privileges_ cannot guarantee that elevated permissions will be removed from the user account at all or on any specific schedule. _Privileges_ cannot undo other changes made by a user - or processes acting as the user - when that user has elevated rights. Organizations should consider this when designing their client management, device compliance, security hardening, and auditing policies.

<br/>

Found a security-related issue or vulnerability and want to notify us? [Please see here for how to report it](https://github.com/SAP/macOS-enterprise-privileges/security/policy).

<br/>

# Support

This project is 'as-is' with no support, no changes being made. You are welcome to make changes to improve it but we are not available for questions or support of any kind.
