//
//  DTJSContext.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSContext.h"
#import "DTJSVirtualMachine.h"
#import "DTJSValue.h"
#import "DTJSValue+Internal.h"
#import "DTJSDebug.h"
#include "duktape.h"


@implementation DTJSContext

#pragma mark - intializers

- (instancetype)init{
    @autoreleasepool {
        if(self = [super init]){
            self.virtualMachine = [[[DTJSVirtualMachine alloc] init] autorelease];
            self.dukContext = [self.virtualMachine initialContext];
        }
        return self;
    }
}

- (instancetype)initWithVirtualMachine:(DTJSVirtualMachine *)virtualMachine{
    
    if(self = [super init]){
        if(virtualMachine){
            self.virtualMachine = virtualMachine;
            duk_context *initialContext = [virtualMachine initialContext];
            if(initialContext){
                duk_idx_t thr_idx = duk_push_thread(initialContext);
                self.dukContext = duk_require_context(initialContext, thr_idx);
            }
        }
    }
    return self;
}

#pragma mark - dealloc

- (void)dealloc{
    
    self.virtualMachine = nil;
    self.dukContext = nil;
    [super dealloc];
}

#pragma  mark script eval methods

- (DTJSValue *)evaluateScript:(NSString *)script{
    
    DTJSValue *jsValue = nil;
    if(script){
        duk_push_string(self.dukContext, [script cStringUsingEncoding:NSUTF8StringEncoding]);//[src]
        if (duk_peval(self.dukContext) != 0) {//[... err]
            DTJSDebugLog(@"eval failed");
            const char *error = duk_safe_to_string(self.dukContext, -1);
            jsValue = [DTJSValue valueWithNewErrorFromMessage:[NSString stringWithUTF8String:error] inContext:self];
        } else {//[... res]
            DTJSDebugLog(@"eval successful");
            jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
        }
        duk_pop(self.dukContext);//pop [... res]
    }
    return jsValue;
}

- (DTJSValue *)evaluateScriptInFile:(NSURL *)fileURL{
    
    DTJSValue *jsValue = nil;
    if(fileURL){
        const char *filePath = [[fileURL path] cStringUsingEncoding:NSUTF8StringEncoding];
        if (duk_peval_file(self.dukContext, filePath) != 0) {//[... err]
            DTJSDebugLog(@"eval failed");
            const char *error = duk_safe_to_string(self.dukContext, -1);
            jsValue = [DTJSValue valueWithNewErrorFromMessage:[NSString stringWithUTF8String:error] inContext:self];
        } else {//[... res]
            DTJSDebugLog(@"eval successful");
            jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
        }
        duk_pop(self.dukContext);//pops [... res]
    }
    return jsValue;
}

- (DTJSValue *)evaluateScript:(NSString *)script  withSourceURL:(NSURL *)sourceURL{
    
    DTJSValue *jsValue = nil;
    if(script){
        duk_push_string(self.dukContext, [script cStringUsingEncoding:NSUTF8StringEncoding]);//[... src]
        if(sourceURL){
            const char *sourcePath = [[sourceURL path] cStringUsingEncoding:NSUTF8StringEncoding];
            duk_push_string(self.dukContext, sourcePath);//[... src filename]
            if (duk_pcompile(self.dukContext, 0) != 0) {//[... func]
                DTJSDebugLog(@"compile failed");
                const char *error = duk_safe_to_string(self.dukContext, -1);
                jsValue = [DTJSValue valueWithNewErrorFromMessage:[NSString stringWithUTF8String:error] inContext:self];
            } else {
                DTJSDebugLog(@"compile successful");
                duk_call(self.dukContext, 0);//[... func ] -> [... result ]
                jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
            }
            duk_pop(self.dukContext);//pop result
        }
    }
    return jsValue;
}

- (DTJSValue *)globalObject{
    
    duk_push_global_object(self.dukContext);//[... gbl]
    DTJSValue *jsValue =  [DTJSValue valueWithValAtStackTopInContext:self];
    duk_pop(self.dukContext);//pops [... gbl]
    return jsValue;
}

@end

@implementation DTJSContext (SubscriptSupport)

- (DTJSValue *)objectForKeyedSubscript:(id)key{
    
    return [self globalObject][key];
}

- (void)setObject:(id)object forKeyedSubscript:(NSObject <NSCopying> *)key{
    
    [self globalObject][key] = object;
}

@end

