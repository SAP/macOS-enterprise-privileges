/*
    MTPrivileges.h
    Copyright 2016-2025 SAP SE
     
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
     
    http://www.apache.org/licenses/LICENSE-2.0
     
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

#import <Foundation/Foundation.h>
#import "MTPrivilegesUser.h"

/*!
 @class         MTPrivileges
 @abstract      This class provides methods for handling Privileges settings.
 */

@interface MTPrivileges : NSObject

/*!
 @property      currentUser
 @abstract      Returns the MTPrivilegesUser object for the current user.
 @discussion    The value of this property is MTPrivilegesUser.
*/
@property (nonatomic, strong, readonly) MTPrivilegesUser *currentUser;

/*!
 @property      userDefaults
 @abstract      Returns the Privilges user defaults regardless of which application is accessing them.
 @discussion    The value of this property is NSUserDefaults.
*/
@property (nonatomic, strong, readonly) NSUserDefaults *userDefaults;

/*!
 @method        enforcedPrivilegeType
 @abstract      Get the type of the enforced privileges.
 @discussion    Returns "none" if the app has been completely locked, "admin" if the app has been locked to
                admin privileges, or "user" if the app has been locked to standard user privileges. Retruns nil
                if nothing has been enforced.
 */
- (NSString*)enforcedPrivilegeType;

/*!
 @method        reasonRequired
 @abstract      Get whether the user must provide a reason to get admin rights.
 @discussion    Returns YES if a reason must be provided, otherwise returns NO.
 */
- (BOOL)reasonRequired;

/*!
 @method        reasonMinLength
 @abstract      Get the minimum number of characters that must be entered for a reason.
 @discussion    Returns the configured length or kMTReasonMinLengthDefault, if no minimum lenght has been configured.
 */
- (NSInteger)reasonMinLength;

/*!
 @method        reasonMaxLength
 @abstract      Get the maximum number of characters that can be entered for a reason.
 @discussion    Returns the configured length or kMTReasonMaxLengthDefault, if no maximum lenght has been configured.
 */
- (NSInteger)reasonMaxLength;

/*!
 @method        predefinedReasons
 @abstract      Get the predefined reasons.
 @discussion    Returns an array of dictionaries where each dictionary represents a reason.
 */
- (NSArray*)predefinedReasons;

/*!
 @method        reasonCheckingEnabled
 @abstract      Get whether the reason the user entered should be checked for valid text.
 @discussion    Returns YES if checking is enabled, otherwise returns NO.
 */
- (BOOL)reasonCheckingEnabled;

/*!
 @method        checkReasonString:
 @abstract      Get whether the reason the user entered matches the requirements.
 @param         reasonString The string to be checked.
 @discussion    Returns YES if the check succeeded, otherwise returns NO.
 */
- (BOOL)checkReasonString:(NSString*)reasonString;

/*!
 @method        cleanedReasonStringWithString:
 @abstract      Get a cleaned reason string from the given string.
 @param         reasonString The string to be cleaned.
 @discussion    Returns a string with subsequent whitespace characters removed or nil if an error occurred.
 */
- (NSString*)cleanedReasonStringWithString:(NSString *)reasonString;

/*!
 @method        expirationInterval
 @abstract      Get the current expiration interval.
 @discussion    Returns an integer representing the expiration interval in minutes or -1 if an error occurred.
 */
- (NSInteger)expirationInterval;

/*!
 @method        setExpirationInterval:
 @abstract      Set the expiration interval.
 @param         interval A positive integer specifying the expiration interval in minutes.
 */
- (void)setExpirationInterval:(NSUInteger)interval;

/*!
 @method        expirationIntervalMax
 @abstract      Get the maximum possible expiration interval.
 @discussion    Returns an integer representing the maximum expiration interval in minutes or -1 if there's no
                maximum expiration interval configured.
 */
- (NSInteger)expirationIntervalMax;

/*!
 @method        expirationIntervalIsForced
 @abstract      Get whether the expiration interval has been forced.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)expirationIntervalIsForced;

/*!
 @method        expirationIntervalMaxIsForced
 @abstract      Get whether the maximum expiration interval has been forced.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)expirationIntervalMaxIsForced;

/*!
 @method        authenticationRequired
 @abstract      Get whether the user must authenticate to get admin rights.
 @discussion    Returns YES if authentication is required, otherwise returns NO.
 */
