/*
    MTSyslogMessage.m
    Copyright 2020-2025 SAP SE

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

#import "MTSyslogMessage.h"
#import <SystemConfiguration/SystemConfiguration.h>

@interface MTSyslogMessage ()
@property (nonatomic, assign) MTSyslogMessageFacility facility;
@property (nonatomic, assign) MTSyslogMessageSeverity severity;
@property (nonatomic, assign) NSUInteger msgVersion;
@property (nonatomic, strong, readwrite) NSString *hostName;
@property (nonatomic, strong, readwrite) NSString *appName;
@property (nonatomic, strong, readwrite) NSString *procID;
@property (nonatomic, strong, readwrite) NSString *messageID;
@property (nonatomic, assign) MTSyslogMessageMaxSize maxSize;
@property (nonatomic, assign) MTSyslogMessageFormat format;
@end

@implementation MTSyslogMessage

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _msgVersion = 1;
        _facility = MTSyslogMessageFacilityUser;
        _severity = MTSyslogMessageSeverityInformational;
        _maxSize = MTSyslogMessageMaxSize480;
        _format = MTSyslogMessageFormatNone;
    }
    
    return self;
}

#pragma mark Setters

- (void)setFormat:(MTSyslogMessageFormat)format
{
    _format = (format >= 0 && format <= 2) ? format : MTSyslogMessageFormatNonTransparentFraming;
}

- (void)setFacility:(MTSyslogMessageFacility)facility
{
    _facility = (facility >= 0 && facility <= 24) ? facility : MTSyslogMessageFacilityUser;
}

- (void)setSeverity:(MTSyslogMessageSeverity)severity
{
    _severity = (severity >= 0 && severity <= 7) ? severity : MTSyslogMessageSeverityInformational;
}

- (void)setHostName:(NSString*)name
{
    _hostName = [MTSyslogMessageStructuredData cleanString:name maximumLength:255];
}

- (void)setAppName:(NSString*)name
{
    _appName = [MTSyslogMessageStructuredData cleanString:name maximumLength:48];
}

- (void)setProcID:(NSString*)pid
{
    _procID = [MTSyslogMessageStructuredData cleanString:pid maximumLength:128];
}

- (void)setMessageID:(NSString*)msgId
{
    _messageID = [MTSyslogMessageStructuredData cleanString:msgId maximumLength:32 ];
}

- (void)setMaxSize:(MTSyslogMessageMaxSize)maxSize
{
    _maxSize = (maxSize >= MTSyslogMessageMaxSize480 && maxSize <= MTSyslogMessageMaxSize2048) ? maxSize : MTSyslogMessageMaxSize480;
}

#pragma mark Message composing

- (NSInteger)composedPriority
{
    return _facility * 8 + _severity;
}

- (NSString*)composedTimestamp
{
    NSISO8601DateFormatter *timestampFormatter = [[NSISO8601DateFormatter alloc] init];
    [timestampFormatter setFormatOptions:NSISO8601DateFormatWithFractionalSeconds | NSISO8601DateFormatWithInternetDateTime];
    NSDate *tempTimeStamp = (_timeStamp) ? _timeStamp : [NSDate now];
    
    return [timestampFormatter stringFromDate:tempTimeStamp];
}

- (NSString*)composedHostName
{
    NSString *returnValue = _hostName;
    
    if ([returnValue length] == 0) {
        
        // if no name has been specified, we try to get the local name
        returnValue = (NSString*)CFBridgingRelease(SCDynamicStoreCopyComputerName(NULL, NULL));
        
        // if this didn't work, we use the first local ip address we find
        if ([returnValue length] == 0) {
            
            for (NSString *ipAddress in [[NSHost currentHost] addresses]) {
                
                if ([[ipAddress componentsSeparatedByString:@"."] count] == 4  && ![ipAddress isEqualToString:@"127.0.0.1"]) {
                    returnValue = ipAddress;
                    break;
                }
            }
            
            // if all this didn't work, return the nil value
            if ([returnValue length] == 0) { returnValue = kMTSyslogMessageNilValue; }
        }
    }
    
    return returnValue;
}

- (NSString*)composedAppName
{
    NSString *returnValue = _appName;
    
    if ([returnValue length] == 0) {
        
        // if no name has been specified, we try to get it from the process name
        NSProcessInfo *processInfo = [[NSProcessInfo alloc] init];
        returnValue = [processInfo processName];
            
        // if this didn't work, return the nil value
        if ([returnValue length] == 0) { returnValue = kMTSyslogMessageNilValue; }
    }
    
    return returnValue;
}

- (NSString*)composedProcID
{
    NSString *returnValue = _procID;
    
    if ([returnValue length] == 0) {
        
        // if no name has been specified, we try to get it from the path
        NSProcessInfo *processInfo = [[NSProcessInfo alloc] init];
        returnValue = [NSString stringWithFormat:@"%d", [processInfo processIdentifier]];
            
        // if this didn't work, return the nil value
        if ([returnValue length] == 0) { returnValue = kMTSyslogMessageNilValue; }
    }
    
    return returnValue;
}

- (NSString*)composedID
{
    NSString *returnValue = ([_messageID length] > 0) ? _messageID : kMTSyslogMessageNilValue;
    return returnValue;
}

- (NSString*)composedStructuredData
{
    NSString *returnValue = [_structuredData composedString];
    return (returnValue) ? returnValue : kMTSyslogMessageNilValue;
}

- (NSString*)composedEvent
{
    // the BOM (\357\273\277 -> 0xEFBBBF) indicates a unicode string
    NSString *returnValue = (_eventMessage) ? [NSString stringWithFormat:@"\357\273\277%@", _eventMessage] : @"";
    return returnValue;
}

- (NSString*)composedMessage;
{
    NSString *returnValue = nil;
    
    NSString *tempMessageString = [NSString stringWithFormat:@"<%ld>%ld %@ %@ %@ %@ %@ %@ %@",
                                   [self composedPriority],
                                   _msgVersion,
                                   [self composedTimestamp],
                                   [self composedHostName],
                                   [self composedAppName],
                                   [self composedProcID],
                                   [self composedID],
                                   [self composedStructuredData],
                                   [self composedEvent]
    ];
    
    if (_format == MTSyslogMessageFormatNonTransparentFraming) {
        tempMessageString = [tempMessageString stringByAppendingString:@"\n"];
    }
    
    NSInteger messageLength = [tempMessageString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

    if (messageLength > _maxSize) {
        
        // set the target length. if we use non-transparent framing, make sure
        // there's enough space to add a newline after truncating the data
        NSUInteger targetLength = _maxSize;
        if (_format == MTSyslogMessageFormatNonTransparentFraming) { targetLength--; }
        
        NSData *originalMessageData = [tempMessageString dataUsingEncoding:NSUTF8StringEncoding];
        const char *originalMessageBytes = [originalMessageData bytes];
        NSData *truncatedMessageData = [NSData dataWithBytes:originalMessageBytes length:targetLength];
        NSString *truncatedString = [[NSString alloc] initWithData:truncatedMessageData encoding:NSUTF8StringEncoding];
        tempMessageString = truncatedString;
        messageLength = targetLength;
        
        // if we use non-transparent framing, make sure we add a newline again at the end
        if (_format == MTSyslogMessageFormatNonTransparentFraming) {
            tempMessageString = [tempMessageString stringByAppendingString:@"\n"];
        }
    }
    
    // if we use octet counting, make sure the message starts with the message length
    if (_format == MTSyslogMessageFormatOctetCounting) {
        tempMessageString = [NSString stringWithFormat:@"%ld %@", messageLength, tempMessageString];
    }
    
    returnValue = tempMessageString;
    
    return returnValue;
}

@end
