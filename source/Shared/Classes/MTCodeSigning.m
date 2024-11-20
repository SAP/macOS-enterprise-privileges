/*
    MTCodeSigning.h
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

#import "MTCodeSigning.h"

@implementation MTCodeSigning

+ (NSString*)getSigningAuthorityWithError:(NSError**)error
{
    OSStatus result = errSecSuccess;
    SecCodeRef helperCodeRef = NULL;
    NSString *returnValue = nil;
    NSString *errorMsg = nil;
    
    // get our code object
    result = SecCodeCopySelf(kSecCSDefaultFlags, &helperCodeRef);
    
    if (result != errSecSuccess) {
        
        errorMsg = [NSString stringWithFormat:@"Failed to copy code object: %d", result];
        
    } else {
        
        // get our static code
        SecStaticCodeRef staticCodeRef = NULL;
        result = SecCodeCopyStaticCode(helperCodeRef, kSecCSDefaultFlags, &staticCodeRef);
        
        if (result != errSecSuccess) {
            
            errorMsg = [NSString stringWithFormat:@"Failed to get static code object: %d", result];
            
        } else {
            
            // get our own signing information
            CFDictionaryRef signingInfo = NULL;
            result = SecCodeCopySigningInformation(staticCodeRef, kSecCSSigningInformation, &signingInfo);
            
            if (result != errSecSuccess) {
                
                errorMsg = [NSString stringWithFormat:@"Failed to get signing information: %d", result];
                
            } else {
                
                CFArrayRef certChain = (CFArrayRef) CFDictionaryGetValue(signingInfo, kSecCodeInfoCertificates);
                
                if (certChain && CFGetTypeID(certChain) == CFArrayGetTypeID() && CFArrayGetCount(certChain) > 0) {
                    
                    SecCertificateRef issuerCert = (SecCertificateRef) CFArrayGetValueAtIndex(certChain, 0);
                    
                    if (issuerCert) {
                        
                        CFStringRef subjectCN = NULL;
                        SecCertificateCopyCommonName(issuerCert, &subjectCN);
                        if (subjectCN) { returnValue = CFBridgingRelease(subjectCN); }
                    }
                }
            }
            
            if (signingInfo) { CFRelease(signingInfo); }
        }
        
        if (staticCodeRef) { CFRelease(staticCodeRef); }
    }
    
    if (helperCodeRef) { CFRelease(helperCodeRef); }
    
    if (errorMsg && error) {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:100 userInfo:errorDetail];
    }
    
    return returnValue;
}

+ (NSString*)codeSigningRequirementsWithCommonName:(NSString*)commonName
                                  bundleIdentifier:(NSString*)bundleIdentifier
                                     versionString:(NSString*)versionString
{
    NSString *reqString = [NSString stringWithFormat:@"anchor trusted and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"%@\" and info [CFBundleIdentifier] = %@", commonName, versionString, bundleIdentifier];
    
    return reqString;
}

+ (void)sandboxStatusWithCompletionHandler:(void (^)(BOOL isSandboxed, NSError *error))completionHandler
{
    if (completionHandler) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            BOOL isSandboxed = NO;
            NSError *error = nil;
            
            SecCodeRef codeRef = NULL;
            CFDictionaryRef infoDict = NULL;
            CFTypeRef entitlements = NULL;
            
            OSStatus err = SecCodeCopySelf(kSecCSDefaultFlags, &codeRef);
            
            if (err == errSecSuccess) {
                
                err = SecCodeCopySigningInformation(codeRef, (SecCSFlags) kSecCSDynamicInformation, &infoDict);
                
                if (err == errSecSuccess) {
                    
                    if (CFDictionaryGetValueIfPresent(infoDict, kSecCodeInfoEntitlementsDict, &entitlements)) {
                        
                        if (entitlements != NULL && CFDictionaryGetValue(entitlements, CFSTR("com.apple.security.app-sandbox")) != NULL) {
                            
                            isSandboxed = YES;
                        }
                        
                    } else {
                        
                        err = errSecMissingEntitlement;
                    }
                }
            }
            
            if (err != errSecSuccess) { error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]; }
            
            completionHandler(isSandboxed, error);
        });
    }
}

@end