- (BOOL)authenticationRequired;

/*!
 @method        allowCLIBiometricAuthentication
 @abstract      Get whether the biometric authentication is allowed for the command-line tool.
 @discussion    Returns YES if biometric authentication is allowed, otherwise returns NO.
 */
- (BOOL)allowCLIBiometricAuthentication;

/*!
 @method        privilegesShouldBeRevokedAtLogin
 @abstract      Get whether admin privileges should be revoked at login.
 @discussion    Returns YES if admin privileges should be revoked at login, otherwise returns NO.
 */
- (BOOL)privilegesShouldBeRevokedAtLogin;

/*!
 @method        privilegesShouldBeRevokedAtLoginIsForced
 @abstract      Get whether the privilege removal at login has been forced.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)privilegesShouldBeRevokedAtLoginIsForced;

/*!
 @method        setPrivilegesShouldBeRevokedAtLogin:
 @abstract      Set whether admin privileges should be revoked at login.
 @param         revoke A boolean indicating if administrator privileges should be removed at login (YES) or not (NO).
 */
- (void)setPrivilegesShouldBeRevokedAtLogin:(BOOL)revoke;

/*!
 @method        hideOtherWindows
 @abstract      Get whether all other windows than the Privileges window should be hided after launching Privileges.
 @discussion    Returns YES if Privileges should hide windows of other applications, otherwise returns NO.
 */
- (BOOL)hideOtherWindows;

/*!
 @method        setHideOtherWindows:
 @abstract      Set whether all other windows than the Privileges window should be hided after launching Privileges.
 @param         hide A boolean indicating if Privileges should hide windows of other applications (YES) or not (NO).
 */
- (void)setHideOtherWindows:(BOOL)hide;

/*!
 @method        hideOtherWindowsIsForced
 @abstract      Get whether setting for hiding other application's windows has been forced.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)hideOtherWindowsIsForced;

/*!
 @method        postChangeExecutablePath
 @abstract      Get the path to the executable that should be launched after privileges changed.
 @discussion    Returns the path to the executable or nil if not configured.
 */
- (NSString*)postChangeExecutablePath;

/*!
 @method        postChangeExecutablePathIsForced
 @abstract      Get whether the post-change executable path has been forced.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)postChangeExecutablePathIsForced;

/*!
 @method        setPostChangeExecutablePath:
 @abstract      Set the post-change executable path.
 @param         path The path to the executable that should be launched after privileges changed.
 */
- (void)setPostChangeExecutablePath:(NSString*)path;

/*!
 @method        runActionAfterGrantOnly
 @abstract      Get whether the post-change action should only run after a user got administrator privileges.
 @discussion    Returns YES if the post-change action should only run after a user got administrator privileges,
                or NO if the post-change action runs whenever privileges changed.
 */
- (BOOL)runActionAfterGrantOnly;

/*!
 @method        runActionAfterGrantOnlyIsForced
 @abstract      Get whether the Run action is forced to run only after administrator privileges are granted.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)runActionAfterGrantOnlyIsForced;

/*!
 @method        setRunActionAfterGrantOnly:
 @abstract      Set if the post-change action should only run after a user got administrator privileges.
 @param         grantOnly A boolean indicating if the post-change action should only run after a user got
                administrator privileges (YES) or if the post-change action runs whenever privileges changed (NO).
 */
- (void)setRunActionAfterGrantOnly:(BOOL)grantOnly;

/*!
 @method        remoteLoggingConfiguration
 @abstract      Get the remote logging configuration.
 @discussion    Returns a dictionary containing the remote logging configuration or nil if remote logging is not configured.
                For valid remote logging configuration keys, see the Privileges.mobileconfig file located in the Resources
                folder of the Privilege app bundle.
 */
- (NSDictionary*)remoteLoggingConfiguration;

/*!
 @method        hideSettingsButton
 @abstract      Get whether the app's "Settings" button should be hidden.
 @discussion    Returns YES if the settings button should be hidden, otherwise returns NO.
 */
- (BOOL)hideSettingsButton;

/*!
 @method        hideSettingsFromDockMenu
 @abstract      Get whether the Dock tile's "Settings" menu item should be hidden.
 @discussion    Returns YES if the Dock tile's "Settings" menu item should be hidden, otherwise returns NO.
 */
