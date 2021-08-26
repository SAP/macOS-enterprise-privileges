/*
     File: HelperTool.m
 Abstract: The main object in the helper tool.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "HelperTool.h"

#import "Common.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>

@interface HelperTool () <NSXPCListenerDelegate, HelperToolProtocol>

@property (atomic, strong, readwrite) NSXPCListener *    listener;

@end

@implementation HelperTool

- (id)init
{
    self = [super init];
    if (self != nil) {
        // Set up our XPC listener to handle requests on our Mach service.
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
        self->_listener.delegate = self;
    }
    return self;
}

- (void)run
{
    // Tell the XPC listener to start processing requests.

    [self.listener resume];
    
    // Run the run loop forever.
    
    [[NSRunLoop currentRunLoop] run];
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
    // Called by our XPC listener when a new connection comes in.  We configure the connection
    // with our protocol and ourselves as the main object.
{
    assert(listener == self.listener);
    #pragma unused(listener)
    assert(newConnection != nil);

    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    
    return YES;
}

- (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command
    // Check that the client denoted by authData is allowed to run the specified command. 
    // authData is expected to be an NSData with an AuthorizationExternalForm embedded inside.
{
    #pragma unused(authData)
    NSError *                   error;
    OSStatus                    err;
    OSStatus                    junk;
    AuthorizationRef            authRef;

    assert(command != nil);
    
    authRef = NULL;

    // First check that authData looks reasonable.
    
    error = nil;
    if ( (authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm)) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    // Create an authorization ref from that the external form data contained within.
    
    if (error == nil) {
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        // Authorize the right associated with the command.
        
        if (err == errAuthorizationSuccess) {
            AuthorizationItem   oneRight = { NULL, 0, NULL, 0 };
            AuthorizationRights rights   = { 1, &oneRight };

            oneRight.name = [[Common authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);
            
            err = AuthorizationCopyRights(
                authRef,
                &rights,
                NULL,
                kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                NULL
            );
        }
        if (err != errAuthorizationSuccess) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
        }
    }

    if (authRef != NULL) {
        junk = AuthorizationFree(authRef, 0);
        assert(junk == errAuthorizationSuccess);
    }

    return error;
}

- (BOOL)isValidLicenseKey:(NSString *)licenseKey
    // Check that the license key is valid.  There are two things to note here.  The first 
    // is that I could have just passed an NSUUID across the NSXPCConnection, because 
    // NSUUID supports the NSSecureCoding protocol.  I didn't do that, however, because 
    // I wanted to make an important point, and that brings us to our second thing.  When 
    // you're writing a privileged helper tool you have to make sure that all the data 
    // passed to you from the client is valid.  NSXPCConnection does a lot of checking of 
    // this for you, but you still have to check your app-specific requirements.
    //
    // In this case the app-specific requirements are very simple--is the value not nil and 
    // can it be parsed as a UUID string--but in a complex app they might be a lot more complex.  
    // Regardless, it's vital that you do this checking for all data coming from untrusted 
    // sources.
{
    BOOL        success;
    NSUUID *    uuid;
    
    success = (licenseKey != nil);
    if (success) {
        uuid = [[NSUUID alloc] initWithUUIDString:licenseKey];
        success = (uuid != nil);
    }
    
    return success;
}

#pragma mark * HelperToolProtocol implementation

// IMPORTANT: NSXPCConnection can call these methods on any thread.  It turns out that our 
// implementation of these methods is thread safe but if that's not the case for your code 
// you have to implement your own protection (for example, having your own serial queue and 
// dispatching over to it).

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *))reply
    // Part of the HelperToolProtocol.  Not used by the standard app (it's part of the sandboxed 
    // XPC service support).  Called by the XPC service to get an endpoint for our listener.  It then 
    // passes this endpoint to the app so that the sandboxed app can talk us directly.
{
    reply([self.listener endpoint]);
}

- (void)getVersionWithReply:(void(^)(NSString * version))reply
    // Part of the HelperToolProtocol.  Returns the version number of the tool.  Note that never
    // requires authorization.
{
    // We specifically don't check for authorization here.  Everyone is always allowed to get
    // the version of the helper tool.
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}

static NSString * kLicenseKeyDefaultsKey = @"licenseKey";

- (void)readLicenseKeyAuthorization:(NSData *)authData withReply:(void(^)(NSError * error, NSString * licenseKey))reply
    // Part of the HelperToolProtocol.  Gets the current license key from the defaults database.
{
    NSString *  licenseKey;
    NSError *   error;
    
    error = [self checkAuthorization:authData command:_cmd];
    if (error == nil) {
        licenseKey = [[NSUserDefaults standardUserDefaults] stringForKey:kLicenseKeyDefaultsKey];
    } else {
        licenseKey = nil;
    }

    reply(error, licenseKey);
}

- (void)writeLicenseKey:(NSString *)licenseKey authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
    // Part of the HelperToolProtocol.  Saves the license key to the defaults database.
{
    NSError *   error;
    
    error = nil;
    if ( ! [self isValidLicenseKey:licenseKey] ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    if (error == nil) {
        error = [self checkAuthorization:authData command:_cmd];
    }
    if (error == nil) {
        [[NSUserDefaults standardUserDefaults] setObject:licenseKey forKey:kLicenseKeyDefaultsKey];
    }

    reply(error);
}

- (void)bindToLowNumberPortAuthorization:(NSData *)authData withReply:(void(^)(NSError * error, NSFileHandle * ipv4Handle, NSFileHandle * ipv6Handle))reply
    // Part of the HelperToolProtocol.  Binds two sockets (TCPv4 and TCPv6) to port 80 and returns
    // a reference to them to the client.  Note that we just create and bind the sockets and nothing 
    // else.  This minimizes the amount of code that we have to run with elevated privileges.  We 
    // returns these sockets to the app, which then listens for, accepts, and manages incoming 
    // connections.
{
    NSError *       error;
    int             fd4;
    int             fd6;
    NSFileHandle *  ipv4Handle;
    NSFileHandle *  ipv6Handle;
    int             junk;

    fd4 = -1;
    fd6 = -1;
    ipv4Handle = nil;
    ipv6Handle = nil;

    error = [self checkAuthorization:authData command:_cmd];
    if (error == nil) {
        BOOL                    success;
        struct sockaddr_in      addr4;
        struct sockaddr_in6     addr6;
        static const int kOne = 1;

        memset(&addr4, 0, sizeof(addr4));
        addr4.sin_family = (sa_family_t) AF_INET;
        addr4.sin_len  = sizeof(addr4);
        addr4.sin_port = htons(80);

        memset(&addr6, 0, sizeof(addr6));
        addr6.sin6_family = (sa_family_t) AF_INET6;
        addr6.sin6_len  = sizeof(addr6);
        addr6.sin6_port = htons(80);
        
        fd4 = socket(AF_INET, SOCK_STREAM, 0);
        success = fd4 >= 0;
        success = success && ( setsockopt(fd4, SOL_SOCKET, SO_REUSEADDR, &kOne, sizeof(kOne)) == 0 );
        success = success && ( bind(fd4, (const struct sockaddr *) &addr4, addr4.sin_len) == 0 );
        if (success) {
            fd6 = socket(AF_INET6, SOCK_STREAM, 0);
            success = fd6 >= 0;
        }
        success = success && ( setsockopt(fd6, SOL_SOCKET, SO_REUSEADDR, &kOne, sizeof(kOne)) == 0 );
        success = success && ( bind(fd6, (const struct sockaddr *) &addr6, addr6.sin6_len) == 0 );
        
        if ( ! success ) {
            error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        } else {
            ipv4Handle = [[NSFileHandle alloc] initWithFileDescriptor:fd4 closeOnDealloc:NO];
            ipv6Handle = [[NSFileHandle alloc] initWithFileDescriptor:fd6 closeOnDealloc:NO];
        }
    }
    
    assert( (error == nil) == (ipv4Handle != nil) );
    assert( (error == nil) == (ipv6Handle != nil) );
    
    reply(error, ipv4Handle, ipv6Handle);
    
    if (fd4 != -1) {
        junk = close(fd4);
        assert(junk == 0);
    }
    if (fd6 != -1) {
        junk = close(fd6);
        assert(junk == 0);
    }
}

@end
