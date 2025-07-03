/*
    MTClientCertificate.m
    Copyright 2016-2025 SAP SE

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
*/

#import "MTClientCertificate.h"
#import <Security/Security.h>

@interface MTClientCertificate ()
@property (nonatomic, copy, readwrite) NSArray *decodedDN;
@end

@implementation MTClientCertificate

- (instancetype)initWithDistinguishedName:(NSData*)encodedData {
    
    self = [super init];
    
    if (self) {
        
        // parse the encoded data into an array of dictionaries
        _decodedDN = [self decodedDNWithData:encodedData];
        if ([_decodedDN count] == 0) { self = nil; }
    }
    
    return self;
}

- (NSArray<NSDictionary*>*)decodedDNWithData:(NSData*)encodedData
{
    if (!encodedData) { return nil; }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];

    const char *bytes = [encodedData bytes];
    NSUInteger length = [encodedData length];
    NSUInteger index = 0;

    // must start with a AttributeTypeAndValue sequence
    if (bytes[index++] != 0x30) { return nil; }
    
    NSUInteger sequenceLength = [self decodeLengthFromBytes:bytes
                                                  maxLength:length
                                                      index:&index
    ];
    NSUInteger endOfSequence = index + sequenceLength;

    // process relative distinguished name (RDN) components
    while (index < endOfSequence) {
        
        if (bytes[index++] != 0x31) { break; } // SET
        
        NSUInteger setLength = [self decodeLengthFromBytes:bytes maxLength:length index:&index];
        NSUInteger endOfSet = index + setLength;

        // process AttributeTypeAndValue within this RDN
        while (index < endOfSet) {
            
            if (bytes[index++] != 0x30) { break; } // start of a AttributeTypeAndValue sequence
            
            NSUInteger atavLength = [self decodeLengthFromBytes:bytes maxLength:length index:&index];
            NSUInteger endOfATAV = index + atavLength;
            
            // parse the AttributeType (OID)
            if (index < endOfATAV && bytes[index++] == 0x06) {
                
                if (index >= endOfATAV) { break; }
                
                NSUInteger oidLength = [self decodeLengthFromBytes:bytes maxLength:length index:&index];
                if (index + oidLength > endOfATAV) { break; }
                
                NSString *oid = [self decodeOIDWithBytes:&bytes[index] length:oidLength];
                index += oidLength;
                
                // only process the value if we have a valid OID
                if (oid && index < endOfATAV) {
                    
                    // parse the AttributeValue
                    UInt8 valueTag = bytes[index++];
                    
                    if (index < endOfATAV) {
                        
                        NSUInteger valueLength = [self decodeLengthFromBytes:(const char *)bytes maxLength:length index:&index];
                        if (index + valueLength > endOfATAV) { break; }
                        
                        NSStringEncoding encoding = 0;
                        
                        switch (valueTag) {
                                
                            case 0x13:
                            case 0x14:
                                
                                // Printable/Teletex
                                encoding = NSASCIIStringEncoding;
                                break;
                                
                            case 0x1E:
                                
                                // BMP
                                encoding = NSUTF16BigEndianStringEncoding;
                                break;
                                
                            case 0x0C:
                                
                                // UTF8
                                encoding = NSUTF8StringEncoding;
                                break;
                                
                            case 0x16:
                            case 0x22:
                                
                                // IA5 or IA5String
                                encoding = NSASCIIStringEncoding;
                                break;
                        }
                        
                        if (encoding > 0) {
                            
                            NSData *valueData = [NSData dataWithBytes:&bytes[index] length:valueLength];
                            NSString *value = [[NSString alloc] initWithData:valueData encoding:encoding];
                            
                            if (value) { [result addObject:[NSDictionary dictionaryWithObject:value forKey:oid]]; }
                            
                            index += valueLength;
                        }
                    }
                }
            }
        }
    }
    
    return result;
}

- (NSInteger)decodeLengthFromBytes:(const char *)bytes maxLength:(NSUInteger)maxLength index:(NSUInteger *)index
{
    if (*index >= maxLength) { return 0; }
    
    UInt8 first = bytes[(*index)++];
    
    if ((first & 0x80) == 0) { return first; }

    UInt8 numBytes = first & 0x7F;
    if (numBytes == 0 || *index + numBytes > maxLength) { return 0; }
    
    NSInteger length = 0;
    
    for (int i = 0; i < numBytes; i++) {
        length = (length << 8) | ((UInt8)bytes[(*index)++]);
    }
    
    return length;
}

