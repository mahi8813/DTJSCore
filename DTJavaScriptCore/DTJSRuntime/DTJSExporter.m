//
//  DTJSExporter.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 20/11/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSExporter.h"
#import "DTJSContext.h"
#import "DTJSValueInternal.h"
#import "DTJSConstants.h"
#import <objc/runtime.h>

DUK_C_FUNCTION(JSObjectConstructorCallback){
    
    return 0;
}

DUK_C_FUNCTION(JSObjectClassMethodCallback){
    
    return 0;
}

DUK_C_FUNCTION(JSObjectInstanceMethodCallback){
    
    return 0;
}

DUK_C_FUNCTION(JSObjectPropertySetterCallback){
    
    return 0;
}

DUK_C_FUNCTION(JSObjectPropertyGetterCallback){
    
    duk_push_int(ctx, 2);
    return 1;
}

@interface DTJSExporter ()

@property (nonatomic, retain) NSMutableDictionary *classMethodMap;
@property (nonatomic, retain) NSMutableDictionary *instanceMethodMap;
@property (nonatomic, retain) NSMutableDictionary *classObjMap;

- (void)exportClassMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
- (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;
- (void)exportPropertiesFromClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;

@end

@implementation DTJSExporter

+ (instancetype)sharedInstance{
    
    static DTJSExporter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DTJSExporter alloc] init];
        sharedInstance.classMethodMap = [NSMutableDictionary dictionary];
        sharedInstance.instanceMethodMap = [NSMutableDictionary dictionary];
        sharedInstance.classObjMap = [NSMutableDictionary dictionary];
    });
    return sharedInstance;
}

//should never be called
- (void)dealloc{
    
    self.classMethodMap = nil;
    self.instanceMethodMap = nil;
    self.classObjMap = nil;
    [super dealloc];
}

#pragma mark - export methods

- (DTJSValue *)exportClass:(Class)cls inContext:(DTJSContext *)context{
    
    DTJSValue *classObj = nil;
    if(context && cls){
        if(object_isClass(cls)){
            if(self.classObjMap){
                classObj = [self.classObjMap objectForKey:NSStringFromClass(cls)];
            }
            if(!classObj){
                {
                    //create jsObject for the class
                    classObj = [DTJSValue valueWithNewFunctionInContext:context withCallback:JSObjectConstructorCallback noOfArgs:0];
                    
                    //export class methods to classObj
                    [self exportClassMethodsFromClass:cls toJSValue:classObj inContext:context];
                    
                    //add a prototype object to the classObj
                    classObj[@"prototype"] = [DTJSValue valueWithNewObjectInContext:context];
                    
                    //export instance methods & properties to classObj's prototype object
                    [self exportInstanceMethodsFromClass:cls toJSValue:classObj[@"prototype"] inContext:context];
                    [self exportPropertiesFromClass:cls toJSValue:classObj[@"prototype"] inContext:context];
                    
                    //store classObj in classObjMap
                    [self.classObjMap setObject:classObj forKey:NSStringFromClass(cls)];
                }
                {
                    //create prototype based inheritance for super class
                    DTJSValue *superClsObj = [self exportClass:class_getSuperclass(cls) inContext:context];
                    if(superClsObj){
                        
                        //set __proto__ of derived class obj to super class obj
                        duk_idx_t obj_idx = [classObj push];//[... clsObj]
                        [superClsObj push];//[... clsObj, supClsObj]
                        duk_set_prototype(context.dukContext,  obj_idx);//[... clsObj]
                        duk_pop(context.dukContext);//pops [... clsObj]
                        
                        //set __proto__ of derived class prototype obj to super class prototype obj
                        duk_idx_t cls_protyp_obj_idx = [classObj[@"prototype"] push];//[... clsProTypObj]
                        [superClsObj[@"prototype"] push];//[... clsProTypObj, supClsProTypObj]
                        duk_set_prototype(context.dukContext, cls_protyp_obj_idx);//[... clsProTypObj]
                        duk_pop(context.dukContext);//pops [... clsProTypObj]
                    }
                }
            }
        }
    }
    return classObj;
}

