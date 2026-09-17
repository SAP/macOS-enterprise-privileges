/*
    MTPolicyBanner.m
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

#import "MTPolicyBanner.h"
#import "Constants.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MTPolicyBanner ()
@property (nonatomic, strong, readwrite) NSString *bannerPath;
@property (nonatomic, strong, readwrite) NSData *bannerData;
@end

@implementation MTPolicyBanner

- (instancetype)initWithBasePath:(NSString*)path
{
    self = [super init];
    
    if (self) {
        
        if (path) {
            
            NSArray *supportedFileTypes = [NSArray arrayWithObjects:@"txt", @"rtf", @"rtfd", nil];
            
            for (NSString *fileType in supportedFileTypes) {
                
                NSString *tempPath = [path stringByAppendingPathExtension:fileType];
                
                if ([[NSFileManager defaultManager] isReadableFileAtPath:tempPath] && [self fileSizeAllowedWithPath:tempPath]) {
                    
                    _bannerPath = tempPath;
                    break;
                }
            }
        }
        
        if ([_bannerPath length] == 0) { self = nil; }
    }
    
    return self;
}

- (instancetype)initWithData:(NSData*)data
{
    self = [super init];
    
    if (self) {
        
        if (data) {
            
            _bannerData = [[NSData alloc] initWithData:data];
        }
        
        if ([_bannerData length] == 0) { self = nil; }
    }
    
    return self;
}

- (BOOL)fileSizeAllowedWithPath:(NSString*)path
{
    BOOL isAllowed = NO;
    
    if (path) {
        
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        
        if (fileURL) {
            
            NSError *error = nil;
            UTType *fileType = nil;

            
            [fileURL getResourceValue:&fileType
                               forKey:NSURLContentTypeKey
                                error:&error
            ];
            
            if (!error) {
                
                NSNumber *fileSize = nil;
                
                if ([fileType conformsToType:UTTypeRTF] || [fileType conformsToType:UTTypeText]) {
                    
                    [[NSURL fileURLWithPath:path] getResourceValue:&fileSize
                                                            forKey:NSURLFileSizeKey
                                                             error:&error
                    ];
                    
                } else if ([fileType conformsToType:UTTypeRTFD]) {
                    
                    fileSize = [self allocatedSizeOfDirectoryAtURL:fileURL];
                }

                isAllowed = (!error && fileSize && [fileSize unsignedIntegerValue] <= kMTMaximumPolicySize);
            }
        }
    }

    return isAllowed;
}

- (NSNumber*)allocatedSizeOfDirectoryAtURL:(NSURL *)directoryURL
{
    NSNumber *totalSize = 0;
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directoryURL
                                                             includingPropertiesForKeys:[NSArray arrayWithObjects:
                                                                                         NSURLIsRegularFileKey,
                                                                                         NSURLFileAllocatedSizeKey,
                                                                                         NSURLTotalFileAllocatedSizeKey,
                                                                                         nil
                                                                                        ]
                                                                                options:0
                                                                           errorHandler:nil
    ];

    for (NSURL *fileURL in enumerator) {
        
        NSNumber *isRegularFile = nil;
        
        [fileURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil];

        if (![isRegularFile boolValue]) { continue; }

        NSNumber *fileSize = nil;

        [fileURL getResourceValue:&fileSize forKey:NSURLTotalFileAllocatedSizeKey error:nil];
        if (fileSize == nil) { [fileURL getResourceValue:&fileSize forKey:NSURLFileAllocatedSizeKey error:nil]; }

        totalSize = [NSNumber numberWithUnsignedLongLong:[totalSize unsignedLongLongValue] + [fileSize unsignedLongLongValue]];
    }

    return totalSize;
}

- (NSAttributedString*)attributedString
{
    NSAttributedString *attrString = nil;
    NSDictionary *options = [NSDictionary dictionary];
    
    if (_bannerData) {
    
        attrString = [[NSAttributedString alloc] initWithData:_bannerData
                                                      options:options
                                           documentAttributes:nil
                                                        error:nil
        ];
        
    } else if (_bannerPath) {
        
        attrString = [[NSAttributedString alloc] initWithURL:[NSURL fileURLWithPath:_bannerPath]
                                                     options:options
                                          documentAttributes:nil
                                                       error:nil
        ];
    }
            
    return attrString;
}


@end
