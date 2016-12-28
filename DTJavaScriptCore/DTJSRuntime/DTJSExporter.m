//
//  DTJSExporter.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 20/11/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSExporter.h"
#import "DTJSContext.h"
#import "DTJSContextInternal.h"
#import "DTJSValueInternal.h"
#import "DTJSConstants.h"
#import <objc/runtime.h>

DUK_C_FUNCTION(JSObjectDestructorCallback){
    
    if(ctx){
        DTJSContext *context = [DTJSContext currentContext];
        if(context){
            //this refers to object being destructed
            DTJSValue *this = [DTJSContext currentThis];
            if(this){
                bool deleted = [this[@("\xFF" "deleted")] toBool];
                if(!deleted){
                    id nativeObj = [this[@("\xFF" "nativeRef")] toPointer];
                    if([nativeObj isKindOfClass:[NSObject class]]){
                        [nativeObj release];
                    }
                    this[@("\xFF" "deleted")] = [DTJSValue valueWithBool:true inContext:context];
                }
            }
        }
    }
    return 0;
}

DUK_C_FUNCTION(JSObjectConstructorCallback){
    
    //check if constructor is invoked using new
    if(ctx && duk_is_constructor_call(ctx)){
        DTJSContext *context = [DTJSContext currentContext];
        if(context && context.dukContext == ctx){
            //this refers to object being constructed
            DTJSValue *this = [DTJSContext currentThis];
            if(this){
                DTJSValue *className = this[@("\xFF" "className")];
                if(className){
                    Class class = NSClassFromString([className toString]);
                    id obj = [[class alloc] init];
                    //store the native reference
                    this[@("\xFF" "nativeRef")] = [DTJSValue valueWithPointer:(void *)obj inContext:context];
                }
                
                //store a boolean flag to mark the object as deleted
                //because the destructor may be called several times
                this[@("\xFF" "deleted")] = [DTJSValue valueWithBool:false inContext:context];
                
                //store the function destructor
                [this push];//[... newObject]
                duk_push_c_function(context.dukContext, JSObjectDestructorCallback, 0);
                duk_set_finalizer(context.dukContext, -2);
                [this pop];//pops [... newObject]
            }
        }
    }
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
    
    return 0;
}

@interface DTJSExporter ()

@property (nonatomic, retain) NSMutableDictionary *classObjMap;

- (void)exportMethodsFromProtocol:(Protocol *)protocol toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context;
- (void)exportPropertiesFromProtocol:(Protocol *)protocol toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context;
- (void)exportProtocol:(Protocol *)protocol toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context;
- (void)exportProtocolsOfClass:(Class)cls toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context;

@end

@implementation DTJSExporter

+ (instancetype)sharedInstance{
    
    static DTJSExporter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DTJSExporter alloc] init];
        sharedInstance.classObjMap = [NSMutableDictionary dictionary];
    });
    return sharedInstance;
}

//should never be called
- (void)dealloc{
    
    [super dealloc];
}

#pragma mark - export methods

- (void)exportMethodsFromProtocol:(Protocol *)protocol toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context{
    
    if(classObj && context){
        if(protocol && protocol_conformsToProtocol(protocol, objc_getProtocol("JSExport"))){
            unsigned outCount = 0;
            struct objc_method_description *methods = nil;
            DTCFunction dukCFunction = nil;
            if ([@(protocol_getName(protocol)) hasSuffix: @"ClassExports"]){
                methods = protocol_copyMethodDescriptionList(protocol, YES, NO, &outCount);
                dukCFunction = JSObjectClassMethodCallback;
            }
            else if ([@(protocol_getName(protocol)) hasSuffix: @"InstanceExports"]){
                methods = protocol_copyMethodDescriptionList(protocol, YES, YES, &outCount);
                dukCFunction = JSObjectInstanceMethodCallback;
                classObj = classObj[@"prototype"];
            }
            if(methods){
                for (unsigned i = 0; i < outCount; i++) {
                    SEL sel = methods[i].name;
                    NSInteger noOfArgs = strlen(methods[i].types);
                    NSString *propName= [DTJSExporter propertyNameFromSelector:sel];
                    DTJSValue *propValue = [DTJSValue valueWithNewFunctionInContext:context withCallback:dukCFunction noOfArgs:noOfArgs];
                    propValue[@"methodName"] = NSStringFromSelector(sel);
                    classObj[propName] = propValue;
                    
                }
                free(methods);methods = 0;
            }
        }
    }
}

