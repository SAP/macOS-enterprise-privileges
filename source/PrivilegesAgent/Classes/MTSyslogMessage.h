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
#import "MTSyslogMessageStructuredData.h"

/*!
@class MTSyslogMessage
@abstract This class provides methods for creating RFC 5424 compliant syslog messages.
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

/*!
  @enum Syslog Message Format
  @discussion Specifies the format of the syslog message. MTSyslogMessageFormatNone specifies an RFC 5424
              compliant syslog message, which is typically used to send a syslog message over UDP. The other two
              formats are used for sending syslog messages over TCP. MTSyslogMessageFormatNonTransparentFraming
              specifies an RFC 5424 compliant syslog message that uses non-transparent framing, and
              MTSyslogMessageFormatOctetCounting specifies one that uses octet counting.
*/
typedef enum {
    MTSyslogMessageFormatNone                  = 0,
    MTSyslogMessageFormatNonTransparentFraming = 1,
    MTSyslogMessageFormatOctetCounting         = 2
} MTSyslogMessageFormat;

#define kMTSyslogMessageNilValue    @"-"

/*!
 @property      facility
 @abstract      Returns the syslog message's facility.
 @discussion    The value of this property is MTSyslogMessageFacility and the
                default value is MTSyslogMessageFacilityUser.
*/
@property (nonatomic, assign, readonly) MTSyslogMessageFacility facility;

/*!
 @property      severity
 @abstract      Returns the syslog message's severity.
 @discussion    The value of this property is MTSyslogMessageSeverity and the
                default value is MTSyslogMessageSeverityInformational.
*/
@property (nonatomic, assign, readonly) MTSyslogMessageSeverity severity;

/*!
 @property      version
 @abstract      Returns the syslog message's version.
 @discussion    The value of this property is an unsigned integer and is always 1.
*/
@property (nonatomic, assign, readonly) NSUInteger version;

/*!
 @property      timeStamp
 @abstract      The syslog message's timestamp.
 @discussion    The value of this property is NSDate. If not set, the current date is used
                when composing the syslog message.
*/
@property (nonatomic, strong, readwrite) NSDate *timeStamp;

/*!
 @property      hostName
 @abstract      Returns the syslog message's host name.
 @discussion    The value of this property is NSString. If not specified
                the host name is set automatically.
*/
@property (nonatomic, strong, readonly) NSString *hostName;

/*!
 @property      appName
 @abstract      Returns the syslog message's app name.
 @discussion    The value of this property is NSString. If not set, or set to an empty string,
                the app name set automatically.
*/
@property (nonatomic, strong, readonly) NSString *appName;

/*!
 @property      procID
 @abstract      Returns the syslog message's process id.
 @discussion    The value of this property is NSString. If not set, or set to an empty string,
                the app name set automatically.
*/
@property (nonatomic, strong, readonly) NSString *procID;

/*!
 @property      messageID
 @abstract      Returns the syslog message's message id.
 @discussion    The value of this property is NSString.
*/
@property (nonatomic, strong, readonly) NSString *messageID;

/*!
 @property      structuredData
 @abstract      The syslog message's structured data.
 @discussion    The value of this property is MTSyslogMessageStructuredData, may be nil.
*/
@property (nonatomic, strong, readwrite) MTSyslogMessageStructuredData *structuredData;

/*!
 @property      eventMessage
 @abstract      The syslog message's event.
 @discussion    The value of this property is NSString, may be nil.
*/
@property (nonatomic, strong, readwrite) NSString *eventMessage;

/*!
 @property      maxSize
 @abstract      Returns the syslog message's maximum message size.
 @discussion    The value of this property is MTSyslogMessageMaxSize.
*/
@property (nonatomic, assign, readonly) MTSyslogMessageMaxSize maxSize;

/*!
 @property      format
 @abstract      Returns the syslog message's format.
 @discussion    The value of this property is MTSyslogMessageFormat.
*/
@property (nonatomic, assign, readonly) MTSyslogMessageFormat format;

