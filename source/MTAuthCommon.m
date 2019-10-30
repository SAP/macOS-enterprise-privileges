/*
 MTAuthCommon.m
 Copyright 2016-2019 SAP SE
 
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
                         NSStringFromSelector(@selector(changeGroupMembershipForUser:group:remove:authorization:withReply:)) : @{
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

+ (void)enumerateRightsUsingBlock:(void (^)(NSString * authRightName, id authRightDefault, NSString * authRightDesc))block
// Calls the supplied block with information about each known authorization right..
{
    [self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
#pragma unused(key)
#pragma unused(stop)
        NSDictionary *  commandDict;
        NSString *      authRightName;
        id              authRightDefault;
        NSString *      authRightDesc;
        
        // If any of the following asserts fire it's likely that you've got a bug
        // in sCommandInfo.
        
        commandDict = (NSDictionary *) obj;
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
    [MTAuthCommon enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc) {
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

+ (NSData*)createAuthorizationUsingAuthorizationRef:(AuthorizationRef*)authRef
{
    NSData *authorization;
    AuthorizationExternalForm extForm;
    OSStatus err = AuthorizationCreate(NULL, NULL, 0, authRef);
    
    // If we can't create an authorization reference then the app is not going to be able
    // to do anything requiring authorization.  Generally this only happens when you launch
    // the app in some wacky, and typically unsupported, way.  In the debug build we flag that
    // with an assert.  In the release build we continue with self->_authRef as NULL, which will
    // cause all authorized operations to fail.
    
    if (err == errAuthorizationSuccess) { err = AuthorizationMakeExternalForm(*authRef, &extForm); }
    
    if (err == errAuthorizationSuccess) {
        authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
        
        // If we successfully connected to Authorization Services, get our XPC service to add
        // definitions for our default rights (unless they're already in the database).
        if (authRef) { [MTAuthCommon setupAuthorizationRights:*authRef]; }
    }
    
    return authorization;
}

+ (BOOL)installHelperToolUsingAuthorizationRef:(AuthorizationRef)authRef error:(NSError**)error
{
    CFErrorRef helperError;
    BOOL success = SMJobBless(
                              kSMDomainSystemLaunchd,
                              CFSTR("corp.sap.privileges.helper"),
                              authRef,
                              &helperError
                              );
    
    if (!success && error != nil) {
        *error = (__bridge NSError *) helperError;
        CFRelease(helperError);
    }

    return success;
}

+ (void)connectToHelperToolUsingConnection:(__strong NSXPCConnection**)helperToolConnection
// Ensures that we're connected to our helper tool.
{
    assert([NSThread isMainThread]);
    
    if (*helperToolConnection == nil) {
        
        NSXPCConnection *xpcConnection = [[NSXPCConnection alloc] initWithMachServiceName:kHelperToolMachServiceName
                                                                                  options:NSXPCConnectionPrivileged];
        xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        // We can ignore the retain cycle warning because a) the retain taken by the
        // invalidation handler block is released by us setting it to nil when the block
        // actually runs, and b) the retain taken by the block passed to -addOperationWithBlock:
        // will be released when that operation completes and the operation itself is deallocated
        // (notably self does not have a reference to the NSBlockOperation).
        xpcConnection.invalidationHandler = ^{
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            xpcConnection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                *helperToolConnection = nil;
            }];
        };
        *helperToolConnection = xpcConnection;
        
#pragma clang diagnostic pop
        [*helperToolConnection resume];
    }
}

+ (void)connectToHelperToolUsingConnection:(__strong NSXPCConnection**)helperToolConnection andExecuteCommandBlock:(void(^)(void))commandBlock
// Connects to the helper tool and then executes the supplied command
// block on the main thread.
{
    assert([NSThread isMainThread]);
    
    // ensure that there's a helper tool connection in place.
    [self connectToHelperToolUsingConnection:helperToolConnection];
    
    // run the command block
    commandBlock();
}

@end
