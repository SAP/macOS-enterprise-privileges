/*
 MTIdentity.m
 Copyright 2016-2018 SAP SE
 
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
#import <Collaboration/Collaboration.h>

@implementation MTIdentity

+ (int)gidFromGroupName:(NSString*)groupName
{
    int posixID = -1;
    
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
    
    return posixID;
}

+ (BOOL)getGroupMembershipForUser:(NSString*)userName groupID:(gid_t)groupID error:(NSError**)error
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

@end

