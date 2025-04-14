/*
    MTIdentity.m
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

#import "MTIdentity.h"
#import "Constants.h"
#import <os/log.h>

@implementation MTIdentity

+ (int)gidFromGroupName:(NSString*)groupName
{
    int posixID = -1;
    
    if ([groupName length] > 0) {
        
        CSIdentityQueryRef groupQuery = CSIdentityQueryCreateForName(NULL, (__bridge CFStringRef)groupName, kCSIdentityQueryStringEquals, kCSIdentityClassGroup, CSGetLocalIdentityAuthority());
        
        // run the query
        CSIdentityQueryExecute(groupQuery, kCSIdentityQueryIncludeHiddenIdentities, NULL);
        CFArrayRef groupQueryResults = CSIdentityQueryCopyResults(groupQuery);
        
        if (groupQueryResults) {
            long resultsCount = CFArrayGetCount(groupQueryResults);
            
            if (resultsCount == 1) {
                CSIdentityRef groupIdentity = (CSIdentityRef)CFArrayGetValueAtIndex(groupQueryResults, 0);
                posixID = (int)CSIdentityGetPosixID(groupIdentity);
                
            }
            
            CFRelease(groupQueryResults);
        }
    }
    
    return posixID;
}

+ (BOOL)groupMembershipForUser:(NSString*)userName groupID:(gid_t)groupID error:(NSError**)error
{
    BOOL isMember = NO;
    NSString *errorMsg;
    
    // get the identity for the current user
    CBIdentity *userIdentity = [CBIdentity identityWithName:userName authority:[CBIdentityAuthority defaultIdentityAuthority]];
    
    if (userIdentity != nil) {
        
        // get the identity of the admin group
        CBGroupIdentity *groupIdentity = [CBGroupIdentity groupIdentityWithPosixGID:groupID authority:[CBIdentityAuthority localIdentityAuthority]];
        
        if (groupIdentity != nil) {
            
            // check if the user is currently a member of the admin group
            isMember = [userIdentity isMemberOfGroup:groupIdentity];
            
        } else { errorMsg = @"Unable to get group identity"; }
        
    } else { errorMsg = @"Unable to get user identity"; }
    
    if (errorMsg != nil && error != nil) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
    }
    
    return isMember;
}

+ (BOOL)groupMembershipForUser:(NSString*)userName groupName:(NSString*)groupName error:(NSError**)error
{
    BOOL isMember = NO;
    NSString *errorMsg;
    
    gid_t groupID = [self gidFromGroupName:groupName];
    
    if (groupID == -1) {
        
        errorMsg = [NSString stringWithFormat:@"Unable to get id of group %@", groupName];
        
    } else {
        
        isMember = [self groupMembershipForUser:userName
                                           groupID:[self gidFromGroupName:groupName]
                                             error:error
        ];
    }
    
    if (errorMsg != nil && error != nil) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
    }
    
    return isMember;
}

+ (void)authenticateUserWithReason:(NSString*)authReason completionHandler:(void (^) (BOOL success, NSError *error))completionHandler
{
    if (authReason) {
        
        NSError *error = nil;
        LAContext *myContext = [[LAContext alloc] init];
        
        if ([myContext canEvaluatePolicy:kLAPolicyDeviceOwnerAuthentication error:&error]) {
            
            [myContext evaluatePolicy:kLAPolicyDeviceOwnerAuthentication
                      localizedReason:authReason
                                reply:^(BOOL success, NSError *error) {
                
                if (completionHandler) { completionHandler(success, error); }
            }];
            
        } else {
            
            if (completionHandler) { completionHandler(NO, error); }
        }
    
    } else {
        
        if (completionHandler) { completionHandler(NO, nil); }
    }
}

+ (void)authenticatePIVUserWithReason:(NSString*)authReason completionHandler:(void (^) (BOOL success, NSError *error))completionHandler
{
    // Since Local Authentication does not currently support smartcard/PIV
    // tokens, we have to use Authorization Services instead.
    
    if (authReason) {
        
        // create an empty right
        AuthorizationRef authRef;
        OSStatus status = AuthorizationCreate(NULL, NULL, 0, &authRef);
        
        if (status == noErr) {
            
            // check if the right already exists or create it
            status = AuthorizationRightGet(kMTAuthRightName, NULL);
            
            if (status == errAuthorizationDenied) {
                
                status = AuthorizationRightSet(
                                               authRef,
                                               kMTAuthRightName,
                                               CFSTR(kAuthorizationRuleAuthenticateAsSessionUser),
                                               NULL,
                                               NULL,
                                               NULL
                                               );
                
                if (status != noErr) {
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to ceate default right: (%d)", (int)status);
                }
            }
            
            if (status == noErr) {
                        
                AuthorizationItem authItem = {kMTAuthRightName, 0, NULL, 0};
                AuthorizationRights authRights = {1, &authItem};
                AuthorizationFlags authFlags = (kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed);
                
                AuthorizationItem dialogItem = {kAuthorizationEnvironmentPrompt, strlen([authReason UTF8String]), (char *)[authReason UTF8String], 0};
                AuthorizationEnvironment authEnvironment = {1, &dialogItem };
                
                status = AuthorizationCopyRights(
                                                 authRef,
                                                 &authRights,
                                                 &authEnvironment,
                                                 authFlags,
                                                 NULL
                                                 );
                
                if (status == errAuthorizationSuccess) {
                    
                    if (completionHandler) { completionHandler(YES, nil); }
                    AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
                    
                } else {
                    
                    if (completionHandler) {
                        
                        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
                        completionHandler(NO, error);
                    }
                }
                
            } else {
                
                NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
                if (completionHandler) { completionHandler(NO, error); }
            }
        }
        
    } else {
        
        if (completionHandler) { completionHandler(NO, nil); }
    }
}

+ (BOOL)verifyPassword:(NSString*)userPassword forUser:(NSString*)userName
{
    BOOL success = NO;
    
    if (userName && userPassword) {
        
        ODNode *searchNode = [ODNode nodeWithSession:[ODSession defaultSession] type:kODNodeTypeAuthentication error:nil];
        
        if (searchNode) {
            
            ODRecord *userRecord = [searchNode recordWithRecordType:kODRecordTypeUsers
                                                               name:userName
                                                         attributes:nil
                                                              error:nil
            ];
            
            if (userRecord) { success = [userRecord verifyPassword:userPassword error:nil]; }
        }
    }
    
    return success;
}

@end

