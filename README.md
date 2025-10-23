<img src="https://github.com/SAP/macOS-enterprise-privileges/blob/main/readme_images/banner.png" width="879"><br/>

<br/>

# Privileges

[![REUSE status](https://api.reuse.software/badge/github.com/SAP/macOS-enterprise-privileges)](https://api.reuse.software/info/github.com/SAP/macOS-enterprise-privileges)

### Transparent, free, and secure admin rights management for macOS.

_Privileges_ is a free macOS application designed for modern enterprise environments. It gives users temporary administrator privileges when needed without granting permanent admin rights. The application is built with simplicity, security, and transparency in mind. Users can set a timeframe in the application's settings to perform specific tasks, such as installing or removing an application.

Using a standard user account instead of an administrator account adds an extra layer of security to your Mac and is considered a security best practice. We believe that all users, including developers, can benefit from using _Privileges_.

**_Privileges_ supports the following macOS versions:**

* macOS 26.x
* macOS 15.x
* macOS 14.x
* macOS 13.x (*)
* macOS 12.x
* macOS 11.x

<br/>

>[!NOTE]
>Unfortunately, macOS 13 incorrectly reports a launch constraint violation and immediately terminates the application. Starting with version 2.2, we are therefore providing two versions of the application: one with launch constraints and one without. However, we recommend using the version with launch constraints whenever possible.
<br/>

# Features

🛠️ Easy install

🚀 Perfect for day-to-day use

🛜 Works completely offline - no internet connection required

⏰ Turn on admin rights anytime

🔐 Enjoy standard user security

🧰 Extensive MDM support for broad device and policy control

⌨️ Command line support

<br/>

## New Privileges 2 features

⛔️ Revoke admin rights at login

⏳ Unified expiration interval for administrator privileges

🔁 Renew expiring administrator privileges at any time

🪪 Smart card and PIV token support

▶️ Run actions on privilege change

🔒 Status item for the macOS menu bar

👆 Command line tool now supports Touch ID

⚙️ AppleScript support

🪝 Webhooks

🔠 Localized in 41 languages

📦 Installer package

<br/>

# Demo

Have a look at how quick and easy you can request admin rights

https://github.com/user-attachments/assets/6cf5df95-9dce-4c21-a150-2217044fe389

<br/>

# Application Management
As of _Privileges 1.0.5_, it is possible to manage settings for _Privileges_ or the _PrivilegesCLI_ command line tool using a macOS configuration profile. [For details, please click here](https://github.com/SAP/macOS-enterprise-privileges/wiki/Managing-Privileges).

<br/>

# Articles

See who's talking about _Privileges_…

2025
* [Leveling Up - Managing admin rights in the enterprise - Rich Trouton's session at MacAD.UK 2025](https://youtu.be/JSnCdmV_N5U)
* [9To5Mac: Privileges 2.1 continues to be one of the must-have macOS apps in the enterprise](https://9to5mac.com/2025/03/15/privileges-2-1-continues-to-be-one-of-the-must-have-macos-apps-in-the-enterprise/)
* [Caschys Blog: Privileges 2.3.0: Mehr Sicherheit und Kontrolle für Mac-Admins (German language)](https://stadt-bremerhaven.de/privileges-2-3-0-mehr-sicherheit-und-kontrolle-fuer-mac-admins/)

2024
* [Der Flounder: Privileges 2.0 available with new features](https://derflounder.wordpress.com/2024/11/20/privileges-2-0-available-with-new-features)
  
2022
* [Mac & i: SAP-Werkzeug erleichtert Arbeit als Standardnutzer (German language)](https://www.heise.de/-7192631)
* [ifun.de: Privileges.app von SAP: Nur noch auf Zuruf zum Admin (German language)](https://www.ifun.de/privileges-app-von-sap-nur-noch-auf-zuruf-zum-admin-191491/)
* [Leveling Up - Rich Trouton's session at MacSysAdmin 2022](https://docs.macsysadmin.se/2022/video/day1session2.mp4)
* [The Great Debate: Admin or Standard Users? - A talk hosted by Kandji](https://youtu.be/LCj59EIKFDg)

2019
* [9To5Mac: Privileges for macOS is the open source tool that all Apple IT departments need](https://9to5mac.com/2019/11/16/privileges-app-for-macos/)

<br/>

# Documentation

To learn more about _Privileges_ features, make sure to take a look at our [wiki](https://github.com/SAP/macOS-enterprise-privileges/wiki) or the links below:

* [Installation](https://github.com/SAP/macOS-enterprise-privileges/wiki/Installation)
* [Uninstallation](https://github.com/SAP/macOS-enterprise-privileges/wiki/Uninstallation)
* [Using _Privileges_](https://github.com/SAP/macOS-enterprise-privileges/wiki/Using-Privileges)
* [Managing _Privileges_](https://github.com/SAP/macOS-enterprise-privileges/wiki/Managing-Privileges)
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
