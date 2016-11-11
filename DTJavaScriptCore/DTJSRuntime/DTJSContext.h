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

@property (nonatomic, retain) DTJSVirtualMachine *virtualMachine;
@property (nonatomic, assign) duk_context *dukContext;

- (instancetype)init;
- (instancetype)initWithVirtualMachine:(DTJSVirtualMachine *)virtualMachine;

/* eval code */
- (DTJSValue *)evaluateScript:(NSString *)script;
- (DTJSValue *)evaluateScriptInFile:(NSURL *)fileURL;
/* global code */
- (DTJSValue *)evaluateScript:(NSString *)script  withSourceURL:(NSURL *)sourceURL;

@property (readonly, retain) DTJSValue *globalObject;
@property (nonatomic, strong) DTJSValue *exception;
@property (nonatomic, copy) void(^exceptionHandler)(DTJSContext *context, DTJSValue *exception);

@end


@interface DTJSContext (SubscriptSupport)

- (DTJSValue *)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(NSObject <NSCopying> *)key;

@end
