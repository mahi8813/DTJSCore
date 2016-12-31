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
#import "DTJSValueInternal.h"
#import "DTJSContextInternal.h"
#import "DTJSDebug.h"
#import "duktape.h"

@interface DTJSContext ()

@property (nonatomic, retain) DTJSVirtualMachine *virtualMachine;

@end

@implementation DTJSContext

static DTJSContext *_currentContext = nil;

#pragma mark - intializers

- (instancetype)init{
    @autoreleasepool {
        if(self = [super init]){
            self.virtualMachine = [[[DTJSVirtualMachine alloc] init] autorelease];
            self.dukContext = [self.virtualMachine mainContext];
            self.exceptionHandler = ^(DTJSContext *context, DTJSValue *exception){
                context.exception = exception;
                [exception push];//[... err];
                NSLog(@"JavaScript Error - %s\n", duk_safe_to_string(context.dukContext, -1));
                duk_throw(context.dukContext);//code will never returns
            };
        }
        return self;
    }
}

- (instancetype)initWithVirtualMachine:(DTJSVirtualMachine *)virtualMachine{
    
    if(self = [super init]){
        if(virtualMachine){
            self.virtualMachine = virtualMachine;
            duk_context *mainContext = [virtualMachine mainContext];
            if(mainContext){
                duk_idx_t thr_idx = duk_push_thread(mainContext);
                self.dukContext = duk_require_context(mainContext, thr_idx);
                self.exceptionHandler = ^(DTJSContext *context, DTJSValue *exception){
                    context.exception = exception;
                    [exception push];//[... err];
                    NSLog(@"JavaScript Error - %s\n", duk_safe_to_string(context.dukContext, -1));
                    duk_throw(context.dukContext);//code will never returns
                };
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

#pragma  mark - script eval methods

- (DTJSValue *)evaluateScript:(NSString *)script{
    
    DTJSValue *jsValue = nil;
    if(script){
        duk_push_string(self.dukContext, [script cStringUsingEncoding:NSUTF8StringEncoding]);//[src]
        [DTJSContext setCurrentContext:self];
        if (duk_peval(self.dukContext) != 0) {//[... err]
            DTJSDebugLog(@"eval failed");
            jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
            DTJSValue *exception = jsValue;
            [self notifyExecption:exception];
        } else {//[... res]
            DTJSDebugLog(@"eval successful");
            jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
        }
        [DTJSContext setCurrentContext:nil];
        duk_pop(self.dukContext);//pop [... res]
    }
    return jsValue;
}

- (DTJSValue *)evaluateScriptInFile:(NSURL *)fileURL{
    
    DTJSValue *jsValue = nil;
    if(fileURL){
        const char *filePath = [[fileURL path] cStringUsingEncoding:NSUTF8StringEncoding];
        [DTJSContext setCurrentContext:self];
        if (duk_peval_file(self.dukContext, filePath) != 0) {//[... err]
            DTJSDebugLog(@"eval failed");
            jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
            DTJSValue *exception = jsValue;
            [self notifyExecption:exception];
        } else {//[... res]
            DTJSDebugLog(@"eval successful");
            jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
        }
        [DTJSContext setCurrentContext:nil];
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
            [DTJSContext setCurrentContext:self];
            if (duk_pcompile(self.dukContext, 0) != 0) {//[... func]
                DTJSDebugLog(@"compile failed");
                jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
                DTJSValue *exception = jsValue;
                [self notifyExecption:exception];
            } else {
                DTJSDebugLog(@"compile successful");
                duk_call(self.dukContext, 0);//[... func ] -> [... result ]
                jsValue = [DTJSValue valueWithValAtStackTopInContext:self];
            }
            [DTJSContext setCurrentContext:nil];
            duk_pop(self.dukContext);//pop result
        }
    }
    return jsValue;
}

- (DTJSValue *)globalObject{
    
    static DTJSValue *globalObj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        duk_push_global_object(self.dukContext);//[... gbl]
        globalObj =  [DTJSValue valueWithValAtStackTopInContext:self];
        duk_pop(self.dukContext);//pops [... gbl]
    });
    return globalObj;
}

+ (void)setCurrentContext:(DTJSContext *)currentContext{
    
    if(_currentContext != currentContext){
        _currentContext = currentContext;
    }
}

+ (DTJSContext *)currentContext{
    
    return _currentContext;
}

+ (DTJSValue *)currentThis{
    
    DTJSValue *this = nil;
    DTJSContext *context = [DTJSContext currentContext];
    if(context){
        duk_push_this(context.dukContext);//[... newObj]
        this = [DTJSValue valueWithValAtStackTopInContext:context];
        duk_pop(context.dukContext);//pops [... newObj]
    }
    return this;
}

+ (DTJSValue *)currentCallee{
    
    DTJSValue *callee = nil;
    DTJSContext *context = [DTJSContext currentContext];
    if(context){
        duk_push_current_function(context.dukContext);//[... newObj]
        callee = [DTJSValue valueWithValAtStackTopInContext:context];
        duk_pop(context.dukContext);//pops [... newObj]
    }
    return callee;
}

+ (NSArray *)currentArguments{
    
    NSMutableArray *arguments = nil;
    DTJSContext *context = [DTJSContext currentContext];
    if(context){
        arguments = [NSMutableArray array];
        int nargs = duk_get_top(context.dukContext);
        for (unsigned i = 0; i < nargs; i++) {
            id obj = [[DTJSValue valueWithValAtStackIndex:i inContext:context] toObject];
            [arguments addObject:obj];
        }
    }
    return arguments;
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

@implementation DTJSContext (Internal)

//TODO: remove commented code
//+ (void)setContext:(DTJSContext *)context ofDukContext:(duk_context *)ctx{
//
//    if(ctx && context){
//        duk_push_thread_stash(ctx, ctx);
//        duk_push_pointer(ctx, (void *)context);
//        duk_put_prop_string(ctx, -1, "context");
//        duk_pop_2(ctx);
//    }
//}
//
//+ (DTJSContext *)contextOfDukContext:(duk_context *)ctx{
//    
//    void *context = nil;
//    if(ctx){
//        duk_push_thread_stash(ctx, ctx);//[... thdStash]
//        if(duk_get_prop_string(ctx, -1, "context")){//[... thdStash, ptr]
//            context = duk_require_pointer(ctx, -1);
//        }
//        duk_pop_2(ctx);
//    }
//    return (DTJSContext *)context;
//}
//
//- (DTJSValue *)thisObject{
//    
//    DTJSValue *thisObj = nil;
//    duk_push_this(self.dukContext);//[... newObj]
//    thisObj = [DTJSValue valueWithValAtStackTopInContext:self];
//    duk_pop(self.dukContext);//pops [... newObj]
//    return thisObj;
//}

- (void)notifyExecption:(DTJSValue *)exception{

    self.exceptionHandler(self, exception);
}

@end
