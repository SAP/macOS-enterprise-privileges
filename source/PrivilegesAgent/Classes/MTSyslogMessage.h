/*
    MTSyslogMessage.h
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

#import <Foundation/Foundation.h>

/*!
@class MTSyslogMessage
@abstract This class provides methods for creating RFC 5424-compliant syslog messages.
*/

@interface MTSyslogMessage : NSObject

/*!
  @enum Syslog Facility
  @discussion Specifies values for diffent syslog facility types.
*/
typedef enum {
    MTSyslogMessageFacilityKernel     = 0,
    MTSyslogMessageFacilityUser       = 1,
    MTSyslogMessageFacilityMail       = 2,
    MTSyslogMessageFacilityDaemon     = 3,
    MTSyslogMessageFacilityAuth       = 4,
    MTSyslogMessageFacilitySyslog     = 5,
    MTSyslogMessageFacilityLPR        = 6,
    MTSyslogMessageFacilityNews       = 7,
    MTSyslogMessageFacilityUUCP       = 8,
    MTSyslogMessageFacilityCron       = 9,
    MTSyslogMessageFacilityAuthPriv   = 10,
    MTSyslogMessageFacilityFTP        = 11,
    
    /* macOS specific facilities */
    MTSyslogMessageFacilityNetInfo    = 12,
    MTSyslogMessageFacilityRemoteAuth = 13,
    MTSyslogMessageFacilityInstall    = 14,
    MTSyslogMessageFacilityRAS        = 15,
    
    MTSyslogMessageFacilityLocal0     = 16,
    MTSyslogMessageFacilityLocal1     = 17,
    MTSyslogMessageFacilityLocal2     = 18,
    MTSyslogMessageFacilityLocal3     = 19,
    MTSyslogMessageFacilityLocal4     = 20,
    MTSyslogMessageFacilityLocal5     = 21,
    MTSyslogMessageFacilityLocal6     = 22,
    MTSyslogMessageFacilityLocal7     = 23,
    
    /* macOS specific facility */
    MTSyslogMessageFacilityLaunchd    = 24
} MTSyslogMessageFacility;

/*!
  @enum Syslog Severity
  @discussion Specifies values for diffent syslog severity types.
*/
typedef enum {
    MTSyslogMessageSeverityEmergency     = 0,
    MTSyslogMessageSeverityAlert         = 1,
    MTSyslogMessageSeverityCritical      = 2,
    MTSyslogMessageSeverityError         = 3,
    MTSyslogMessageSeverityWarning       = 4,
    MTSyslogMessageSeverityNotice        = 5,
    MTSyslogMessageSeverityInformational = 6,
    MTSyslogMessageSeverityDebug         = 7
} MTSyslogMessageSeverity;

/*!
  @enum Syslog Maximum Message Size
  @discussion Specifies values for the maximum syslog message size.
*/
typedef enum {
    MTSyslogMessageMaxSize480  =  480,
    MTSyslogMessageMaxSize1024 = 1024,
    MTSyslogMessageMaxSize2048 = 2048
} MTSyslogMessageMaxSize;


typedef struct  {
    MTSyslogMessageFacility facility;
    MTSyslogMessageSeverity severity;
    NSInteger version;
    NSDate *timestamp;
    NSString *hostname;
    NSString *appname;
    NSString *procid;
    NSString *msgid;
    NSString *structured;
    NSString *msg;
    NSInteger max_size;
} MTSyslogMessageParts;

#define kMTSyslogMessageNilValue    @"-"

/*!
 @method        init
 @abstract      Initializes a MTSyslogMessage object.
 @returns       A MTSyslogMessage object.
*/
- (instancetype)init;

/*!
 @method        setFacility:
 @abstract      Set the receiver's syslog facility.
 @param         facility A MTSyslogMessageFacility object specifying the syslog facility for the receiver.
 @discussion    A syslog message facility is used to specify the type of program that is logging the message.
                If not specified the facility defaults to MTSyslogMessageFacilityUser.
*/
- (void)setFacility:(MTSyslogMessageFacility)facility;

/*!
 @method        setSeverity:
 @abstract      Set the receiver's syslog severity.
 @param         severity A MTSyslogMessageSeverity object specifying the syslog severity for the receiver.
 @discussion    If not specified the severity defaults to MTSyslogMessageSeverityInformational.
*/
- (void)setSeverity:(MTSyslogMessageSeverity)severity;

/*!
 @method        setTimestamp:
 @abstract      Set the receiver's timestamp.
 @param         timestamp A NSDate object specifying the syslog timestamp for the receiver.
 @discussion    If not specified the timestamp is added automatically.
*/
- (void)setTimestamp:(NSDate*)timestamp;

/*!
 @method        setHostname:
 @abstract      Set the receiver's host name.
 @param         hostName A NSString specifying the host name for the receiver.
 @discussion    The host name identifies the machine that originally sent the syslog message. If not specified
                the host name is added automatically.
*/
- (void)setHostname:(NSString*)hostName;

/*!
 @method        setAppName:
 @abstract      Set the receiver's app name.
 @param         appName A NSString specifying the app name for the receiver.
 @discussion    The app name should identify the device or application that originated the message. This is
                an optional value.
*/
- (void)setAppName:(NSString*)appName;

/*!
 @method        setProcessId:
 @abstract      Set the receiver's process id.
 @param         procId A NSString specifying the process id for the receiver.
 @discussion    The process id is a value that is included in the message, having no interoperable meaning,
                except that a change in the value indicates there has been a discontinuity in syslog reporting.
                This is an optional value.
*/
- (void)setProcessId:(NSString*)procId;

/*!
 @method        setMessageId:
 @abstract      Set the receiver's message id.
 @param         msgId A NSString specifying the message id for the receiver.
 @discussion    The message id should identify the type of message.  For example, a firewall might use the
                message id "TCPIN" for incoming TCP traffic and the message id "TCPOUT" for outgoing TCP
                traffic. Messages with the same message id should reflect events of the same semantics. This
                is an optional value.
*/
- (void)setMessageId:(NSString*)msgId;

/*!
 @method        setEventMessage:
 @abstract      Set the receiver's event message.
 @param         eventMessage A NSString specifying the actual event message for the receiver.
 @discussion    The event message contains a free-form message that provides information about the event.
                Must not be nil.
*/
- (void)setEventMessage:(NSString*)eventMessage;

/*!
 @method        setMaxSize:
 @abstract      Set the receiver's maximum size.
 @param         maxSize A MTSyslogMessageMaxSize object specifying the maximum size for the receiver.
 @discussion    If not specified, the maximum size of a syslog message (header + event message) is set to
                MTSyslogMessageMaxSize480 because this is the minimum maximum message size, a syslog
                server must support.
*/
- (void)setMaxSize:(MTSyslogMessageMaxSize)maxSize;

/*!
 @method        messageString
 @abstract      Creates a RFC 5424-compliant syslog message from a MTSyslogMessage object.
 @returns       A NSString containing the syslog message or nil if an error occurred.
*/
- (NSString*)messageString;

/*!
 @method        syslogMessageWithString:
 @abstract      Convenience method that creates a MTSyslogMessage object from the given string.
 @param         eventMessage A NSString containing the event message to be logged.
 @returns       A MTSyslogMessage object containing the event message.
*/
+ (MTSyslogMessage*)syslogMessageWithString:(NSString*)eventMessage;

@end
