/*
 MTAuthCommon.m
 Copyright 2016-2020 SAP SE
 
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

#import "MTAuthCommon.h"
#import "PrivilegesHelper.h"
#import "PrivilegesXPC.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation MTAuthCommon

static NSString *kCommandKeyAuthRightName = @"authRightName";
static NSString *kCommandKeyAuthRightDefault = @"authRightDefault";
static NSString *kCommandKeyAuthRightDesc = @"authRightDescription";

+ (NSDictionary*)commandInfo
{
    static dispatch_once_t sOnceToken;
    static NSDictionary *sCommandInfo;

    dispatch_once(&sOnceToken, ^{
        sCommandInfo = @{
            NSStringFromSelector(@selector(changeAdminRightsForUser:remove:reason:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"corp.sap.privileges.changeAdminRights",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleClassAllow,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(@"changeAdminRights", nil)
                                 }
                         };
    });
    
    return sCommandInfo;
}

+ (NSString *)authorizationRightForCommand:(SEL)command
{
    return [self commandInfo][NSStringFromSelector(command)][kCommandKeyAuthRightName];
}

+ (void)enumerateRightsUsingBlock:(void (^)(NSString *authRightName, id authRightDefault, NSString *authRightDesc))block
// Calls the supplied block with information about each known authorization right..
{
    [self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
#pragma unused(key)
#pragma unused(stop)
        NSDictionary *commandDict;
        NSString *authRightName;
        id authRightDefault;
        NSString *authRightDesc;
        
        // If any of the following asserts fire it's likely that you've got a bug
        // in sCommandInfo.
        
        commandDict = (NSDictionary*) obj;
        assert([commandDict isKindOfClass:[NSDictionary class]]);
        
        authRightName = [commandDict objectForKey:kCommandKeyAuthRightName];
        assert([authRightName isKindOfClass:[NSString class]]);
        
        authRightDefault = [commandDict objectForKey:kCommandKeyAuthRightDefault];
        assert(authRightDefault != nil);
        
        authRightDesc = [commandDict objectForKey:kCommandKeyAuthRightDesc];
        assert([authRightDesc isKindOfClass:[NSString class]]);
        
        block(authRightName, authRightDefault, authRightDesc);
    }];
}

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef
// See comment in header.
{
    assert(authRef != NULL);
    [MTAuthCommon enumerateRightsUsingBlock:^(NSString *authRightName, id authRightDefault, NSString *authRightDesc) {
        OSStatus    blockErr;
        
        // First get the right.  If we get back errAuthorizationDenied that means there's
        // no current definition, so we add our default one.
        
        blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
        if (blockErr == errAuthorizationDenied) {
            blockErr = AuthorizationRightSet(
                                             authRef,                                    // authRef
                                             [authRightName UTF8String],                 // rightName
                                             (__bridge CFTypeRef) authRightDefault,      // rightDefinition
                                             (__bridge CFStringRef) authRightDesc,       // descriptionKey
                                             NULL,                                       // bundle (NULL implies main bundle)
                                             CFSTR("Localizable")                        // localeTableName
                                             );
            assert(blockErr == errAuthorizationSuccess);
        } else {
            // A right already exists (err == noErr) or any other error occurs, we
            // assume that it has been set up in advance by the system administrator or
            // this is the second time we've run.  Either way, there's nothing more for
            // us to do.
        }
    }];
}

+ (NSString*)getSigningAuthorityWithError:(NSError**)error
{
    OSStatus result = errSecSuccess;
    SecCodeRef helperCodeRef = NULL;
    NSString *returnValue = nil;
    NSString *errorMsg = nil;
    
    // get our code object
    result = SecCodeCopySelf(kSecCSDefaultFlags, &helperCodeRef);
    
    if (result != errSecSuccess) {
        errorMsg = [NSString stringWithFormat:@"Failed to copy code object: %d", result];
    } else {
        
        // get our static code
        SecStaticCodeRef staticCodeRef = NULL;
        result = SecCodeCopyStaticCode(helperCodeRef, kSecCSDefaultFlags, &staticCodeRef);
        
        if (result != errSecSuccess) {
            errorMsg = [NSString stringWithFormat:@"Failed to get static code object: %d", result];
        } else {
            
            // get our own signing information
            CFDictionaryRef signingInfo = NULL;
            result = SecCodeCopySigningInformation(staticCodeRef, kSecCSSigningInformation, &signingInfo);
            
            if (result != errSecSuccess) {
                errorMsg = [NSString stringWithFormat:@"Failed to get signing information: %d", result];
            } else {
                
                CFArrayRef certChain = (CFArrayRef) CFDictionaryGetValue(signingInfo, kSecCodeInfoCertificates);
                
                if (certChain && CFGetTypeID(certChain) == CFArrayGetTypeID() && CFArrayGetCount(certChain) > 0) {
                    
                    SecCertificateRef issuerCert = (SecCertificateRef) CFArrayGetValueAtIndex(certChain, 0);
                    
                    if (issuerCert) {
                        CFStringRef subjectCN = NULL;
                        SecCertificateCopyCommonName(issuerCert, &subjectCN);
                        if (subjectCN) { returnValue = CFBridgingRelease(subjectCN); }
                    }
                }
            }
            
            if (signingInfo) { CFRelease(signingInfo); }
        }
        
        if (staticCodeRef) { CFRelease(staticCodeRef); }
    }
    
    if (helperCodeRef) { CFRelease(helperCodeRef); }
    
    if (errorMsg && error) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:100 userInfo:errorDetail];
    }
    
    return returnValue;
}

@end
