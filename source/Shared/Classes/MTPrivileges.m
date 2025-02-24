/*
    MTPrivileges.m
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

#import "MTPrivileges.h"
#import "Constants.h"

@interface MTPrivileges ()
@property (nonatomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (nonatomic, strong, readwrite) MTPrivilegesUser *currentUser;
@end

@implementation MTPrivileges

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kMTAppBundleIdentifier]) {
            _userDefaults = [NSUserDefaults standardUserDefaults];
        } else {
            _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppBundleIdentifier];
        }
                
        _currentUser = [[MTPrivilegesUser alloc] init];
    }
    
    return self;
}

- (NSString*)enforcedPrivilegeType
{
    NSString *returnValue = nil;
    NSString *enforcedPrivileges = ([_userDefaults objectIsForcedForKey:kMTDefaultsEnforcePrivilegesKey]) ? [_userDefaults objectForKey:kMTDefaultsEnforcePrivilegesKey] : nil;
    
    if ([enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeNone] ||
        [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeAdmin] ||
        [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeUser]) {
        
        returnValue = enforcedPrivileges;
    }
    
    return returnValue;
}

- (BOOL)reasonRequired
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsRequireReasonKey] && [_userDefaults boolForKey:kMTDefaultsRequireReasonKey]);
}

- (NSInteger)reasonMinLength
{
    NSInteger minReasonLength = kMTReasonMinLengthDefault;
    
    if ([_userDefaults objectIsForcedForKey:kMTDefaultsReasonMinLengthKey]) { minReasonLength = [_userDefaults integerForKey:kMTDefaultsReasonMinLengthKey]; }
    if (minReasonLength < 1 || minReasonLength >= kMTReasonMaxLengthDefault) { minReasonLength = kMTReasonMinLengthDefault; }
        
    return minReasonLength;
}

- (NSInteger)reasonMaxLength
{
    NSInteger maxReasonLength = kMTReasonMaxLengthDefault;
    
    if ([_userDefaults objectIsForcedForKey:kMTDefaultsReasonMaxLengthKey]) { maxReasonLength = [_userDefaults integerForKey:kMTDefaultsReasonMaxLengthKey]; }
    if (maxReasonLength <= [self reasonMinLength] || maxReasonLength > kMTReasonMaxLengthDefault) { maxReasonLength = kMTReasonMaxLengthDefault; }
    
    return maxReasonLength;
}

- (NSArray *)predefinedReasons
{
    return [_userDefaults arrayForKey:kMTDefaultsReasonPresetsKey];
}

- (BOOL)reasonCheckingEnabled
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsReasonCheckingEnabledKey] && [_userDefaults boolForKey:kMTDefaultsReasonCheckingEnabledKey]);
}

- (BOOL)checkReasonString:(NSString *)reasonString
{
    __block BOOL success = NO;
    
    if ([reasonString length] > 0) {
        
        if ([reasonString length] >= [self reasonMinLength]) {
            
            if ([self reasonCheckingEnabled]) {
                
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                
                NSSpellChecker *spellChecker = [NSSpellChecker sharedSpellChecker];
                [spellChecker setAutomaticallyIdentifiesLanguages:YES];
                [spellChecker requestCheckingOfString:reasonString
                                                range:NSMakeRange(0, [reasonString length])
                                                types:NSTextCheckingTypeOrthography
                                              options:nil
                               inSpellDocumentWithTag:0
                                    completionHandler:^(NSInteger sequenceNumber, NSArray *results, NSOrthography *orthography, NSInteger wordCount) {
                    
                    success = ([[orthography dominantLanguage] isEqualToString:@"und"]) ? NO : YES;
                    dispatch_semaphore_signal(semaphore);
                }];
                
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                
            } else {
                
                success = YES;
            }
        }
    }
    
    return success;
}

- (NSString*)cleanedReasonStringWithString:(NSString *)reasonString
{
    NSString *cleanedReasonString = nil;
    
    if ([reasonString length] > 0) {
        
        // remove subsequent spaces
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s{2,}"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil
        ];
        cleanedReasonString = [regex stringByReplacingMatchesInString:reasonString
                                                              options:0
                                                                range:NSMakeRange(0, [reasonString length])
                                                         withTemplate:@" "
        ];
    }
    
    return cleanedReasonString;
}

- (NSInteger)expirationInterval
{
    NSInteger returnValue = kMTExpirationDefault;
    NSInteger interval = -1;
    
    if ([_userDefaults objectForKey:kMTDefaultsExpirationIntervalKey]) {
        
        interval = [_userDefaults integerForKey:kMTDefaultsExpirationIntervalKey];

    // if we got no value back, we try to get the value from our app group defaults
    } else {
        
        NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        
        if ([appGroupDefaults objectForKey:kMTDefaultsExpirationIntervalKey]) {
            
            interval = [appGroupDefaults integerForKey:kMTDefaultsExpirationIntervalKey];
            
        } else {
                
            // Because our Dock Tile plugin cannot access our group container we also
            // check ~/Library/Preferences/corp.sap.privileges.docktileplugin which the
            // Dock Tile plugin can read. This is the only app setting the Dock needs
            // access to.
            NSUserDefaults *privilegesSharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTDockTilePluginBundleIdentifier];
            
            if ([privilegesSharedDefaults objectForKey:kMTDefaultsExpirationIntervalKey]) {

                interval = [privilegesSharedDefaults integerForKey:kMTDefaultsExpirationIntervalKey];
            }
        }
    }
    
    if (interval >= 0) {

        NSInteger intervalMax = [self expirationIntervalMax];
        if (intervalMax > 0 && interval > intervalMax) { interval = intervalMax; }
        returnValue = interval;
    }
        
    return returnValue;
}

- (void)setExpirationInterval:(NSUInteger)interval
{
    NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    [appGroupDefaults setInteger:interval forKey:kMTDefaultsExpirationIntervalKey];
    
    // Because our Dock Tile plugin can't access our group container, and
    // because of a bug in macOS 15, it can't access the application's
    // container directory either, the application needs a sandbox exception to
    // write values to ~/Library/Preferences/corp.sap.privileges.docktileplugin,
    // which the Dock Tile plugin can then read.
    NSUserDefaults *privilegesSharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTDockTilePluginBundleIdentifier];
    [privilegesSharedDefaults setInteger:interval forKey:kMTDefaultsExpirationIntervalKey];
}

- (NSInteger)expirationIntervalMax
{
    NSInteger returnValue = -1;
    
    if ([_userDefaults objectForKey:kMTDefaultsAutoExpirationIntervalMaxKey]) {
        returnValue = [_userDefaults integerForKey:kMTDefaultsAutoExpirationIntervalMaxKey];
    }
    
    return returnValue;
}

- (BOOL)expirationIntervalIsForced;
{
    return [_userDefaults objectIsForcedForKey:kMTDefaultsExpirationIntervalKey];
}

- (BOOL)expirationIntervalMaxIsForced
{
    return [_userDefaults objectIsForcedForKey:kMTDefaultsAutoExpirationIntervalMaxKey];
}

- (BOOL)authenticationRequired
{
    return ([_userDefaults boolForKey:kMTDefaultsAuthRequiredKey]);
}

- (BOOL)privilegesShouldBeRevokedAtLogin
{
    BOOL remove = NO;
    
    if ([_userDefaults objectForKey:kMTDefaultsRevokeAtLoginKey]) {
        
        remove = [_userDefaults boolForKey:kMTDefaultsRevokeAtLoginKey];
        
    // if we got no value back, we try to get the value from our app group defaults
    } else {
        
        NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        remove = [appGroupDefaults boolForKey:kMTDefaultsRevokeAtLoginKey];
    }

    return (remove && ![[self currentUser] isExcludedFromRevokeAtLogin]);
}

- (BOOL)allowCLIBiometricAuthentication
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsAuthCLIBiometricsAllowedKey] && [_userDefaults boolForKey:kMTDefaultsAuthCLIBiometricsAllowedKey]);
}

- (void)setPrivilegesShouldBeRevokedAtLogin:(BOOL)revoke
{
    NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    [appGroupDefaults setBool:revoke forKey:kMTDefaultsRevokeAtLoginKey];
}

- (BOOL)privilegesShouldBeRevokedAtLoginIsForced
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsRevokeAtLoginKey] || [[self currentUser] isExcludedFromRevokeAtLogin]);
}

- (BOOL)hideOtherWindows
{
    BOOL hide = YES;
    
    if ([_userDefaults objectForKey:kMTDefaultsHideOtherWindowsKey]) {
        hide = [_userDefaults boolForKey:kMTDefaultsHideOtherWindowsKey];
    }
    
    return hide;
}

- (void)setHideOtherWindows:(BOOL)hide
{
    if (hide) {
        [_userDefaults removeObjectForKey:kMTDefaultsHideOtherWindowsKey];
    } else {
        [_userDefaults setBool:NO forKey:kMTDefaultsHideOtherWindowsKey];
    }
}

- (BOOL)hideOtherWindowsIsForced
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsHideOtherWindowsKey]);
}

- (NSString*)postChangeExecutablePath
{
    NSString *executablePath = nil;
    
    if ([_userDefaults objectForKey:kMTDefaultsPostChangeExecutablePathKey]) {
        
        executablePath = [_userDefaults stringForKey:kMTDefaultsPostChangeExecutablePathKey];
        
    // if we got no value back, we try to get the value from our app group defaults
    } else {
        
        NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        executablePath = [appGroupDefaults stringForKey:kMTDefaultsPostChangeExecutablePathKey];
    }
        
    return ([executablePath length] > 0) ? executablePath : nil;
}

- (BOOL)postChangeExecutablePathIsForced
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsPostChangeExecutablePathKey]);
}

- (void)setPostChangeExecutablePath:(NSString*)path
{
    NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    [appGroupDefaults setObject:path forKey:kMTDefaultsPostChangeExecutablePathKey];
}

- (NSDictionary*)remoteLoggingConfiguration
{
    return [_userDefaults dictionaryForKey:kMTDefaultsRemoteLoggingKey];
}

- (BOOL)runActionAfterGrantOnly
{
    BOOL grantOnly = NO;
    
    if ([_userDefaults objectForKey:kMTDefaultsPostChangeActionOnGrantOnlyKey]) {
        
        grantOnly = [_userDefaults boolForKey:kMTDefaultsPostChangeActionOnGrantOnlyKey];
        
    // if we got no value back, we try to get the value from our app group defaults
    } else {
        
        NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        grantOnly = [appGroupDefaults boolForKey:kMTDefaultsPostChangeActionOnGrantOnlyKey];
    }
    
    return grantOnly;
}

- (BOOL)runActionAfterGrantOnlyIsForced
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsPostChangeActionOnGrantOnlyKey]);
}

- (void)setRunActionAfterGrantOnly:(BOOL)grantOnly
{
    NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    [appGroupDefaults setBool:grantOnly forKey:kMTDefaultsPostChangeActionOnGrantOnlyKey];
}

- (BOOL)hideSettingsButton
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsHideSettingsButtonKey] && [_userDefaults boolForKey:kMTDefaultsHideSettingsButtonKey]);
}

- (BOOL)hideSettingsFromDockMenu
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsHideSettingsFromDockMenuKey] && [_userDefaults boolForKey:kMTDefaultsHideSettingsFromDockMenuKey]);
}

- (BOOL)hideSettingsFromStatusItem
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsHideSettingsFromStatusItemKey] && [_userDefaults boolForKey:kMTDefaultsHideSettingsFromStatusItemKey]);
}

- (BOOL)privilegeRenewalAllowed
{
    BOOL allow = NO;
    
    if ([_userDefaults objectForKey:kMTDefaultsAllowPrivilegeRenewalKey]) {

        allow = [_userDefaults boolForKey:kMTDefaultsAllowPrivilegeRenewalKey];
        
    // if we got no value back, we try to get the value from our app group defaults
    } else {

        NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        
        if ([appGroupDefaults objectForKey:kMTDefaultsAllowPrivilegeRenewalKey]) {
            
            allow = [appGroupDefaults boolForKey:kMTDefaultsAllowPrivilegeRenewalKey];
            
        } else {
            
            // Because our Dock Tile plugin cannot access our group container we also
            // check ~/Library/Preferences/corp.sap.privileges.docktileplugin which the
            // Dock Tile plugin can read. This is the only app setting the Dock needs
            // access to.
            NSUserDefaults *privilegesSharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTDockTilePluginBundleIdentifier];
            
            if ([privilegesSharedDefaults objectForKey:kMTDefaultsAllowPrivilegeRenewalKey]) {

                allow = [privilegesSharedDefaults boolForKey:kMTDefaultsAllowPrivilegeRenewalKey];
            }
        }
    }
    
    return allow;
}

- (BOOL)privilegeRenewalAllowedIsForced
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsAllowPrivilegeRenewalKey]);
}

- (void)setPrivilegeRenewalAllowed:(BOOL)isAllowed
{
    NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    [appGroupDefaults setBool:isAllowed forKey:kMTDefaultsAllowPrivilegeRenewalKey];
    
    // Because our Dock Tile plugin can't access our group container, and
    // because of a bug in macOS 15, it can't access the application's
    // container directory either, the application needs a sandbox exception to
    // write values to ~/Library/Preferences/corp.sap.privileges.docktileplugin,
    // which the Dock Tile plugin can then read.
    NSUserDefaults *privilegesSharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTDockTilePluginBundleIdentifier];
    [privilegesSharedDefaults setBool:isAllowed forKey:kMTDefaultsAllowPrivilegeRenewalKey];
}

- (BOOL)hideHelpButton
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsHideHelpButtonKey] && [_userDefaults boolForKey:kMTDefaultsHideHelpButtonKey]);
}

- (NSURL*)helpButtonURL
{
    NSURL *helpURL = nil;
    
    if ([_userDefaults objectIsForcedForKey:kMTDefaultsHelpButtonCustomURLKey]) {
        
        NSString *urlString = [_userDefaults stringForKey:kMTDefaultsHelpButtonCustomURLKey];
        
        if ([urlString length] > 0) {
            
            NSURL *tmpHelpURL = [NSURL URLWithString:urlString];

            if (tmpHelpURL &&
                ([[[tmpHelpURL scheme] lowercaseString] isEqualToString:@"https"] ||
                [[[tmpHelpURL scheme] lowercaseString] isEqualToString:@"http"])) {
                helpURL = tmpHelpURL;
            }
        }
    }
    
    return helpURL;
}

- (BOOL)renewalFollowsAuthSetting
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsRenewalFollowsAuthSettingKey] && [_userDefaults boolForKey:kMTDefaultsRenewalFollowsAuthSettingKey]);
}

- (BOOL)passReasonToExecutable
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsPassReasonToExecutableKey] && [_userDefaults boolForKey:kMTDefaultsPassReasonToExecutableKey]);
}

- (BOOL)showInMenuBar
{
    BOOL show = NO;
    
    if ([_userDefaults objectForKey:kMTDefaultsShowInMenuBarKey]) {
        
        show = [_userDefaults boolForKey:kMTDefaultsShowInMenuBarKey];
        
    // if we got no value back, we try to get the value from our app group defaults
    } else {
        
        NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        show = [appGroupDefaults boolForKey:kMTDefaultsShowInMenuBarKey];
    }
        
    return show;
}

- (BOOL)showInMenuBarIsForced
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsShowInMenuBarKey]);
}

- (void)setShowInMenuBar:(BOOL)show
{
    NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    
    if (show) {
        [appGroupDefaults setBool:YES forKey:kMTDefaultsShowInMenuBarKey];
    } else {
        [appGroupDefaults removeObjectForKey:kMTDefaultsShowInMenuBarKey];
    }
}

- (BOOL)smartCardSupportEnabled
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsEnableSmartCardSupportKey] && [_userDefaults boolForKey:kMTDefaultsEnableSmartCardSupportKey]);
}

+ (NSString *)stringForDuration:(double)duration localized:(BOOL)localized naturalScale:(BOOL)naturalScale
{
    NSMeasurement *durationMeasurement = [[NSMeasurement alloc] initWithDoubleValue:duration
                                                                               unit:[NSUnitDuration minutes]
    ];
    NSMeasurementFormatter *durationFormatter = [[NSMeasurementFormatter alloc] init];
    [[durationFormatter numberFormatter] setMaximumFractionDigits:0];
    if (!localized) { [durationFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]]; }
    [durationFormatter setUnitStyle:NSFormattingUnitStyleLong];
    
    if (naturalScale) {
        [durationFormatter setUnitOptions:NSMeasurementFormatterUnitOptionsNaturalScale];
    } else {
        [durationFormatter setUnitOptions:NSMeasurementFormatterUnitOptionsProvidedUnit];
    }
    
    return [durationFormatter stringFromMeasurement:durationMeasurement];
}

@end
