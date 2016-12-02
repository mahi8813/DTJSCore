//
//  DTJSExport.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 20/11/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSExport.h"
#import "DTJSContext.h"
#import "duktape.h"
#import <objc/runtime.h>


DUK_CALLBACK(JSObjectConstructorCallback){
    
    return 0;
}

DUK_CALLBACK(JSObjectMethodCallback){
    
    return 0;
}

@interface DTJSExport ()

@property (class) NSMutableDictionary *classMethodMap;
@property (class) NSMutableDictionary *instanceMethodMap;

+ (void)exportClassMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
+ (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
+ (void)exportPropertiesFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;

@end

@implementation DTJSExport

static NSMutableDictionary *_classMethodMap;
static NSMutableDictionary *_instanceMethodMap;

+ (NSMutableDictionary *)classMethodMap{
    if(!_classMethodMap){
        //ensure that dictionary is created only once
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _classMethodMap = [[NSMutableDictionary dictionary] retain];
        });
    }
    return _classMethodMap;
}

+ (void)setClassMethodMap:(NSMutableDictionary *)classMethodMap{
    
    if(_classMethodMap){
        [_classMethodMap release]; _classMethodMap = nil;
    }
    if(classMethodMap){
        _classMethodMap = [classMethodMap retain];
    }
}

+ (NSMutableDictionary *)instanceMethodMap{
    if(!_instanceMethodMap){
        //ensure that dictionary is created only once
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _instanceMethodMap = [[NSMutableDictionary dictionary] retain];
        });
    }
    return _instanceMethodMap;
}

+ (void)setInstanceMethodMap:(NSMutableDictionary *)instanceMethodMap{
    
    if(_instanceMethodMap){
        [_instanceMethodMap release]; _instanceMethodMap = nil;
    }
    if(instanceMethodMap){
        _instanceMethodMap = [instanceMethodMap retain];
    }
}

+ (void)exportClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    if(jsValue && context && cls){
        if(object_isClass(cls)){
            [DTJSExport exportClassMethodsFromClass:cls toJSValue:jsValue inContext:context];
            [DTJSExport exportInstanceMethodsFromClass:cls toJSValue:jsValue inContext:context];
            [DTJSExport exportPropertiesFromClass:cls toJSValue:jsValue inContext:context];
        }
    }
}

+ (void)exportClassMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    if(jsValue && context && cls){
        if(object_isClass(cls)){
            NSString *mtdJSName = nil;
            DTJSValue *mtdJSValue = nil;
            SEL sel = nil;
            NSValue *key = nil;
            NSValue *value = nil;
            unsigned int mtdCount = 0;
            Method *mtdList = class_copyMethodList(object_getClass(cls), &mtdCount);
            for (int i = 0; i < mtdCount; i++) {
                sel = method_getName(mtdList[i]);
                mtdJSName = [NSString jsMethodStringWithSelector:sel];
                mtdJSValue = [DTJSValue valueWithNewFunctionWithAssociatedDukCallback:JSObjectMethodCallback inContext:context];
                jsValue[mtdJSName] = mtdJSValue;
                
                // store the duk func obj and objC method selector as key-value pairs
                // key = duk func obj
                // val = objC method selector
                key = [NSValue valueWithPointer:[mtdJSValue objectValue]];
                value = [NSValue valueWithPointer:sel];
                [self.classMethodMap setObject:value forKey:key];
            }
        }
    }
}

+ (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    if(jsValue && context && cls){
        if(object_isClass(cls)){
            NSString *mtdJSName = nil;
            DTJSValue *mtdJSValue = nil;
            SEL sel = nil;
            NSValue *key = nil;
            NSValue *value = nil;
            unsigned int mtdCount = 0;
            Method *mtdList = class_copyMethodList(cls, &mtdCount);
            for (int i = 0; i < mtdCount; i++) {
                sel = method_getName(mtdList[i]);
                mtdJSName = [NSString jsMethodStringWithSelector:sel];
                mtdJSValue = [DTJSValue valueWithNewFunctionWithAssociatedDukCallback:JSObjectMethodCallback inContext:context];
                jsValue[mtdJSName] = mtdJSValue;
                
                // store the duk func obj and objC method selector as key-value pairs
                // key = duk func obj
                // val = objC method selector
                key = [NSValue valueWithPointer:[mtdJSValue objectValue]];
                value = [NSValue valueWithPointer:sel];
                [self.instanceMethodMap setObject:value
                                        forKey:key];
            }
        }
    }
}

+ (void)exportPropertiesFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    //TODO
}

@end

@implementation NSString (DTJSExport)

+ (NSString *)jsMethodStringWithSelector:(SEL)aSelector{
    
    const char *srcStr = sel_getName(aSelector);
    void *dstStr = calloc(1, sizeof(char)*(strlen(srcStr)+1));
    char *methodName =  strcpy(dstStr, srcStr) ;
    if(methodName){
        unsigned long length = strlen(methodName);
        int j = 0;
        for(int i = 0; i < length; i++){
            if(methodName[i] == ':'){
                ++i;
                if(methodName[i] >= 'a' && methodName[i] <= 'z'){
                    methodName[j++] = methodName[i] - 32;//'a' - 'A' = 32
                }else{
                    methodName[j++] = methodName[i];
                }
            }
            else{
                methodName[j++] = methodName[i];
            }
        }
        methodName[j] = '\0';
        return [NSString stringWithUTF8String:methodName];
    }
    return nil;
}

@end

