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

+ (void)exportClassMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
+ (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
+ (void)exportPropertiesFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;

@end

@implementation DTJSExport

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
            unsigned int mtdCount = 0;
            Method *mtdList = class_copyMethodList(object_getClass(cls), &mtdCount);
            for (int i = 0; i < mtdCount; i++) {
                SEL sel = method_getName(mtdList[i]);
                NSString *mtdJSName = [NSString jsMethodStringWithSelector:sel];
                jsValue[mtdJSName] = [DTJSValue valueWithNewFunctionWithAssociatedDukCallback:JSObjectMethodCallback inContext:context];
            }
        }
    }
}

+ (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    if(jsValue && context && cls){
        if(object_isClass(cls)){
            unsigned int mtdCount = 0;
            Method *mtdList = class_copyMethodList(cls, &mtdCount);
            for (int i = 0; i < mtdCount; i++) {
                SEL sel = method_getName(mtdList[i]);
                NSString *mtdJSName = [NSString jsMethodStringWithSelector:sel];
                jsValue[mtdJSName] = [DTJSValue valueWithNewFunctionWithAssociatedDukCallback:JSObjectMethodCallback inContext:context];
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
    
    char *methodName = (char *)sel_getName(aSelector);
    if(methodName){
        unsigned long length = strlen(methodName);
        int j = 0;
        for(int i = 0; i < length; i++){
            if(methodName[i] == ':'){
                ++i;
                if(methodName[i] >= 'a' && methodName[i] <= 'z'){
                    methodName[j++] = methodName[i] - ('a' - 'A');
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

