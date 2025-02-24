/*
    Constants.h
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

#define kMTAppName                              @"Privileges"
#define kMTDaemonMachServiceName                @"corp.sap.privileges.daemon.xpc"
#define kMTAgentMachServiceName                 @"corp.sap.privileges.agent.xpc"
#define kMTXPCServiceName                       @"corp.sap.privileges.xpcservice"
#define kMTAppBundleIdentifier                  @"corp.sap.privileges"
#define kMTAuthRightName                        "corp.sap.privileges.auth"
#define kMTAppGroupIdentifier                   @"7R5ZEU67FQ.corp.sap.privileges"
#define kMTDockTilePluginBundleIdentifier       @"corp.sap.privileges.docktileplugin"
#define kMTErrorDomain                          @"corp.sap.privileges.ErrorDomain"
#define kMTWebhookEventTypeGranted              @"corp.sap.privileges.granted"
#define kMTWebhookEventTypeRevoked              @"corp.sap.privileges.revoked"
#define kMTGitHubURL                            @"https://github.com/SAP/macOS-enterprise-privileges"

#define kMTAdminGroupID                         80
#define kMTExpirationDefault                    20
#define kMTReasonMinLengthDefault               10
#define kMTReasonMaxLengthDefault               250
#define kMTFixedExpirationIntervals             @[@0, @5, @10, @20, @30, @60]
#define kMTRevokeAtLoginThreshold               60

#define kMTEnforcedPrivilegeTypeNone            @"none"
#define kMTEnforcedPrivilegeTypeAdmin           @"admin"
#define kMTEnforcedPrivilegeTypeUser            @"user"

#define kMTRemoteLoggingServerTypeSyslog        @"syslog"
#define kMTRemoteLoggingServerTypeWebhook       @"webhook"

// NSUserDefaults
#define kMTDefaultsExpirationIntervalKey            @"ExpirationInterval"
#define kMTDefaultsAutoExpirationIntervalMaxKey     @"ExpirationIntervalMax"
#define kMTDefaultsEnforcePrivilegesKey             @"EnforcePrivileges"
#define kMTDefaultsAuthRequiredKey                  @"RequireAuthentication"
#define kMTDefaultsAuthCLIBiometricsAllowedKey      @"AllowCLIBiometricAuthentication"
#define kMTDefaultsLimitToUserKey                   @"LimitToUser"
#define kMTDefaultsLimitToGroupKey                  @"LimitToGroup"
#define kMTDefaultsRequireReasonKey                 @"ReasonRequired"
#define kMTDefaultsReasonMinLengthKey               @"ReasonMinLength"
#define kMTDefaultsReasonMaxLengthKey               @"ReasonMaxLength"
#define kMTDefaultsReasonPresetsKey                 @"ReasonPresetList"
#define kMTDefaultsReasonCheckingEnabledKey         @"ReasonCheckingEnabled"
#define kMTDefaultsRemoteLoggingKey                 @"RemoteLogging"
#define kMTDefaultsRemoteLoggingServerTypeKey       @"ServerType"
#define kMTDefaultsRemoteLoggingServerAddressKey    @"ServerAddress"
#define kMTDefaultsRemoteLoggingSyslogOptionsKey    @"SyslogOptions"
#define kMTDefaultsRemoteLoggingSyslogServerPortKey @"ServerPort"
#define kMTDefaultsRemoteLoggingSyslogUseTLSKey     @"UseTLS"
#define kMTDefaultsRemoteLoggingSyslogFacilityKey   @"LogFacility"
#define kMTDefaultsRemoteLoggingSyslogSeverityKey   @"LogSeverity"
#define kMTDefaultsRemoteLoggingSyslogMaxSizeKey    @"MaximumMessageSize"
#define kMTDefaultsRemoteLoggingWebhookDataKey      @"WebhookCustomData"
#define kMTDefaultsHideOtherWindowsKey              @"HideOtherWindows"
#define kMTDefaultsRevokeAtLoginKey                 @"RevokePrivilegesAtLogin"
#define kMTDefaultsRevokeAtLoginExcludedUsersKey    @"RevokeAtLoginExcludedUsers"
#define kMTDefaultsPostChangeExecutablePathKey      @"PostChangeExecutablePath"
#define kMTDefaultsPostChangeActionOnGrantOnlyKey   @"PostChangeActionOnGrantOnly"
#define kMTDefaultsAgentTimerExpirationKey          @"TimerExpires"
#define kMTDefaultsUnhideOtherWindowsKey            @"UnhideOtherWindows"
#define kMTDefaultsHideSettingsButtonKey            @"HideSettingsButton"
#define kMTDefaultsHideSettingsFromDockMenuKey      @"HideSettingsFromDockMenu"
#define kMTDefaultsHideSettingsFromStatusItemKey    @"HideSettingsFromStatusItem"
#define kMTDefaultsAllowPrivilegeRenewalKey         @"AllowPrivilegeRenewal"
#define kMTDefaultsRenewalFollowsAuthSettingKey     @"RenewalFollowsAuthSetting"
#define kMTDefaultsHideHelpButtonKey                @"HideHelpButton"
#define kMTDefaultsHelpButtonCustomURLKey           @"HelpButtonCustomURL"
#define kMTDefaultsPassReasonToExecutableKey        @"PassReasonToExecutable"
#define kMTDefaultsShowInMenuBarKey                 @"ShowInMenuBar"
#define kMTDefaultsSettingsSelectedTabKey           @"SettingsSelectedTab"
#define kMTDefaultsEnableSmartCardSupportKey        @"EnableSmartCardSupport"

// NSNotification
#define kMTNotificationNamePrivilegesDidChange  @"corp.sap.privileges.PrivilegesDidChange"
#define kMTNotificationNameExpirationTimeLeft   @"corp.sap.privileges.ExpirationTimeLeft"
#define kMTNotificationNameConfigDidChange      @"corp.sap.privileges.ConfigDidChange"
#define kMTNotificationCategoryIdentifier       @"corp.sap.privileges.action"
#define kMTNotificationActionIdentifierRenew    @"corp.sap.privileges.action.renew"

// NSNotification user info keys
#define kMTNotificationKeyTimeLeft              @"TimeLeft"
#define kMTNotificationKeyPreferencesChanged    @"PreferenceKey"
