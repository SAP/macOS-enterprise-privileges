/*
    MTChecksum.m
    Copyright 2016-2026 SAP SE
     
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

#import "MTChecksum.h"

@implementation MTChecksum

+ (NSString*)sha256ChecksumWithPath:(NSString*)path
{
    NSMutableString *checksumString = [[NSMutableString alloc] init];
    
    if (path) {
        
        NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
        
        if (handle) {
            
            BOOL done = NO;
            
            CC_SHA256_CTX sha;
            CC_SHA256_Init(&sha);
            
            while (!done) {
                
                NSError *error = nil;
                NSData *fileData = [handle readDataUpToLength:4096 error:&error];
                
                if (error) {
                    
                    break;
                    
                } else {
                    
                    CC_SHA256_Update(&sha, [fileData bytes], (unsigned int)[fileData length]);
                    if ([fileData length] == 0 ) { done = YES; }
                }
            }
            
            if (done) {
                
                unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                CC_SHA256_Final(digest, &sha);
                
                for (int i = 0; i < sizeof(digest); ++i) {
                    [checksumString appendFormat:@"%02x", digest[i]];
                }
            }
        }
    }
    
    return checksumString;
}

@end
