/*
    MTDropPopUpButton.h
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

@class MTDropPopUpButton;

/*!
 @protocol      MTDropPopUpButtonDelegate
 @abstract      Defines an interface for delegates of MTDropPopUpButton to be notified about changes to the button.
*/
@protocol MTDropPopUpButtonDelegate <NSObject>

/*!
 @method        button:didAddApplicationAtPath:
 @abstract      Called if an application has been added to the button's menu.
 @param         button A reference to the MTDropPopUpButton instance.
 @param         path The path to the application that has been added.
 @discussion    Delegates receive this message after an application has been added to the menu of the MTDropPopUpButton.
*/
- (void)button:(MTDropPopUpButton*)button didAddApplicationAtPath:(NSString*)path;

/*!
 @method        button:didFailToAddApplicationAtPath:
 @abstract      Called if an application could not be added to the button's menu.
 @param         button A reference to the MTDropPopUpButton instance.
 @param         path The path to the application that could not be added.
 @discussion    Delegates receive this message when an application cannot be added to the MTDropPopUpButton menu because
                the application is not accessible or the user does not have the necessary permissions to execute it.
*/
- (void)button:(MTDropPopUpButton*)button didFailToAddApplicationAtPath:(NSString*)path;

@end

@interface MTDropPopUpButton : NSPopUpButton <NSDraggingDestination>

/*!
 @enum          MTDropPopUpButtonSelection
 @abstract      Specifies the selected menu entry of the button.
 @constant      MTDropPopUpButtonSelectionTypeNone Specifies the first menu entry.
 @constant      MTDropPopUpButtonSelectionTypeApp Specifies the application menu entry.
*/
typedef enum {
    MTDropPopUpButtonSelectionTypeNone = 0,
    MTDropPopUpButtonSelectionTypeApp  = 755
} MTDropPopUpButtonSelection;

/*!
 @property      delegate
 @abstract      The receiver's delegate.
 @discussion    The value of this property is an object conforming to the MTDropPopUpButtonDelegate protocol.
*/
@property (weak) id <MTDropPopUpButtonDelegate> delegate;

- (void)setExecutablePath:(NSString*)path;
- (BOOL)hasApplicationItem;
- (void)selectRelevantItem;

@end
