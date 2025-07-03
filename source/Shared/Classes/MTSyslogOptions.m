/*
    MTSyslogOptions.m
    Copyright 2016-2025 SAP SE
     
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

#import "MTSyslogOptions.h"
#import "Constants.h"

@interface MTSyslogOptions ()
@property (nonatomic, strong, readwrite) NSDictionary *syslogOptions;
@end

@implementation MTSyslogOptions

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    
    if (self) {
        
        _syslogOptions = dict;
    }
    
    return self;
}

- (MTSyslogMessageFacility)logFacility
{
    MTSyslogMessageFacility facility = ([_syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogFacilityKey]) ? [[_syslogOptions valueForKey:kMTDefaultsRemoteLoggingSyslogFacilityKey] intValue] : MTSyslogMessageFacilityAuth;
    
    return facility;
}

- (MTSyslogMessageSeverity)logSeverity
{
    MTSyslogMessageSeverity severity = ([_syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogSeverityKey]) ? [[_syslogOptions valueForKey:kMTDefaultsRemoteLoggingSyslogSeverityKey] intValue] : MTSyslogMessageSeverityInformational;
    
    return severity;
}

- (MTSyslogMessageMaxSize)maxSize
{
    MTSyslogMessageMaxSize size = ([_syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogMaxSizeKey]) ? [[_syslogOptions valueForKey:kMTDefaultsRemoteLoggingSyslogMaxSizeKey] intValue] : 0;
    
    return size;
}

- (MTSyslogMessageFormat)messageFormat
{
    MTSyslogMessageFormat format = ([_syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogFormatKey]) ? [[_syslogOptions valueForKey:kMTDefaultsRemoteLoggingSyslogFormatKey] intValue] : MTSyslogMessageFormatNonTransparentFraming;
    
    return format;
}

- (NSDictionary*)structuredData
{
    NSDictionary *data = [_syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogSDKey];

    return data;
}

- (NSInteger)serverPort
{
    NSInteger port = [[_syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogServerPortKey] integerValue];
    if (port == 0) { port = ([self useTLS]) ? 6514 : 514; }
    
    return port;
}

- (BOOL)useTLS
{
    BOOL tls = [[_syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogUseTLSKey] boolValue];
    
    return tls;
}

@end
