/*
    MTDropPopUpButton.m
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

#import "MTDropPopUpButton.h"
#import "MTPrivileges.h"
#import <UniformTypeIdentifiers/UTCoreTypes.h>

@implementation MTDropPopUpButton

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self setWantsLayer:YES];
    [self registerForDraggedTypes:[NSArray arrayWithObject:NSPasteboardTypeFileURL]];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];

    if (enabled) {
        
        [self registerForDraggedTypes:[NSArray arrayWithObject:NSPasteboardTypeFileURL]];
        
    } else {
        
        [self unregisterDraggedTypes];
        [[self layer] setBackgroundColor:nil];
    }
}

- (void)setExecutablePath:(NSString*)path
{
    if (path) {
        
        MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];
        [[privilegesApp currentUser] canExecuteFileAtURL:[NSURL fileURLWithPath:path]
                                                   reply:^(BOOL canExecute) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (canExecute) {
                
                    // get the title for the menu item…
                    NSString *itemTitle = [path lastPathComponent];
                    if ([[[itemTitle pathExtension] lowercaseString] isEqualToString:@"app"]) {
                        itemTitle = [itemTitle stringByDeletingPathExtension];
                    }
                    
                    // get the image for the menu item…
                    NSImage *itemImage = [[NSWorkspace sharedWorkspace] iconForFile:path];
                    
                    if ([itemImage isValid]) {
                        
                        // resize the image to 16x16 pixels
                        NSImageRep *imageRep = [itemImage bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil hints:nil];
                        itemImage = [[NSImage alloc] initWithSize:[imageRep size]];
                        [itemImage addRepresentation:imageRep];
                    }
                    
                    // add the item…
                    NSMenuItem *executableItem = [[NSMenuItem alloc] initWithTitle:itemTitle
                                                                            action:nil
                                                                     keyEquivalent:@""
                    ];
                    [executableItem setImage:itemImage];
                    [executableItem setTag:MTDropPopUpButtonSelectionTypeApp];
                    [self addApplicationItem:executableItem];
                    
                    if (self->_delegate && [self->_delegate respondsToSelector:@selector(button:didAddApplicationAtPath:)]) {
                        [self->_delegate button:self didAddApplicationAtPath:path];
                    }
                
                } else if (self->_delegate && [self->_delegate respondsToSelector:@selector(button:didFailToAddApplicationAtPath:)]) {
                    [self->_delegate button:self didFailToAddApplicationAtPath:path];
                }
                
                [self selectRelevantItem];
            });
        }];
  
    } else {
        
        [self removeApplicationItem];
    }
    
    [self setAccessibilityLabel:[self titleOfSelectedItem]];
}

- (BOOL)hasApplicationItem
{
    return ([[self menu] itemWithTag:MTDropPopUpButtonSelectionTypeApp] != nil);
}

- (void)removeApplicationItem
{
    if ([self hasApplicationItem]) {
        
        [[self menu] removeItemAtIndex:[self indexOfItemWithTag:MTDropPopUpButtonSelectionTypeApp]];
    }
}

- (void)addApplicationItem:(NSMenuItem*)item
{
    // remove an existing app item
    [self removeApplicationItem];
    
    // add the new item
    [[self menu] insertItem:item atIndex:2];
}

- (void)selectRelevantItem
{
    if ([self hasApplicationItem]) {
        
        [self selectItemWithTag:MTDropPopUpButtonSelectionTypeApp];
        
    } else {
        
        [self selectItemAtIndex:MTDropPopUpButtonSelectionTypeNone];
    }
}

#pragma mark - dragging methods

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    NSDragOperation dragOperation = NSDragOperationNone;
    
    if ([self isEnabled]) {
        
        NSPasteboard *pboard = [sender draggingPasteboard];
        NSArray *supportedFileTypes = [NSArray arrayWithObjects:UTTypeApplicationBundle, UTTypeUnixExecutable, UTTypeShellScript, nil];
        
        if ([[pboard pasteboardItems] count] == 1 && [[pboard types] containsObject:NSPasteboardTypeFileURL]) {
            
            NSURL *imageURL = [NSURL URLFromPasteboard:pboard];
            imageURL = [imageURL URLByResolvingSymlinksInPath];
            
            id utiValue = nil;
            [imageURL getResourceValue:&utiValue forKey:NSURLTypeIdentifierKey error:nil];
            
            if (utiValue) {
                
                BOOL isSupported = NO;
                UTType *fileType = [UTType typeWithIdentifier:utiValue];
                
                for (UTType *type in supportedFileTypes) {
                    
                    if ([fileType conformsToType:type]) {
                        
                        isSupported = YES;
                        break;
                    }
                }
                
                if (isSupported) {
                    
                    dragOperation = NSDragOperationCopy;
                    [[self layer] setBackgroundColor:[NSColor unemphasizedSelectedContentBackgroundColor].CGColor];
                }
            }
        }
    }

    return dragOperation;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    BOOL success = NO;
    
    if ([self isEnabled]) {
        
        NSURL *fileURL = [NSURL URLFromPasteboard:[sender draggingPasteboard]];
        
        if (fileURL) {
            
            [self setExecutablePath:[fileURL path]];
            success = YES;
        }
    }
    
    [[self layer] setBackgroundColor:nil];
    
    return success;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    [[self layer] setBackgroundColor:nil];
}

@end
