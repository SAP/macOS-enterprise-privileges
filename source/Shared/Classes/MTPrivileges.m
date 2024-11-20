/*
    MTPrivileges.m
    Copyright 2024 SAP SE
     
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

- (BOOL)useIsRestrictedForUser:(MTPrivilegesUser*)privilegesUser
{
    NSString *enforcedPrivileges = ([_userDefaults objectIsForcedForKey:kMTDefaultsEnforcePrivilegesKey]) ? [_userDefaults objectForKey:kMTDefaultsEnforcePrivilegesKey] : nil;
    id limitToUser = ([_userDefaults objectIsForcedForKey:kMTDefaultsLimitToUserKey]) ? [_userDefaults objectForKey:kMTDefaultsLimitToUserKey] : nil;
    id limitToGroup = ([_userDefaults objectIsForcedForKey:kMTDefaultsLimitToGroupKey]) ? [_userDefaults objectForKey:kMTDefaultsLimitToGroupKey] : nil;
    
    BOOL userRestricted = YES;
    BOOL groupRestricted = YES;
    
    if (limitToUser) {
        
        if ([limitToUser isKindOfClass:[NSString class]]) {
            
            userRestricted = ([limitToUser caseInsensitiveCompare:[privilegesUser userName]] != NSOrderedSame);
            
        } else if ([limitToUser isKindOfClass:[NSArray class]]) {
            
            for (NSString *userName in limitToUser) {
                
                if ([userName caseInsensitiveCompare:[privilegesUser userName]] == NSOrderedSame) {
                    userRestricted = NO;
                    break;
                }
            }
        }
    }
    
    if (limitToGroup) {
        
        if ([limitToGroup isKindOfClass:[NSString class]]) {
            
            groupRestricted = ![MTIdentity getGroupMembershipForUser:[privilegesUser userName] groupName:limitToGroup error:nil];
            
        } else if ([limitToGroup isKindOfClass:[NSArray class]]) {
            
            for (NSString *groupName in limitToGroup) {
                
                if ([MTIdentity getGroupMembershipForUser:[privilegesUser userName] groupName:groupName error:nil]) {
                    groupRestricted = NO;
                    break;
                }
            }
        }
    }
    
    BOOL isRestricted = (
                         [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeNone] ||
                         [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeAdmin] ||
                         [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeUser] ||
                         (limitToUser && userRestricted) ||
                         (!limitToUser && limitToGroup && groupRestricted)
                         );
    
    return isRestricted;
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
    BOOL remove = YES;
    
    if ([_userDefaults objectForKey:kMTDefaultsRevokeAtLoginKey]) {
        
        remove = [_userDefaults boolForKey:kMTDefaultsRevokeAtLoginKey];
        
    // if we got no value back, we try to get the value from our app group defaults
    } else {
        
        NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        if ([appGroupDefaults objectForKey:kMTDefaultsRevokeAtLoginKey]) {
            remove = [appGroupDefaults boolForKey:kMTDefaultsRevokeAtLoginKey];
        }
    }
    
    return remove;
}

- (BOOL)allowCLIBiometricAuthentication
{
    return ([_userDefaults boolForKey:kMTDefaultsAuthCLIBiometricsAllowedKey]);
}

- (void)setPrivilegesShouldBeRevokedAtLogin:(BOOL)revoke
{
    NSUserDefaults *appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    [appGroupDefaults setBool:revoke forKey:kMTDefaultsRevokeAtLoginKey];
}

- (BOOL)privilegesShouldBeRevokedAtLoginIsForced
{
    return ([_userDefaults objectIsForcedForKey:kMTDefaultsRevokeAtLoginKey]);
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
    return [_userDefaults objectForKey:kMTDefaultsRemoteLoggingKey];
}

- (BOOL)runActionAfterGrantOnly
{
    BOOL grantOnly = YES;
    
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

@end
