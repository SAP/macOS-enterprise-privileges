/*
MTResolve.m
Copyright 2020 SAP SE

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

#import "MTResolve.h"
#import <arpa/inet.h>
#import <netdb.h>

@implementation MTResolve

static void stopResolve(CFHostRef hostRef)
{
    if (hostRef) {
        CFHostSetClient(hostRef, NULL , NULL);
        CFHostCancelInfoResolution(hostRef, kCFHostAddresses);
        CFHostUnscheduleFromRunLoop(hostRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        hostRef = nil;
    }
}

static void resolveDidFinish(CFHostRef hostRef, CFHostInfoType typeInfo, const CFStreamError *streamError, void *info)
{
    NSError *error = nil;
    NSString *errorMsg = nil;
    NSMutableArray *addresses;
    void (^completionHandler)(NSArray* ipAddresses, NSError* error) = (__bridge void (^)(NSArray*__strong, NSError *__strong))info;
    
    if (streamError->domain || streamError->error) {
        errorMsg = @"Name resolution failed";

    } else {
        
        Boolean hasBeenResolved;
        CFArrayRef addressesRef = CFHostGetAddressing(hostRef, &hasBeenResolved);
        
        if (hasBeenResolved) {
            
            addresses = [[NSMutableArray alloc] init];
            CFIndex numAddresses = CFArrayGetCount(addressesRef);
            for (CFIndex currentIndex = 0; currentIndex < numAddresses; currentIndex++) {
                struct sockaddr *address = (struct sockaddr *)CFDataGetBytePtr(CFArrayGetValueAtIndex(addressesRef, currentIndex));
            
                if (address) {
                    char ipAddress[INET6_ADDRSTRLEN];
                    int error = getnameinfo(address, address->sa_len, ipAddress, INET6_ADDRSTRLEN, NULL, 0, NI_NUMERICHOST);
            
                    if (error == NETDB_SUCCESS) {
                        [addresses addObject:[NSString stringWithCString:ipAddress encoding:NSASCIIStringEncoding]];
                    }
                }
            }
                        
        } else {
            errorMsg = @"Host could not be resolved";
        }
    }
    
    if (errorMsg) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
    }

    if (completionHandler) { completionHandler(addresses, error); }
    stopResolve(hostRef);
}

- (void)resolveHostname:(NSString*)hostName completionHandler:(nonnull void (^)(NSArray * _Nullable, NSError * _Nullable))completionHandler
{
    if (hostName && completionHandler) {
        CFHostClientContext context = {0, (__bridge_retained void*)(completionHandler), NULL, NULL, NULL};
        CFHostRef hostRef = CFHostCreateWithName(NULL, (__bridge CFStringRef)hostName);
        CFHostSetClient(hostRef, resolveDidFinish, &context);
        CFHostScheduleWithRunLoop(hostRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

        CFStreamError streamError;
        Boolean success = CFHostStartInfoResolution(hostRef, kCFHostAddresses, &streamError);

        if (!success) {
            NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:@"Could not start name resolution", NSLocalizedDescriptionKey, nil];
            NSError *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
            
            completionHandler(nil, error);
            stopResolve(hostRef);
        }
    }
}

@end
