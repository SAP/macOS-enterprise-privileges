/*
    MTPrivilegesLoggingConfiguration.m
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

#import "MTPrivilegesLoggingConfiguration.h"
#import "Constants.h"

@interface MTPrivilegesLoggingConfiguration ()
@property (nonatomic, strong, readwrite) NSDictionary *remoteLoggingConfiguration;
@end

@implementation MTPrivilegesLoggingConfiguration

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    
    if (self) {
        
        _remoteLoggingConfiguration = dict;
    }
    
    return self;
}

- (NSString*)serverType
{
    NSString *type = [_remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingServerTypeKey];
    
    if (type) { type = [type lowercaseString]; }
    
    return type;
}

- (NSString*)serverAddress
{
    NSString *address = [_remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingServerAddressKey];
        
    return address;
}

- (NSDictionary*)webhookCustomData
{
    NSDictionary *customData = [_remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingWebhookDataKey];
    
    return customData;
}

- (MTSyslogOptions*)syslogOptions
{
    MTSyslogOptions *options = [[MTSyslogOptions alloc] initWithDictionary:[_remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingSyslogOptionsKey]];
    
    return options;
}

- (BOOL)queueUnsentEvents
{
    BOOL queue = [[_remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingQueueEventsKey] boolValue];
    
    return queue;
}

- (NSInteger)queuedEventsMax
{
    NSInteger returnValue = kMTQueuedEventsMaxDefault;
    
    if ([_remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingQueuedEventsMaxKey]) {
            
        NSInteger maximumValue = [[_remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingQueuedEventsMaxKey] integerValue];
        if (maximumValue >= 0) { returnValue = maximumValue; }
    }
    
    return returnValue;
}

@end
