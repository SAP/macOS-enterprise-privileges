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
@property (assign) MTSyslogMessageParts msgParts;
@end

@implementation MTSyslogMessage

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _msgParts.version    = 1;
        _msgParts.facility   = MTSyslogMessageFacilityUser;
        _msgParts.severity   = MTSyslogMessageSeverityInformational;
        _msgParts.appname    = kMTSyslogMessageNilValue;
        _msgParts.procid     = kMTSyslogMessageNilValue;
        _msgParts.msgid      = kMTSyslogMessageNilValue;
        _msgParts.structured = kMTSyslogMessageNilValue;
        _msgParts.max_size   = MTSyslogMessageMaxSize480;
    }
    
    return self;
}

- (void)setFacility:(MTSyslogMessageFacility)facility
{
    if (facility >= 0 && facility <= 24) {
        _msgParts.facility = facility;
    }
}

- (void)setSeverity:(MTSyslogMessageSeverity)severity
{
    if (severity >= 0 && severity <= 7) {
        _msgParts.severity = severity;
    }
}

- (void)setTimestamp:(NSDate*)timestamp
{
    if (timestamp) {
        _msgParts.timestamp = timestamp;
    }
}

- (void)setHostname:(NSString*)hostName
{
    hostName = [self cleanHeaderString:hostName maximumLength:255];
    _msgParts.hostname = hostName;
}

- (void)setAppName:(NSString*)appName
{
    appName = [self cleanHeaderString:appName maximumLength:48];
    _msgParts.appname = ([appName length] > 0) ? appName : kMTSyslogMessageNilValue;
}

- (void)setProcessId:(NSString*)procId
{
    procId = [self cleanHeaderString:procId maximumLength:128];
    _msgParts.procid = ([procId length] > 0) ? procId : kMTSyslogMessageNilValue;
}

- (void)setMessageId:(NSString*)msgId
{
    msgId = [self cleanHeaderString:msgId maximumLength:32];
    _msgParts.msgid = ([msgId length] > 0) ? msgId : kMTSyslogMessageNilValue;
}

- (void)setEventMessage:(NSString*)eventMessage
{
    _msgParts.msg = eventMessage;
}

- (void)setMaxSize:(MTSyslogMessageMaxSize)maxSize
{
    if (maxSize >= MTSyslogMessageMaxSize480 && maxSize <= MTSyslogMessageMaxSize2048) {
        _msgParts.max_size = maxSize;
    }
}

- (NSString*)messageString
{
    NSString *returnValue = nil;
    
    if ([_msgParts.msg length] > 0) {
        
        NSMutableString *finalMessage = [[NSMutableString alloc] init];
        
        // first we calculate the message priority
        NSInteger msgPriority = _msgParts.facility * 8 + _msgParts.severity;
        [finalMessage appendFormat:@"<%ld>", (long)msgPriority];
        
        // add the version
        [finalMessage appendFormat:@"%ld ", (long)_msgParts.version];
        
        // set the timestamp
        if (!_msgParts.timestamp) { _msgParts.timestamp  = [[NSDate alloc] init]; }

        NSISO8601DateFormatter *timestampFormatter = [[NSISO8601DateFormatter alloc] init];
        [finalMessage appendFormat:@"%@ ", [timestampFormatter stringFromDate:_msgParts.timestamp]];
        
        // add the host name
        if ([_msgParts.hostname length] == 0) {
            
            // if no name has been specified, we try to get the local name
            _msgParts.hostname = (NSString*)CFBridgingRelease(SCDynamicStoreCopyComputerName(NULL, NULL));
            
            // if this didn't work, we'll use the first local ip address we find
            if ([_msgParts.hostname length] == 0) {
                
                for (NSString *ipAddress in [[NSHost currentHost] addresses]) {
                    if ([[ipAddress componentsSeparatedByString:@"."] count] == 4  && ![ipAddress isEqualToString:@"127.0.0.1"]) {
                        _msgParts.hostname = ipAddress;
                        break;
                    }
                }
            }
        }
            
        if ([_msgParts.hostname length] > 0) {
            
            [finalMessage appendFormat:@"%@ ", _msgParts.hostname];
            
            // add the app name
            [finalMessage appendFormat:@"%@ ", _msgParts.appname];
            
            // add the process id
            [finalMessage appendFormat:@"%@ ", _msgParts.procid];
            
            // add the message id
            [finalMessage appendFormat:@"%@ ", _msgParts.msgid];
            
            // add structured data (not implemented yet)
            [finalMessage appendFormat:@"%@ ", _msgParts.structured];
            
            // add the BOM (0xEFBBBF) to indicate a unicode string. Then
            // add the log message and make sure, the final message is not longer
            // than specified in _msgParts.max_length to prevent information loss
            [finalMessage appendFormat:@"\357\273\277%@\n", _msgParts.msg];
            NSInteger finalMessageLength = [finalMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

            if (finalMessageLength > _msgParts.max_size) {
                
                NSData *originalMessageData = [finalMessage dataUsingEncoding:NSUTF8StringEncoding];
                const char *originalMessageBytes = originalMessageData.bytes;
                NSData *truncatedMessageData = [NSData dataWithBytes:originalMessageBytes length:_msgParts.max_size];
                NSString *truncatedString = [[NSString alloc] initWithData:truncatedMessageData encoding:NSUTF8StringEncoding];
                finalMessage = [NSMutableString stringWithString:[truncatedString stringByAppendingString:@"\n"]];
            }

            returnValue = finalMessage;
        }
    }
    
    return returnValue;
}

+ (MTSyslogMessage*)syslogMessageWithString:(NSString*)eventMessage
{
    MTSyslogMessage *syslogMessage = [[self alloc] init];
    [syslogMessage setEventMessage:eventMessage];
    
    return syslogMessage;
}
    
- (NSString*)cleanHeaderString:(NSString*)originalString maximumLength:(NSInteger)maxLength
{
    NSString *cleanedString = nil;
    
    if ([originalString length] > 0) {

        // convert string to US_ASCII
        NSData *stringData = [originalString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        originalString = [[NSString alloc] initWithData:stringData encoding:NSASCIIStringEncoding];
        
        // remove all non-prinable characters
        originalString = [originalString stringByReplacingOccurrencesOfString:@"[^\x21-\x7E]"
                                                                   withString:@""
                                                                      options:NSRegularExpressionSearch
                                                                        range:NSMakeRange(0, [originalString length])];

        // make sure the string does not exceed the allowed length
        if ([originalString length] > maxLength) {
            originalString = [originalString substringToIndex:(maxLength - 1)];
        }
        
        if ([originalString length] > 0) { cleanedString = originalString; }
    }
    
    return cleanedString;
}

@end