- (void)exportPropertiesFromProtocol:(Protocol *)protocol toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context{
    
    if(classObj && context){
        if(protocol && protocol_conformsToProtocol(protocol, objc_getProtocol("JSExport"))){
            unsigned outCount = 0;
            objc_property_t *properties = nil;
            if([@(protocol_getName(protocol)) hasSuffix: @"InstanceExports"]){
                properties = protocol_copyPropertyList(protocol, &outCount);
            }
            if(properties && outCount > 0){
                for (unsigned i = 0; i < outCount; i++) {
                    //prop name
                    const char *propName = property_getName(properties[i]);
                    
                    //descriptor
                    NSMutableDictionary *descriptor = [NSMutableDictionary dictionary];
                    NSValue *getterValue = [[NSValue valueWithPointer:(void *)JSObjectPropertyGetterCallback] retain];
                    [descriptor setValue:getterValue forKey:JSPropertyDescriptorGetKey];
                    [descriptor setValue:[NSNumber numberWithBool:false] forKey:JSPropertyDescriptorEnumerableKey];
                    [descriptor setValue:[NSNumber numberWithBool:true]  forKey:JSPropertyDescriptorConfigurableKey];
                
                    //check attributes for read-write:
                    const char *propertyAttributes = property_getAttributes(properties[i]);
                    NSArray *attributes = [[NSString stringWithUTF8String:propertyAttributes] componentsSeparatedByString:@","];
                    if(![attributes containsObject:@"R"]){
                        NSValue *setterValue = [[NSValue valueWithPointer:(void *)JSObjectPropertySetterCallback] retain];
                        [descriptor setValue:setterValue forKey:JSPropertyDescriptorSetKey];
                        [descriptor setValue:[NSNumber numberWithBool:true] forKey:JSPropertyDescriptorEnumerableKey];
                    }
                    
                    //define property
                    [classObj defineProperty:[NSString stringWithUTF8String:propName] descriptor:descriptor];
                }
                free(properties);properties = 0;
            }
        }
    }
}

- (void)exportProtocol:(Protocol *)protocol toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context{
    
    if(classObj && context){
        if(protocol && protocol_conformsToProtocol(protocol, objc_getProtocol("JSExport"))){
            [self exportMethodsFromProtocol:protocol toJSValue:classObj inContext:context];
            [self exportPropertiesFromProtocol:protocol toJSValue:classObj inContext:context];
        }
    }
}

- (void)exportProtocolsOfClass:(Class)cls toJSValue:(DTJSValue *)classObj inContext:(DTJSContext *)context{
    
    Protocol* jsExportProtocol = objc_getProtocol("JSExport");
    
    unsigned protocolsCount;
    Protocol** protocols = class_copyProtocolList(cls, &protocolsCount);
    if(protocols && protocolsCount > 0){
        for (unsigned i = 0; i < protocolsCount; i++) {
            if( protocol_conformsToProtocol(protocols[i], jsExportProtocol)){
                [self exportProtocol:protocols[i] toJSValue:classObj inContext:context];
            }
        }
    }
}

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
                    
                    //add a prototype object to the classObj
                    classObj[@"prototype"] = [DTJSValue valueWithNewObjectInContext:context];
                    
                    //export jsexport protocols to classObj
                    [self exportProtocolsOfClass:cls toJSValue:classObj inContext:context];
                    
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

#pragma mark - utility methods

+ (NSString*)propertyNameFromSelector:(SEL)selector{
    
    NSArray* split = [NSStringFromSelector(selector) componentsSeparatedByString: @":"];
    NSMutableString* propertyName = [NSMutableString string];
    for (NSInteger i = 0; i < split.count; i++) {
        NSString* string = split[i];
        if (i > 0) {
            if (string.length > 0) {
                NSString* firstCharacter = [string substringWithRange: NSMakeRange(0, 1)];
                [propertyName appendString: [string stringByReplacingCharactersInRange: NSMakeRange(0, 1) withString: firstCharacter.uppercaseString]];
            }
        } else {
            [propertyName appendString: string];
        }
    }
    
    //remove js prefix if any
    if([propertyName hasPrefix:@"js"]){
        [propertyName deleteCharactersInRange:NSMakeRange(0, 2)];
    }
    
    return propertyName;
}

@end
