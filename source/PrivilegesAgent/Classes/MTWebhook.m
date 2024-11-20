/*
    MTWebhook.m
    Copyright 2024 SAP SE
     
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

#import "MTWebhook.h"
#import "MTSystemInfo.h"

@interface MTWebhook ()
@property (nonatomic, strong, readwrite) NSURL *url;
@end

@implementation MTWebhook

- (instancetype)initWithURL:(NSURL*)url
{
    self = [super init];
    
    if (self) {
        _url = url;
    }
    
    return self;
}


- (void)postToWebhookForUser:(MTPrivilegesUser*)user
                      reason:(NSString*)reason
              expirationDate:(NSDate*)expiration
           completionHandler:(void (^) (NSError *error))completionHandler
{
    NSString *expirationDateString = @"";
    NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
    
    if ([user hasAdminPrivileges] && expiration) {
        expirationDateString = [dateFormatter stringFromDate:expiration];
    }

    NSDictionary *jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:
                              [user userName], @"user",
                              [NSNumber numberWithBool:[user hasAdminPrivileges]], @"admin",
                              expirationDateString, @"expires",
                              (reason) ? reason : @"", @"reason",
                              [MTSystemInfo machineUUID], @"machine",
                              [dateFormatter stringFromDate:[NSDate now]], @"timestamp",
                              nil
    ];
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict
                                                       options:NSJSONWritingSortedKeys
                                                         error:&error
    ];
    
    if (!error) {
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:jsonData];
        
        NSURLSessionDataTask* dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                
            if (completionHandler) { completionHandler(error); }
        }];
        
        [dataTask resume];
        
    } else {
        
        if (completionHandler) { completionHandler(error); }
    }
}

@end
