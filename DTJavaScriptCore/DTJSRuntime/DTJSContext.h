//
//  DTJSContext.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "duk_config.h"

@class DTJSVirtualMachine;
@class DTJSValue;

@interface DTJSContext : NSObject

//TODO: no need to expose this prop
@property (nonatomic, assign) duk_context *dukContext;

@property (readonly, retain) DTJSVirtualMachine *virtualMachine;
@property (readonly, retain) DTJSValue *globalObject;
@property (nonatomic, retain) DTJSValue *exception;
@property (nonatomic, copy) void(^exceptionHandler)(DTJSContext *context, DTJSValue *exception);

+ (DTJSContext *)currentContext;
+ (DTJSValue *)currentThis;

- (instancetype)init;
- (instancetype)initWithVirtualMachine:(DTJSVirtualMachine *)virtualMachine;

//eval code
- (DTJSValue *)evaluateScript:(NSString *)script;
- (DTJSValue *)evaluateScriptInFile:(NSURL *)fileURL;
//global code
- (DTJSValue *)evaluateScript:(NSString *)script  withSourceURL:(NSURL *)sourceURL;

@end

@interface DTJSContext (SubscriptSupport)

- (DTJSValue *)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(NSObject <NSCopying> *)key;

@end