- (NSString *)decodeOIDWithBytes:(const char *)bytes length:(NSUInteger)length
{
    if (length < 1) { return nil; }

    NSMutableString *oidString = [[NSMutableString alloc] init];
    
    // first byte determines the first two parts of the OID, so we have
    // to split it. therefore we have to divide the value by 40 to get
    // the first value and the rest of this division is our second value.
    unsigned char first = bytes[0];
    [oidString appendFormat:@"%u.%u", first / 40, first % 40];

    // decoding  rest of the OID. starting with the second
    // byte as we already handled the first byte
    NSUInteger i = 1;
    
    while (i < length) {
        
        UInt64 value = 0;
        BOOL continueFlag;
        
        do {
            value = (value << 7) | (bytes[i] & 0x7F);
            continueFlag = (bytes[i] & 0x80) != 0;
            i++;
            
        } while (i < length && continueFlag);
        
        [oidString appendFormat:@".%llu", value];
    }

    return oidString;
}

- (SecIdentityRef)matchingIdentityWithSecItems:(NSArray*)secItems
{
    if ([_decodedDN count] == 0) { return NULL; }

    SecIdentityRef matchedIdentity = NULL;
    NSArray *sortedSecItems = [self identitiesSortedByCreationDate:secItems];

    for (id aSecItem in sortedSecItems) {
        
        // ensure the item is a SecIdentityRef
        if (CFGetTypeID((CFTypeRef)aSecItem) == SecIdentityGetTypeID()) {
            
            SecIdentityRef identityRef = (__bridge SecIdentityRef)aSecItem;
            NSArray *valArray = [self issuerNamesWithIdentity:identityRef];
            
            if ([valArray count] > 0) {
                
                BOOL isMatching = YES;
                
                for (NSDictionary *rdn in _decodedDN) {
                    
                    NSArray *matchingIdentities = nil;
                    NSString *oidString = [[rdn allKeys] firstObject];
                    NSString *oidValue = [rdn objectForKey:oidString];
                    
                    if (oidString && oidValue) {
                        
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K == %@",
                                                  kSecPropertyKeyLabel,
                                                  oidString,
                                                  kSecPropertyKeyValue,
                                                  oidValue
                        ];

                        matchingIdentities = [valArray filteredArrayUsingPredicate:predicate];
                    }
                    
                    if ([matchingIdentities count] == 0) {
                        
                        isMatching = NO;
                        break;
                    }
                }

                if (isMatching) {
                    matchedIdentity = (SecIdentityRef)CFRetain(identityRef);
                    break;
                }
            }
        }
    }

    return matchedIdentity;
}

- (NSArray<NSDictionary*>*)issuerNamesWithIdentity:(SecIdentityRef)identityRef
{
    NSMutableArray *result = nil;
    
    if (!identityRef) { return nil; }
    
    // extract the certificate from the identity reference
    SecCertificateRef certRef = NULL;
    OSStatus status = SecIdentityCopyCertificate(identityRef, &certRef);
    
    if (status == errSecSuccess && certRef) {
        
        NSArray *keys = [NSArray arrayWithObject:(__bridge id)kSecOIDX509V1IssuerName];
        
        NSDictionary *certValues = CFBridgingRelease(SecCertificateCopyValues(
                                                                              certRef,
                                                                              (__bridge CFArrayRef)keys,
                                                                              NULL
                                                                              )
                                                     );
        
        if (certValues) {
            
            NSDictionary *issuerDict = [certValues objectForKey:(__bridge NSString *)kSecOIDX509V1IssuerName];
            
            if (issuerDict) {

                result = [[NSMutableArray alloc] init];
                
                // get the actual value
                NSArray<NSDictionary*> *valArray = [issuerDict objectForKey:(__bridge NSString *)kSecPropertyKeyValue];
                
                for (NSDictionary *oid in valArray) {
                    
                    NSString *objectType = [oid objectForKey:(__bridge NSString *)kSecPropertyKeyType];
                    
                    if ([objectType isEqualToString:(NSString*)kSecPropertyTypeSection]) {
                        
                        NSArray *fields = [oid objectForKey:(NSString*)kSecPropertyKeyValue];
                        
                        for (NSDictionary *field in fields) {
                            
                            NSString *label = [field objectForKey:(NSString*)kSecPropertyKeyLabel];
                            id value = [field objectForKey:(NSString*)kSecPropertyKeyValue];
                            
                            if (label && value) {
                                
                                [result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   label, (NSString*)kSecPropertyKeyLabel,
                                                   value, (NSString*)kSecPropertyKeyValue,
                                                   nil
                                                  ]
                                ];
                            }
                        }
                        
                    } else {
                        
                        NSString *label = [oid objectForKey:(NSString*)kSecPropertyKeyLabel];
                        id value = [oid objectForKey:(NSString*)kSecPropertyKeyValue];
                        
                        if (label && value) {
                            
                            [result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                               label, (NSString*)kSecPropertyKeyLabel,
                                               value, (NSString*)kSecPropertyKeyValue,
                                               nil
                                              ]
                            ];
                        }
                    }
                }
            }
        }
    }
    
    return result;
}

// sort identities by creation date (most recent first)
- (NSArray*)identitiesSortedByCreationDate:(NSArray *)secItems
{
    NSMutableArray *sortedSecItems = [NSMutableArray arrayWithArray:secItems];

    [sortedSecItems sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
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
