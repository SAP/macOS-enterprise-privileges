/*
 MTVoiceOver.h
 Copyright 2020 SAP SE

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

NS_ASSUME_NONNULL_BEGIN

/*!
@class MTVoiceOver
@abstract This class provides methods for VoiceOver.
*/

@interface MTVoiceOver : NSObject

/*!
@method        postAnnouncementWithString:forUIElement
@abstract      Make VoiceOver speak the given announcement.
@param         accessibilityAnnouncement A string containing the text of the announcement.
@param         uiElement The UI object element the announcement should be sent to.
@discussion    Returns YES if the user is member of the group, otherwise returns NO.
*/
+ (void)postAnnouncementWithString:(NSString*)accessibilityAnnouncement forUIElement:(id)uiElement;

/*!
@method        isEnabled
@abstract      Check if VoiceOver is enabled or not.
@discussion    Returns YES if VoiceOver is enabled, otherwise returns NO.
*/
+ (BOOL)isEnabled;

@end

NS_ASSUME_NONNULL_END
