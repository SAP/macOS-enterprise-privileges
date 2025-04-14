/*
    MTClientCertificate.m
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

#import "MTClientCertificate.h"
#import <Security/Security.h>

@interface MTClientCertificate ()
@property (nonatomic, copy, readwrite) NSDictionary *dictionaryRepresentation;
@end

@implementation MTClientCertificate

- (instancetype)initWithDistinguishedName:(NSData*)encodedData {
  
    self = [super init];
    
    if (self) {
    
        // parse the encoded data into a dictionary representation
        _dictionaryRepresentation = [self dictionaryRepresentationWithData:encodedData];
        if ([[_dictionaryRepresentation allKeys] count] == 0) { self = nil; }
    }
    
    return self;
}

- (NSDictionary*)dictionaryRepresentationWithData:(NSData*)encodedData
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    
    const char *bytes = [encodedData bytes];
    NSInteger length = [encodedData length];
    NSInteger i = 0;
   
    while (i < length) {
        
        // check for the start of a new Relative Distinguished Name (RDN) component
        if (bytes[i] == 0x31) {
           
            // move past the RDN identifier and the length byte
            i+=2;
           
            // check for the AttributeTypeAndValue sequence
            if (bytes[i] == 0x30) {
               
                // move past the identifier and length
                i+=2;
               
                // parse the AttributeType (OID)
                if (bytes[i] == 0x06) {
                   
                    // move past the OID identifier
                    i++;
                   
                    NSInteger oidLength = bytes[i++];
                    NSString *oid = [self decodeOIDWithBytes:(unsigned char*)&bytes[i] length:oidLength];
                    i += oidLength;
                    
                    // only process the value if we have a valid OID
                    if (oid) {
                        
                        // parse the AttributeValue
                        if (bytes[i] == 0x13 || bytes[i] == 0x0C) {
                            
                            // move past the string identifier
                            i++;
                            
                            NSInteger valueLength = bytes[i++];
                            NSString *value = [[NSString alloc] initWithBytes:&bytes[i]
                                                                       length:valueLength
                                                                     encoding:NSUTF8StringEncoding
                            ];
                            
                            i += valueLength;
                            
                            if (value) { [result setObject:value forKey:oid]; }
                        }
                    }
               }
           }
           
       } else {
           
           // move to the next byte if we
           // didn't find an RDN start
           i++;
       }
    }
       
    return result;
}

- (NSString *)decodeOIDWithBytes:(unsigned char *)bytes length:(NSUInteger)length
{
    if (length < 2) { return nil; }
   
    NSMutableString *oidString = [[NSMutableString alloc] init];
        
    // first byte determines the first two parts of the OID, so we have
    // to split it. therefore we have to divide the value by 40 to get
    // the first value and the rest of this division is our second value.
    unsigned char firstByte = bytes[0];
    [oidString appendFormat:@"%u.%u", firstByte / 40, firstByte % 40];
        
    // decoding  rest of the OID. starting with the second
    // byte as we already handled the first byte
    unsigned int value = 0;
    
    for (int i = 1; i < length; i++) {
        
        value = (value << 7) | (bytes[i] & 0x7F);
        
        if (!(bytes[i] & 0x80)) {
            [oidString appendFormat:@".%u", value];
            value = 0;
        }
    }
    
    return oidString;
}

- (SecIdentityRef)matchingIdentityWithSecItems:(NSArray*)secItems
{
    SecIdentityRef matchedIdentity = NULL;
    
    // check if _dictionaryRepresentation is empty
    if ([_dictionaryRepresentation count] == 0) {
        
        return NULL;
    }
    
    // sort the SecItems by creation date
    NSArray *sortedSecItems = [self identitiesSortedByCreationDate:secItems];
        
    for (id aSecItem in sortedSecItems) {
        
        // ensure the item is a SecIdentityRef
        if (CFGetTypeID((CFTypeRef)aSecItem) == SecIdentityGetTypeID()) {
            
            // extract the certificate from the identity reference
            SecCertificateRef certRef = NULL;
            SecIdentityRef identityRef = (__bridge SecIdentityRef)aSecItem;
            OSStatus status = SecIdentityCopyCertificate(identityRef, &certRef);
            
            if (status == errSecSuccess && certRef) {
                
                const void *keys[] = { kSecOIDX509V1IssuerName };
                CFArrayRef keySelection = CFArrayCreate(NULL, keys , sizeof(keys)/sizeof(keys[0]), &kCFTypeArrayCallBacks);
                
                NSDictionary *values = CFBridgingRelease(SecCertificateCopyValues(certRef, keySelection, NULL));
                CFRelease(keySelection);
                
                if (values) {
                    
                    NSDictionary *issuerDict = [values objectForKey:(__bridge NSString *)kSecOIDX509V1IssuerName];
                    NSArray *valArray = [issuerDict objectForKey:(__bridge NSString *)kSecPropertyKeyValue];
                    
                    BOOL isMatching = YES;
                    
                    for (NSString *aKey in _dictionaryRepresentation) {

                        NSString *expectedValue = [_dictionaryRepresentation objectForKey:aKey];
                        NSString *actualValue = [self stringValueForLabel:aKey inValuesArray:valArray];
                        
                        if (![expectedValue isEqualToString:actualValue]) {
                            
                            isMatching = NO;
                            break;
                        }
                    }
                    
                    if (isMatching) {

                        matchedIdentity = identityRef;
                        break;
                    }
                }
            }
        }
    }

    return matchedIdentity;
}

// helper method to extract the string value for a
// given label from certificate values array
- (NSString*)stringValueForLabel:(NSString*)label inValuesArray:(NSArray<NSDictionary*>*)array
{
    NSString *returnValue = nil;
    
    for (NSDictionary *aDict in array) {
        
        NSString *valueLabel = [aDict objectForKey:(NSString*)kSecPropertyKeyLabel];

        if ([valueLabel isEqualToString:label]) {
            returnValue = [aDict objectForKey:(NSString*)kSecPropertyKeyValue];
        }
    }
    
    return returnValue;
}

// sort identities by creation date (most recent first)
- (NSArray*)identitiesSortedByCreationDate:(NSArray *)secItems
{
    NSMutableArray *sortedSecItems = [NSMutableArray arrayWithArray:secItems];

    [sortedSecItems sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
      
        // extract the certificate from the identity reference
        SecIdentityRef identity1 = (__bridge SecIdentityRef)(obj1);
        SecIdentityRef identity2 = (__bridge SecIdentityRef)(obj2);
        SecCertificateRef certRef1 = NULL;
        SecCertificateRef certRef2 = NULL;
        OSStatus status1 = SecIdentityCopyCertificate(identity1, &certRef1);
        OSStatus status2 = SecIdentityCopyCertificate(identity2, &certRef2);
        
        if (status1 != errSecSuccess || status2 != errSecSuccess) {
            
            // if there's an error copying the certificate,
            // we treat the identities as equal
            return NSOrderedSame;
        }
        
        // get the validity not-before date (creation date) from the certificates
        const void *keys[] = { kSecOIDX509V1ValidityNotBefore };
        CFArrayRef keySelection = CFArrayCreate(NULL, keys, sizeof(keys)/sizeof(keys[0]), &kCFTypeArrayCallBacks);
        
        NSDictionary *values1 = CFBridgingRelease(SecCertificateCopyValues(certRef1, keySelection, NULL));
        NSDictionary *values2 = CFBridgingRelease(SecCertificateCopyValues(certRef2, keySelection, NULL));
        CFRelease(keySelection);

        if (values1 && values2) {
            
            NSDictionary *validityDict1 = [values1 objectForKey:(__bridge NSString*)kSecOIDX509V1ValidityNotBefore];
            NSDictionary *validityDict2 = [values2 objectForKey:(__bridge NSString*)kSecOIDX509V1ValidityNotBefore];
            
            // get the dates
            NSTimeInterval interval1 = [[validityDict1 objectForKey:(__bridge NSString*)kSecPropertyKeyValue] doubleValue];
            NSTimeInterval interval2 = [[validityDict2 objectForKey:(__bridge NSString*)kSecPropertyKeyValue] doubleValue];
            NSDate *date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:interval1];
            NSDate *date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:interval2];
            
            
            // compare the dates and sort them descending
            if (date1 && date2) { return [date2 compare:date1]; }
        }
        
        // if either certificate has no valid date,
        // treat them as equal
        return NSOrderedSame;
    }];

    return sortedSecItems;
}

@end
