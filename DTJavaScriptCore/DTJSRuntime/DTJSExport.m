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

DUK_CALLBACK(JSObjectClassMethodCallback){
    
    return 0;
}

DUK_CALLBACK(JSObjectInstanceMethodCallback){
    
    return 0;
}

DUK_CALLBACK(JSObjectPropertySetterCallback){
    
    return 0;
}

DUK_CALLBACK(JSObjectPropertyGetterCallback){
    
    return 0;
}

@interface DTJSExport ()

@property (class) NSMutableDictionary *classMethodMap;
@property (class) NSMutableDictionary *instanceMethodMap;
@property (class) NSMutableDictionary *jsValueMap;

+ (void)exportClassMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
+ (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
+ (void)exportPropertiesFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;

@end

@implementation DTJSExport

static NSMutableDictionary *_classMethodMap;
static NSMutableDictionary *_instanceMethodMap;
static NSMutableDictionary *_jsValueMap;

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

+ (NSMutableDictionary *)jsValueMap{
    if(!_jsValueMap){
        //ensure that dictionary is created only once
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _jsValueMap = [[NSMutableDictionary dictionary] retain];
        });
    }
    return _jsValueMap;
}

+ (void)setJsValueMap:(NSMutableDictionary *)jsValueMap{
    
    if(_jsValueMap){
        [_jsValueMap release]; _jsValueMap = nil;
    }
    if(jsValueMap){
        _jsValueMap = [jsValueMap retain];
    }
}

+ (DTJSValue *)exportClass:(Class)cls inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context && cls){
        if(object_isClass(cls)){
            if(self.jsValueMap){
                jsValue = [self.jsValueMap objectForKey:NSStringFromClass(cls)];
            }
            if(!jsValue){
                {
                    //create jsObject for the class
                    jsValue = [DTJSValue valueWithNewFunctionInContext:context withCallback:JSObjectConstructorCallback noOfArgs:0];
                    
                    //export class methods to jsObject
                    [DTJSExport exportClassMethodsFromClass:cls toJSValue:jsValue inContext:context];
                    
                    //add a prototype object to the jsObject
                    jsValue[@"prototype"] = [DTJSValue valueWithNewObjectInContext:context];
                    
                    //export instance methods & properties to prototype object
                    [DTJSExport exportInstanceMethodsFromClass:cls toJSValue:jsValue[@"prototype"] inContext:context];
                    [DTJSExport exportPropertiesFromClass:cls toJSValue:jsValue[@"prototype"] inContext:context];
                    
                    //store jsValue in jsValueMap
                    [self.jsValueMap setObject:jsValue forKey:NSStringFromClass(cls)];
                }
                {
                    //create prototype based inheritance for super class
                    DTJSValue *superClsObj = [DTJSExport exportClass:class_getSuperclass(cls) inContext:context];
                    if(superClsObj){
                        
                        //set __proto__ of derived class obj to super class obj
                        duk_idx_t obj_idx = [jsValue push];//[... clsObj]
                        [superClsObj push];//[... clsObj, supClsObj]
                        duk_set_prototype(context.dukContext,  obj_idx);//[... clsObj]
                        duk_pop(context.dukContext);//pops [... clsObj]
                        
                        //set __proto__ of derived class prototype obj to super class prototype obj
                        duk_idx_t cls_protyp_obj_idx = [jsValue[@"prototype"] push];//[... clsProTypObj]
                        [superClsObj[@"prototype"] push];//[... clsProTypObj, supClsProTypObj]
                        duk_set_prototype(context.dukContext, cls_protyp_obj_idx);//[... clsProTypObj]
                        duk_pop(context.dukContext);//pops [... clsProTypObj]
                    }
                }
            }
        }
    }
    return jsValue;
}

+ (void)exportClassMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    if(jsValue && context && cls){
        if(object_isClass(cls)){
            NSString *mtdJSName = nil;
            DTJSValue *mtdJSValue = nil;
            SEL sel = nil;
            NSInteger noOfArgs = 0;
            NSValue *key = nil;
            NSValue *value = nil;
            unsigned int mtdCount = 0;
            Method *mtdList = class_copyMethodList(object_getClass(cls), &mtdCount);
            for (int i = 0; i < mtdCount; i++) {
                sel = method_getName(mtdList[i]);
                noOfArgs = method_getNumberOfArguments(mtdList[i]);
                mtdJSName = [NSString jsMethodStringWithSelector:sel];
                mtdJSValue = [DTJSValue valueWithNewFunctionInContext:context withCallback:JSObjectClassMethodCallback noOfArgs:noOfArgs];
                jsValue[mtdJSName] = mtdJSValue;
                
                // store the duk func obj and objC method selector as key-value pairs
                // key = duk func obj
                // val = objC method selector
                key = [NSValue valueWithPointer:[mtdJSValue objectValue]];
                value = [NSValue valueWithPointer:sel];
                [self.classMethodMap setObject:value forKey:key];
            }
            free(mtdList);mtdList = 0;
        }
    }
}

+ (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    if(jsValue && context && cls){
        if(object_isClass(cls)){
            NSString *mtdJSName = nil;
            DTJSValue *mtdJSValue = nil;
            SEL sel = nil;
            NSInteger noOfArgs = 0;
            NSValue *key = nil;
            NSValue *value = nil;
            unsigned int mtdCount = 0;
            Method *mtdList = class_copyMethodList(cls, &mtdCount);
            if(mtdList && mtdCount > 0){
                for (int i = 0; i < mtdCount; i++) {
                    sel = method_getName(mtdList[i]);
                    noOfArgs = method_getNumberOfArguments(mtdList[i]);
                    mtdJSName = [NSString jsMethodStringWithSelector:sel];
                    mtdJSValue = [DTJSValue valueWithNewFunctionInContext:context withCallback:JSObjectInstanceMethodCallback noOfArgs:noOfArgs];
                    jsValue[mtdJSName] = mtdJSValue;
                    
                    // store the duk func obj and objC method selector as key-value pairs
                    // key = duk func obj
                    // val = objC method selector
                    key = [NSValue valueWithPointer:[mtdJSValue objectValue]];
                    value = [NSValue valueWithPointer:sel];
                    [self.instanceMethodMap setObject:value
                                               forKey:key];
                }
                free(mtdList);mtdList = 0;
            }
        }
    }
}

+ (void)exportPropertiesFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context{
    
    //TODO
    if(jsValue && context && cls){
        if(object_isClass(cls)){
            const char *propName = nil;
            unsigned int propCount = 0;
            objc_property_t *propList = class_copyPropertyList(cls, &propCount);
            if(propList && propCount > 0){
                for (int i = 0; i < propCount; i++) {
                    propName = property_getName(propList[i]);
                    
                    NSDictionary *descriptor = [NSDictionary dictionary];
                    [descriptor setValue:(id)JSObjectPropertyGetterCallback forKey:JSPropertyDescriptorGetKey];
                    const char *propertyAttributes = property_getAttributes(propList[i]);
                    //check those attributes for read-only:
                    NSArray *attributes = [[NSString stringWithUTF8String:propertyAttributes] componentsSeparatedByString:@","];
                    if(![attributes containsObject:@"R"]){
                        [descriptor setValue:(id)JSObjectPropertySetterCallback forKey:JSPropertyDescriptorSetKey];
                        
                    }
                    [jsValue defineProperty:[NSString stringWithUTF8String:propName] descriptor:descriptor];
                }
                free(propList);propList = 0;
            }
        }
    }
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

