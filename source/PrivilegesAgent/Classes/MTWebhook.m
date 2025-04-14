/*
    MTWebhook.m
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

#import "MTWebhook.h"
#import "MTSystemInfo.h"
#import "Constants.h"
#import "MTClientCertificate.h"

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
                  customData:(NSDictionary*)customData
           completionHandler:(void (^) (NSError *error))completionHandler
{
    NSString *expirationDateString = @"";
    NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
    
    if ([user hasAdminPrivileges] && expiration) { expirationDateString = [dateFormatter stringFromDate:expiration]; }

    NSMutableDictionary *jsonDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     [user userName], @"user",
                                     [NSNumber numberWithBool:[user hasAdminPrivileges]], @"admin",
                                     expirationDateString, @"expires",
                                     (reason) ? reason : @"", @"reason",
                                     ([user hasAdminPrivileges]) ? kMTWebhookEventTypeGranted : kMTWebhookEventTypeRevoked, @"event",
                                     [MTSystemInfo machineUUID], @"machine",
                                     [dateFormatter stringFromDate:[NSDate now]], @"timestamp",
                                     nil
    ];
    
    if ([[customData allKeys] count] > 0) { [jsonDict setObject:customData forKey:@"custom_data"]; }
    
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
        
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                              delegate:self
                                                         delegateQueue:nil
        ];
        NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                
            if (completionHandler) { completionHandler(error); }
            [session finishTasksAndInvalidate];
        }];
        
        [dataTask resume];
        
    } else {
        
        if (completionHandler) { completionHandler(error); }
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    BOOL credentialsFound = NO;
    
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString:NSURLAuthenticationMethodClientCertificate]) {
        
        CFTypeRef items = NULL;
        
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                   (id)kSecClassIdentity, (id)kSecClass,
                                    [NSNumber numberWithBool:YES], (id)kSecReturnRef,
                                    (id)kSecMatchLimitAll, (id)kSecMatchLimit,
                                    nil
        ];
        
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)attrs, &items);
        
        if (status == errSecSuccess && items) {
            
            NSArray *allSecItems = CFBridgingRelease(items);
            
            for (NSData *distinguishedName in [[challenge protectionSpace] distinguishedNames]) {
                                
                MTClientCertificate *clientCert = [[MTClientCertificate alloc] initWithDistinguishedName:distinguishedName];
                SecIdentityRef matchingIdentityRef = [clientCert matchingIdentityWithSecItems:allSecItems];
                
                if (matchingIdentityRef) {
                    
                    NSURLCredential *credential = [NSURLCredential credentialWithIdentity:matchingIdentityRef
                                                                             certificates:nil
                                                                              persistence:NSURLCredentialPersistenceForSession
                    ];
                    
                    credentialsFound = YES;
                    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                                            
                    break;
                }
            }
        }
    }
    
    if (!credentialsFound) { completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil); }
}

@end
