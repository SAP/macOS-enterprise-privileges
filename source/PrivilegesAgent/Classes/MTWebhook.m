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
#import <os/log.h>

@interface MTWebhook ()
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong, readwrite) NSURLSession *session;
@property (nonatomic, strong, readwrite) NSDate *timeStamp;
@end

@implementation MTWebhook

- (instancetype)initWithURL:(NSURL*)url
{
    self = [super init];
    
    if (self) {
        
        _url = url;
        _timeStamp = [NSDate now];
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    
    return self;
}

- (NSDictionary*)dictionaryRepresentation
{
    NSString *expirationDateString = @"";
    NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
    BOOL hasAdminPrivileges = [_privilegesUser hasAdminPrivileges];
    
    if (hasAdminPrivileges && _expirationDate) { expirationDateString = [dateFormatter stringFromDate:_expirationDate]; }

    NSMutableDictionary *dictRep = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    [_privilegesUser userName], kMTWebhookContentKeyUserName,
                                    [NSNumber numberWithBool:hasAdminPrivileges], kMTWebhookContentKeyAdminRights,
                                    expirationDateString, kMTWebhookContentKeyExpiration,
                                    (_reason) ? _reason : @"", kMTWebhookContentKeyReason,
                                    (hasAdminPrivileges) ? kMTWebhookEventTypeGranted : kMTWebhookEventTypeRevoked, kMTWebhookContentKeyEventType,
                                    [MTSystemInfo machineUUID], kMTWebhookContentKeyMachineIdentifier,
                                    [dateFormatter stringFromDate:_timeStamp], kMTWebhookContentKeyTimestamp,
                                    [NSNumber numberWithBool:_delayed], kMTWebhookContentKeyDelayed,
                                    nil
    ];
    
    // add custom data (if available)
    if ([[_customData allKeys] count] > 0) { [dictRep setObject:_customData forKey:kMTWebhookContentKeyCustomData]; }
    
    return dictRep;
}

+ (NSData*)composedDataWithDictionary:(NSDictionary*)dict
{
    NSData *jsonData = nil;
    
    if (dict) {
        
        jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil
        ];
    }
    
    return jsonData;
}

- (NSData*)composedData
{
    NSData *jsonData = [MTWebhook composedDataWithDictionary:[self dictionaryRepresentation]];
    
    return jsonData;
}

- (void)postData:(NSData*)data completionHandler:(void (^) (NSError *error))completionHandler
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:data];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            
        if (completionHandler) { completionHandler(error); }
    }];
    
    [dataTask resume];
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
    
    if ([[protectionSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodClientCertificate]) {
        
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
            
            for (NSData *distinguishedName in [protectionSpace distinguishedNames]) {
                
                MTClientCertificate *clientCert = [[MTClientCertificate alloc] initWithDistinguishedName:distinguishedName];
                SecIdentityRef matchingIdentityRef = [clientCert matchingIdentityWithSecItems:allSecItems];
                
                if (matchingIdentityRef) {
                    
                    NSURLCredential *credential = [NSURLCredential credentialWithIdentity:matchingIdentityRef
                                                                             certificates:nil
                                                                              persistence:NSURLCredentialPersistenceForSession
                    ];
                    
                    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                    CFRelease(matchingIdentityRef);
                    
                    return;
                }
            }
        }
    }
    
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)dealloc
{
    [_session invalidateAndCancel];
}

@end
