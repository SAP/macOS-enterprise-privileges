/*
    MTUpdateChecker.h
    Copyright 2016-2026 SAP SE
     
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

@interface MTUpdateChecker : NSObject

#define kMTUpdateCheckerBundleIdentifier    @"corp.sap.Patcher"
#define kMTDefaultsUpdateCheckDisabledKey   @"UpdateCheckDisabled"

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithBundleIdentifier: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithBundleIdentifier:
 @abstract      Initialize a MTUpdateChecker object with a given bundle identifier.
 @param         identifier A string specifying the bundle identifier of the updater application.
 @discussion    Returns an initialized MTPolicyBanner object.
*/
- (instancetype)initWithBundleIdentifier:(NSString*)identifier NS_DESIGNATED_INITIALIZER;

/*!
 @method        isAvailable
 @abstract      Get wheter the updater application is installed.
 @discussion    Returns YES if the updater application is installed, otherwise returns NO.
*/
- (BOOL)isAvailable;

/*!
 @method        launch
 @abstract      Launch the updater application.
 @discussion    Returns YES if the launch request has been successfully passed to the operating system, otherwise returns NO.
*/
- (BOOL)launch;

@end

