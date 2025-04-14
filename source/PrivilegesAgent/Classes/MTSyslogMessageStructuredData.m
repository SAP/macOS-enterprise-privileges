/*
    MTSyslogMessageStructuredData.m
    Copyright 2020-2025 SAP SE

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

#import "MTSyslogMessageStructuredData.h"

@interface MTSyslogMessageStructuredData ()
@property (nonatomic, strong, readwrite) NSMutableDictionary *structuredData;
@end

@implementation MTSyslogMessageStructuredData

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _structuredData = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)addStructuredData:(NSDictionary*)data withID:(NSString*)sdID
{
    [_structuredData setObject:data forKey:sdID];
}

- (void)structuredDataWithDictionary:(NSDictionary*)data
{
    if ([data isKindOfClass:[NSDictionary class]]) {
        
        _structuredData = [NSMutableDictionary dictionaryWithDictionary:data];
    }
}

- (NSString*)composedString
{
    NSString *returnValue = nil;
    
    if ([_structuredData count] > 0) {
        
        NSMutableArray *sdElements = [[NSMutableArray alloc] init];
        
        [_structuredData enumerateKeysAndObjectsUsingBlock:^(id sdID, id params, BOOL *stop) {
            
            if ([sdID isKindOfClass:[NSString class]] && [params isKindOfClass:[NSDictionary class]]) {
                
                NSMutableString *sdElement = [NSMutableString stringWithFormat:@"[%@ ", sdID];
                NSMutableArray *paramStrings = [[NSMutableArray alloc] init];
                
                [params enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
                    
                    if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                        
                        NSString *cleanedKey = [self cleanedKeyWithString:key];
                        NSString *escapedValue = [self escapedValueWithString:value];
                        [paramStrings addObject:[NSString stringWithFormat:@"%@=\"%@\"", cleanedKey, escapedValue]];
                    }
                }];
                
                [sdElement appendString:[paramStrings componentsJoinedByString:@" "]];
                [sdElement appendString:@"]"];
                
                [sdElements addObject:sdElement];
            }
        }];

        returnValue = [sdElements componentsJoinedByString:@""];
    }
    
    return returnValue;
}

- (NSString*)escapedValueWithString:(NSString*)originalString
{
    NSString *escapedString = [originalString stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    escapedString = [escapedString stringByReplacingOccurrencesOfString:@"]" withString:@"\\]"];
    
    return escapedString;
}

- (NSString*)cleanedKeyWithString:(NSString*)originalString
{
    NSMutableCharacterSet *invalidCharacters = [[NSMutableCharacterSet alloc] init];
    [invalidCharacters addCharactersInString:@"= ]\""];
    
    NSString *cleanedString = [[originalString componentsSeparatedByCharactersInSet:invalidCharacters] componentsJoinedByString:@""];
    cleanedString = [MTSyslogMessageStructuredData cleanString:cleanedString maximumLength:32];
    
    return cleanedString;
}

+ (NSString*)cleanString:(NSString*)originalString maximumLength:(NSInteger)maxLength
{
    NSString *cleanedString = nil;
    
    if (originalString) {

        // convert string to US-ASCII
        NSData *stringData = [originalString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        cleanedString = [[NSString alloc] initWithData:stringData encoding:NSASCIIStringEncoding];
        
        // remove all non-prinable characters
        cleanedString = [cleanedString stringByReplacingOccurrencesOfString:@"[^\x21-\x7E]"
                                                                 withString:@""
                                                                    options:NSRegularExpressionSearch
                                                                      range:NSMakeRange(0, [originalString length])];

        // make sure the string does not exceed the allowed length
        if (maxLength > 0 && [cleanedString length] > maxLength) {
            cleanedString = [cleanedString substringToIndex:(maxLength - 1)];
        }
    }
    
    return cleanedString;
}

@end