- (void)exportClassMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context{
    
    if(classObj && context && cls){
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
                mtdJSName = [DTJSExporter propertyNameFromSelector:sel];
                mtdJSValue = [DTJSValue valueWithNewFunctionInContext:context withCallback:JSObjectClassMethodCallback noOfArgs:noOfArgs];
                classObj[mtdJSName] = mtdJSValue;
                
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

- (void)exportInstanceMethodsFromClass:(Class)cls toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context{
    
    if(classObj && context && cls){
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
                    mtdJSName = [DTJSExporter propertyNameFromSelector:sel];
                    mtdJSValue = [DTJSValue valueWithNewFunctionInContext:context withCallback:JSObjectInstanceMethodCallback noOfArgs:noOfArgs];
                    classObj[mtdJSName] = mtdJSValue;
                    
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

- (void)exportPropertiesFromClass:(Class)cls toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context{
    
    if(classObj && context && cls){
        if(object_isClass(cls)){
            const char *propName = nil;
            unsigned int propCount = 0;
            objc_property_t *propList = class_copyPropertyList(cls, &propCount);
            if(propList && propCount > 0){
                for (int i = 0; i < propCount; i++) {
                    propName = property_getName(propList[i]);
                    
                    NSMutableDictionary *descriptor = [NSMutableDictionary dictionary];
                    NSValue *getterValue = [[NSValue valueWithPointer:(void *)JSObjectPropertyGetterCallback] retain];
                    [descriptor setValue:getterValue forKey:JSPropertyDescriptorGetKey];
                    const char *propertyAttributes = property_getAttributes(propList[i]);
                    //check those attributes for read-only:
                    NSArray *attributes = [[NSString stringWithUTF8String:propertyAttributes] componentsSeparatedByString:@","];
                    if(![attributes containsObject:@"R"]){
                        NSValue *setterValue = [[NSValue valueWithPointer:(void *)JSObjectPropertySetterCallback] retain];
                        [descriptor setValue:setterValue forKey:JSPropertyDescriptorSetKey];
                        
                    }
                    [classObj defineProperty:[NSString stringWithUTF8String:propName] descriptor:descriptor];
                    
                }
                free(propList);propList = 0;
            }
        }
    }
}

#pragma mark - utility methods

//+ (NSString*)propertyNameFromSelector:(SEL)selector{
//
//    NSArray* split = [NSStringFromSelector(selector) componentsSeparatedByString: @":"];
//    NSMutableString* propertyName = [NSMutableString string];
//    for (NSInteger i = 0; i < split.count; i++) {
//        NSString* string = split[i];
//        if (i > 0) {
//            if (string.length > 0) {
//                NSString* firstCharacter = [string substringWithRange: NSMakeRange(0, 1)];
//                [propertyName appendString: [string stringByReplacingCharactersInRange: NSMakeRange(0, 1) withString: firstCharacter.uppercaseString]];
//            }
//        } else {
//            [propertyName appendString: string];
//        }
//    }
//
//    return propertyName;
//}

+ (NSString*)propertyNameFromSelector:(SEL)selector{
    
    const char *srcStr = sel_getName(selector);
    void *dstStr = calloc(1, sizeof(char)*(strlen(srcStr)+1));
    char *propertyName =  strcpy(dstStr, srcStr) ;
    if(propertyName){
        unsigned long length = strlen(propertyName);
        int j = 0;
        for(int i = 0; i < length; i++){
            if(propertyName[i] == ':'){
                ++i;
                if(propertyName[i] >= 'a' && propertyName[i] <= 'z'){
                    propertyName[j++] = propertyName[i] - 32;//'a' - 'A' = 32
                }else{
                    propertyName[j++] = propertyName[i];
                }
            }
            else{
                propertyName[j++] = propertyName[i];
            }
        }
        propertyName[j] = '\0';
        return [NSString stringWithUTF8String:propertyName];
    }
    return nil;
}

@end