- (BOOL)hideSettingsFromDockMenu;

/*!
 @method        hideSettingsFromStatusItem
 @abstract      Get whether the status item's "Settings" menu item should be hidden.
 @discussion    Returns YES if the status item's "Settings" menu item should be hidden, otherwise returns NO.
 */
- (BOOL)hideSettingsFromStatusItem;

/*!
 @method        privilegeRenewalAllowed
 @abstract      Get whether the renewal of expiring administrator privileges is allowed.
 @discussion    Returns YES if the expiring administrator privileges can be renewed once,
                otherwise returns NO.
 */
- (BOOL)privilegeRenewalAllowed;

/*!
 @method        privilegeRenewalAllowedIsForced
 @abstract      Get whether the setting for the renewal of expiring administrator privileges is forced.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)privilegeRenewalAllowedIsForced;

/*!
 @method        setPrivilegeRenewalAllowed:
 @abstract      Set if the renewal of expiring administrator privileges is allowed.
 @param         isAllowed A boolean indicating if expiring administrator privileges can be renewed
                once (YES) or not (NO).
 */
- (void)setPrivilegeRenewalAllowed:(BOOL)isAllowed;

/*!
 @method        hideHelpButton
 @abstract      Get whether the app's "Help" button should be hidden.
 @discussion    Returns YES if the help button should be hidden, otherwise returns NO.
 */
- (BOOL)hideHelpButton;

/*!
 @method        helpButtonURL
 @abstract      Get the help button's custom url.
 @discussion    Returns a NSURL object or nil, if not set.
 */
- (NSURL*)helpButtonURL;

/*!
 @method        renewalFollowsAuthSetting
 @abstract      Get whether a privilege renewal uses the same authentication settings as requesting privileges.
 @discussion    Returns YES if renewals require the same kind of authentication as requesting privileges, otherwise returns NO.
 */
- (BOOL)renewalFollowsAuthSetting;

/*!
 @method        passReasonToExecutable
 @abstract      Get whether the reason that the user entered when requesting administrator privileges
                should be passed to the executable  that should be launched after privileges changed.
 @discussion    Returns YES if the reason is passed to the executable, otherwise returns NO.
 */
- (BOOL)passReasonToExecutable;

/*!
 @method        showInMenuBar
 @abstract      Get whether Privileges should be displayed in the Menu Bar.
 @discussion    Returns YES if Privileges should be displayed in the Menu Bar, otherwise returns NO.
 */
- (BOOL)showInMenuBar;

/*!
 @method        setShowInMenuBar:
 @abstract      Set whether Privileges should be displayed in the Menu Bar.
 @param         show A boolean indicating if Privileges should be displayed in the Menu Bar (YES) or not (NO).
 */
- (void)setShowInMenuBar:(BOOL)show;

/*!
 @method        showInMenuBarIsForced
 @abstract      Get whether setting for displaying Privileges in the Menu Bar has been forced.
 @discussion    Returns YES if the setting was forced by a configuration profile, otherwise returns NO.
 */
- (BOOL)showInMenuBarIsForced;

/*!
 @method        smartCardSupportEnabled
 @abstract      Get whether smart cards/PIV tokens should be used for authentication.
 @discussion    Returns YES if smart cards/PIV token should be used for authentication, otherwise returns NO.
 */
- (BOOL)smartCardSupportEnabled;

/*!
 @method        renewalCustomAction
 @abstract      Get the configuration for the custom renewal action.
 @discussion    Returns a dictionary containing the rconfiguration for the custom renewal action or nil if no custom action
                is configured. For valid configuration keys, see the Privileges.mobileconfig file located in the Resources
                folder of the Privilege app bundle.
 */
- (NSDictionary*)renewalCustomAction;

/*!
 @method        stringForDuration:localized:naturalScale:
 @abstract      Return the duration string for the given duration.
 @param         duration The duration.
 @param         localized A boolean specifying wheter the string should be localized.
 @param         naturalScale A boolean specifying if the natural scaling (seconds, hours) should be used (YES) or
                if the base unit (minutes) should be used (NO).
 */
+ (NSString*)stringForDuration:(double)duration localized:(BOOL)localized naturalScale:(BOOL)naturalScale;

@end
