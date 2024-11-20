/*
    AppDelegate.h
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

#import <Cocoa/Cocoa.h>

/*!
 @protocol      AppleScriptDataProvider
 @abstract      Defines an interface for accessing some of the PrivilegesAgent's values via AppleScript.
*/
@protocol AppleScriptDataProvider <NSObject>

/*!
 @method        privilegesTimeLeft
 @abstract      Get the number of minutes remaining until the current user's administrator privileges expire.
 @discussion    Returns the number of minutes remaining until the current user's administrator privileges expire,
                or 0 if the user does not have administrator privileges.
*/
- (NSUInteger)privilegesTimeLeft;

/*!
 @method        userHasAdminPrivileges:
 @abstract      Get whether the current user has administrator privileges.
 @discussion    Returns YES if the current user has administrator privileges, otherwise returns NO.
*/
- (BOOL)userHasAdminPrivileges;

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSXPCListenerDelegate, AppleScriptDataProvider>

@end