/*!
 @method        init
 @abstract      Initializes a MTSyslogMessage object.
 @returns       A MTSyslogMessage object.
*/
- (instancetype)init;

/*!
 @method        setFormat:
 @abstract      Set the receiver's syslog message format.
 @param         format A MTSyslogMessageFormat object specifying the syslog message format of the receiver.
 @discussion    By default, this value is set to MTSyslogMessageFormatNone, which describes an RFC 5424-compliant
                syslog message (typically sent over UDP). When set to MTSyslogMessageFormatNonTransparentFraming or
                MTSyslogMessageFormatOctetCounting, the syslog message conforms to RFC 6587, which describes message
                formats for sending a syslog message over TCP.
*/
- (void)setFormat:(MTSyslogMessageFormat)format;

/*!
 @method        setFacility:
 @abstract      Set the receiver's syslog facility.
 @param         facility A MTSyslogMessageFacility object specifying the syslog facility of the receiver.
 @discussion    A syslog message facility is used to specify the type of program that is logging the message.
                If not specified the facility defaults to MTSyslogMessageFacilityUser.
*/
- (void)setFacility:(MTSyslogMessageFacility)facility;

/*!
 @method        setSeverity:
 @abstract      Set the receiver's syslog severity.
 @param         severity A MTSyslogMessageSeverity object specifying the syslog severity of the receiver.
 @discussion    If not specified the severity defaults to MTSyslogMessageSeverityInformational.
*/
-(void)setSeverity:(MTSyslogMessageSeverity)severity;

/*!
 @method        setHostName:
 @abstract      Set the receiver's host name.
 @param         name A NSString specifying the host name of the receiver.
 @discussion    The host name identifies the machine that originally sent the syslog message. If not specified
                the host name is set automatically.
*/
- (void)setHostName:(NSString *)name;

/*!
 @method        setAppName:
 @abstract      Set the receiver's app name.
 @param         name A NSString specifying the app name of the receiver.
 @discussion    The app name should identify the device or application that originated the message. If not
                specified, the app name is determined from the process name. If you want the app name
                to be empty in the composed syslog message, please set it to  kMTSyslogMessageNilValue.
*/
- (void)setAppName:(NSString*)name;

/*!
 @method        setProcID:
 @abstract      Set the receiver's process id.
 @param         pid A NSString specifying the process id of the receiver.
 @discussion    The process id is a value that is included in the message, having no interoperable meaning,
                except that a change in the value indicates there has been a discontinuity in syslog reporting.
                If not specified, the app name is determined from the process identifier. If you want the process
                id to be empty in the composed syslog message, please set it to  kMTSyslogMessageNilValue.
*/
- (void)setProcID:(NSString*)pid;

/*!
 @method        setMessageID:
 @abstract      Set the receiver's message id.
 @param         msgId A NSString specifying the message id of the receiver.
 @discussion    The message id should identify the type of message.  For example, a firewall might use the
                message id "TCPIN" for incoming TCP traffic and the message id "TCPOUT" for outgoing TCP
                traffic. Messages with the same message id should reflect events of the same semantics. This
                is an optional value.
*/
- (void)setMessageID:(NSString*)msgId;

/*!
 @method        setMaxSize:
 @abstract      Set the receiver's maximum size.
 @param         maxSize A MTSyslogMessageMaxSize object specifying the maximum size of the receiver.
 @discussion    If not specified, the maximum size of a syslog message (header + event message) is set to
                MTSyslogMessageMaxSize480 because this is the minimum maximum message size, a syslog
                server must support.
*/
- (void)setMaxSize:(MTSyslogMessageMaxSize)maxSize;

/*!
 @method        composedMessage
 @abstract      Creates a RFC 5424-compliant syslog message from a MTSyslogMessage object.
 @returns       A NSString containing the syslog message or nil if an error occurred.
*/
- (NSString*)composedMessage;

@end
