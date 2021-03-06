//
//  DTJSValue.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSValue.h"
#import "DTJSValueInternal.h"
#import "DTJSContext.h"
#import "DTJSContextInternal.h"
#import "DTJSExporter.h"
#import "duktape.h"
#import <objc/runtime.h>

NSString *const JSPropertyDescriptorWritableKey = @"writable";
NSString *const JSPropertyDescriptorEnumerableKey = @"enumerable";
NSString *const JSPropertyDescriptorConfigurableKey = @"configurable";
NSString *const JSPropertyDescriptorValueKey = @"value";
NSString *const JSPropertyDescriptorGetKey  = @"get";
NSString *const JSPropertyDescriptorSetKey = @"set";

@interface DTJSValue ()

typedef union Value{
    double numberValue;
    void *objectValue;
}Value;

@property (nonatomic, assign) Value *value;
@property (nonatomic, assign) unsigned retainIndex;

//redeclared to allow readwrite internally
@property (readwrite) BOOL isUndefined;
@property (readwrite) BOOL isNull;
@property (readwrite) BOOL isBoolean;
@property (readwrite) BOOL isNumber;
@property (readwrite) BOOL isString;
@property (readwrite) BOOL isObject;
@property (readwrite) BOOL isArray;
@property (readwrite) BOOL isDate;
@property (readwrite) BOOL isFunction;
@property (readwrite) BOOL isPointer;

+ (DTJSValue *)valueWithString:(NSString *)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithArray:(NSArray *)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithDictionary:(NSDictionary *)value inContext:(DTJSContext *)context;

@end

@implementation DTJSValue

#pragma mark - initializers

- (instancetype)initWithContext:(DTJSContext *)context{
    
    if(self = [super init]){
        self.value = (Value *)calloc(1, sizeof(Value));
        self.context = context;
        self.retainIndex = NAN;
    }
    return self;
}

#pragma mark - dealloc

- (void)dealloc{
    
    if(self.value){
        if(self.value->objectValue){
            free(self.value->objectValue);
            self.value->objectValue= 0;
        }
        free(self.value);
        self.value = nil;
    }
    [self releaseJSObjectValue];
    [super dealloc];
}

#pragma mark - convenience initializaters

+ (DTJSValue *)valueWithString:(NSString *)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        if([value isKindOfClass:[NSString class]]){
            jsValue = [[DTJSValue alloc] initWithContext:context];
            jsValue.isString = true;
            jsValue.value->objectValue = (void *)duk_push_string(context.dukContext, [value cStringUsingEncoding:NSUTF8StringEncoding]);
            [jsValue retainJSObjectValue];
            duk_pop(context.dukContext);//pops string
        }
    }
    return jsValue;
}

+ (DTJSValue *)valueWithArray:(NSArray *)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        if([value isKindOfClass:[NSArray class]]){
            jsValue = [DTJSValue valueWithNewArrayInContext:context];
            NSUInteger count = [value count];
            for (int i = 0; i < count; i++) {
                jsValue[i] = value[i];
            }
        }
    }
    return jsValue;
}

+ (DTJSValue *)valueWithDictionary:(NSDictionary *)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        if([value isKindOfClass:[NSDictionary class]]){
            jsValue = [DTJSValue valueWithNewObjectInContext:context];
            for (id key in value) {
                id obj = [value objectForKey:key];
                if(obj){
                    jsValue[key] = obj;
                }
            }
        }
    }
    return jsValue;
}

+ (DTJSValue *)valueWithObject:(id)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        if(value){
            if(object_isClass(value)){
                jsValue = [DTJSValue valueWithObjcClass:value inContext:context];
            }
            else if([value isKindOfClass:[DTJSValue class]]){
                jsValue = value;
            }
            else if([value isKindOfClass:[NSNull class]]){
                jsValue = [DTJSValue valueWithNullInContext:context];
            }
            else if ([value isKindOfClass:[NSNumber class]]){
                jsValue = [DTJSValue valueWithDouble:[value doubleValue] inContext:context];
            }
            else if([value isKindOfClass:[NSString class]]){
                jsValue = [DTJSValue valueWithString:value inContext:context];
            }
            else if([value isKindOfClass:[NSArray class]]){
                jsValue = [DTJSValue valueWithArray:value inContext:context];
            }
            else if([value isKindOfClass:[NSDictionary class]]){
                jsValue = [DTJSValue valueWithDictionary:value inContext:context];
            }
            else if ([value isKindOfClass:[NSDate class]]){
                // date object apis are not exposed in duktape.
                // however built in date object support is available.
            }
        }
        else{
            jsValue = [DTJSValue valueWithUndefinedInContext:context];
        }
    }
    return jsValue;
}

+ (DTJSValue *)valueWithBool:(BOOL)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isBoolean = true;
        jsValue.value->numberValue = value;
    }
    return jsValue;
}

+ (DTJSValue *)valueWithDouble:(double)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isNumber = true;
        jsValue.value->numberValue = value;
    }
    return jsValue;
}

+ (DTJSValue *)valueWithInt32:(int32_t)value inContext:(DTJSContext *)context{
    
    return [DTJSValue valueWithDouble:(double)value inContext:context];
}

+ (DTJSValue *)valueWithUInt32:(uint32_t)value inContext:(DTJSContext *)context{
    
    return [DTJSValue valueWithDouble:(double)value inContext:context];
}

+ (DTJSValue *)valueWithNewObjectInContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isObject = true;
        duk_idx_t obj_idx = duk_push_object(context.dukContext);//[... obj]
        jsValue.value->objectValue = duk_require_heapptr(context.dukContext, obj_idx);
        [jsValue retainJSObjectValue];
        duk_pop(context.dukContext);//pops [... obj]
    }
    return jsValue;
}

+ (DTJSValue *)valueWithNewArrayInContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isArray = true;
        duk_idx_t arr_idx = duk_push_array(context.dukContext);//[... arr]
        jsValue.value->objectValue = duk_require_heapptr(context.dukContext, arr_idx);
        [jsValue retainJSObjectValue];
        duk_pop(context.dukContext);//pops [... arr]
    }
    return jsValue;
}

+ (DTJSValue *)valueWithNewErrorFromMessage:(NSString *)message inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isObject = true;
        duk_idx_t err_idx =  duk_push_error_object(context.dukContext, DUK_ERR_ERROR, [message cStringUsingEncoding:NSUTF8StringEncoding]);//[... err]
        jsValue.value->objectValue = duk_require_heapptr(context.dukContext, err_idx);
        [jsValue retainJSObjectValue];
        duk_pop(context.dukContext);//pops [... err]
    }
    return jsValue;
}

+ (DTJSValue *)valueWithNullInContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isNull = true;
    }
    return jsValue;
}

+ (DTJSValue *)valueWithUndefinedInContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isUndefined = true;
    }
    return jsValue;
}

#pragma mark - JS to Objective C value converters

- (id)toObject{
    
    id retObj = nil;
    if(self.isUndefined){
        retObj = nil;
    }
    else if(self.isNull){
        retObj = [NSNull null];
    }
    else if(self.isBoolean ||
            self.isNumber){
        retObj = [NSNumber numberWithDouble:self.value->numberValue];
    }
    else if(self.isString){
        retObj = [NSString stringWithUTF8String:self.value->objectValue];
    }
    else if (self.isArray){
        duk_idx_t arr_idx = [self push];
        duk_size_t length = duk_get_length(self.context.dukContext, arr_idx);
        retObj = [NSArray array];
        for (int i = 0; i < length; i++) {
            duk_get_prop_index(self.context.dukContext, arr_idx, i);
            DTJSValue *jsValue = [DTJSValue valueWithValAtStackTopInContext:self.context];
            if([jsValue toObject] != nil){
                [retObj addObject:[jsValue toObject]];
            }
            duk_pop(self.context.dukContext);//pops value at index
        }
        [self pop];//pops array object
    }
    else if(self.isObject){
        duk_idx_t obj_idx = [self push];
        NSDictionary *retObj = [NSDictionary dictionary];
        duk_enum(self.context.dukContext, obj_idx, DUK_ENUM_OWN_PROPERTIES_ONLY);
        while (duk_next(self.context.dukContext, -1 , 1 )) {
            DTJSValue *jsValue = [DTJSValue valueWithValAtStackIndex:-1 inContext:self.context];
            DTJSValue *jsKey = [DTJSValue valueWithValAtStackIndex:-2 inContext:self.context];
            if(jsKey.isString){
                [retObj setValue:[jsValue toObject] forKey:[jsValue toString]];
            }
            duk_pop_2(self.context.dukContext);//pops key and value
        }
        duk_pop(self.context.dukContext);//pops enum object
        [self pop];//pops object
    }
    else if(self.isDate){
        // no supported apis in duktape
    }
    return retObj;
}

- (id)toObjectOfClass:(Class)expectedClass{
    
    return ([[self toObject] class] == expectedClass)?[self toObject]:nil;
}

- (BOOL)toBool{
    
    BOOL retVal = (BOOL)duk_to_boolean(self.context.dukContext, [self push]);
    [self pop];
    return retVal;
}

- (double)toDouble{
    
    double retVal = (double)duk_to_number(self.context.dukContext, [self push]);
    [self pop];
    return retVal;
}

- (int32_t)toInt32{
    
    int32_t retVal = (int32_t)duk_to_int32(self.context.dukContext, [self push]);
    [self pop];
    return retVal;
}

- (uint32_t)toUInt32{
    
    uint32_t retVal = (uint32_t)duk_to_uint32(self.context.dukContext, [self push]);
    [self pop];
    return retVal;
}

- (NSNumber *)toNumber{
    
    double value = (double)duk_to_number(self.context.dukContext, [self push]);
    [self pop];
    return [NSNumber numberWithDouble:value];;
}

- (NSString *)toString{
    
    const char *value = (const char *)duk_to_string(self.context.dukContext, [self push]);
    [self pop];
    return [NSString stringWithUTF8String:value];
}

- (NSDate *)toDate{
    return nil;
}

- (NSArray *)toArray{
    
    //if jsvalue is undefined or null
    //this returns nil
    if(self.isBoolean ||
       self.isNumber ||
       self.isString ||
       self.isObject){
        duk_error(self.context.dukContext, DUK_ERR_TYPE_ERROR, "Not an Array object");
    }
    return [self toObjectOfClass:[NSArray class]];
}

- (NSDictionary *)toDictionary{
    
    //if jsvalue is undefined or null
    //this returns nil
    if(self.isBoolean ||
       self.isNumber ||
       self.isString ||
       self.isArray){
        duk_error(self.context.dukContext, DUK_ERR_TYPE_ERROR, "Not an Object object");
    }
    return [self toObjectOfClass:[NSDictionary class]];
}

- (DTJSValue *)valueForProperty:(NSString *)property{
    
    DTJSValue *jsValue = [DTJSValue valueWithUndefinedInContext:self.context];
    if(![property isKindOfClass:[NSString class]]){
        return jsValue;
    }
    duk_idx_t obj_idx = [self push];//[... obj]
    if(duk_get_prop_string(self.context.dukContext, obj_idx, [property cStringUsingEncoding:NSUTF8StringEncoding])){//[... obj val]
        jsValue  = [DTJSValue valueWithValAtStackTopInContext:self.context];
    }
    [self pop2];//pops [obj val]
    return jsValue;
}

- (void)setValue:(id)value forProperty:(NSString *)property{
    
    if([property isKindOfClass:[NSString class]]){
        duk_idx_t obj_idx = [self push];//[... obj]
        [[DTJSValue valueWithObject:value inContext:self.context] push];//[... obj val]
        duk_put_prop_string(self.context.dukContext, obj_idx, [property cStringUsingEncoding:NSUTF8StringEncoding]);//[... obj]
        [self pop]; //pops [... obj]
    }
}

- (BOOL)deleteProperty:(NSString *)property{
    
    BOOL retVal = false;
    if([property isKindOfClass:[NSString class]]){
        duk_idx_t obj_idx = [self push];//[... obj]
        retVal = duk_del_prop_string(self.context.dukContext, obj_idx, [property cStringUsingEncoding:NSUTF8StringEncoding]);
        [self pop]; //pops [... obj]
    }
    return retVal;
}

- (BOOL)hasProperty:(NSString *)property{
    
    BOOL retVal = false;
    if([property isKindOfClass:[NSString class]]){
        duk_idx_t obj_idx = [self push];//[... obj]
        retVal = duk_has_prop_string(self.context.dukContext, obj_idx, [property cStringUsingEncoding:NSUTF8StringEncoding]);
        [self pop]; //pops [... obj]
    }
    return retVal;
}

/*!
 * Data Descriptor: contains one or both of the keys value and writable. Optionally containing one or both of the keys "enumerable" and "configurable"
 * Accessor Descriptor: contains one or both of the keys get and set. Optionally containing one or both of the keys "enumerable" and "configurable".
 * Genric Descriptor: contains one or both of the keys "enumerable" and "configurable".
 */
- (void)defineProperty:(NSString *)property descriptor:(id)descriptor{
    
    if([property isKindOfClass:[NSString class]]){
        if([descriptor isKindOfClass:[NSDictionary class]]){
            
            duk_idx_t obj_idx = [self push];//[... obj]
            duk_push_string(self.context.dukContext, [property cStringUsingEncoding:NSUTF8StringEncoding]);//[... obj key]
            
            id writable = [descriptor valueForKey:JSPropertyDescriptorWritableKey];
            id enumerable = [descriptor valueForKey:JSPropertyDescriptorEnumerableKey];
            id configurable = [descriptor valueForKey:JSPropertyDescriptorConfigurableKey];
            id value = [descriptor valueForKey:JSPropertyDescriptorValueKey];
            id get = [(NSValue *)[descriptor valueForKey:JSPropertyDescriptorGetKey] pointerValue];
            id set = [(NSValue *)[descriptor valueForKey:JSPropertyDescriptorSetKey] pointerValue];
            BOOL isDataDecriptor = value || writable;
            BOOL isAccessorDescriptor = get || set;
            
            duk_uint_t flags = 0;
            if(isDataDecriptor){ //Data Descriptor
                if(value){
                    [[DTJSValue valueWithObject:value inContext:self.context] push];//[... obj key val]
                    flags = DUK_DEFPROP_HAVE_VALUE;
                }
                if(writable){
                    if([writable isKindOfClass:[NSNumber class]]){
                        bool isWritable = [writable boolValue];
                        if(isWritable){
                            flags |= DUK_DEFPROP_SET_WRITABLE;
                        }
                    }
                }
            }
            else if (isAccessorDescriptor){ //Accessor Descriptor
                if(get){
                    duk_push_c_function(self.context.dukContext, (DTCFunction)get, 0);//[... obj key getter]
                    flags |= DUK_DEFPROP_HAVE_GETTER;
                }
                if(set){
                    duk_push_c_function(self.context.dukContext, (DTCFunction)set, 1);//[... obj key getter setter]
                    flags |= DUK_DEFPROP_HAVE_SETTER;
                }
            }
            
            // Genereic Descriptor
            {
                if(enumerable){
                    if([enumerable isKindOfClass:[NSNumber class]]){
                        bool isEnumerable = [enumerable boolValue];
                        if(isEnumerable){
                            flags |= DUK_DEFPROP_SET_ENUMERABLE;
                        }
                    }
                }
                if(configurable){
                    if([configurable isKindOfClass:[NSNumber class]]){
                        bool isConfigurable= [configurable boolValue];
                        if(isConfigurable){
                            flags |= DUK_DEFPROP_SET_CONFIGURABLE;
                        }
                    }
                }
            }
            duk_def_prop(self.context.dukContext, obj_idx, flags);//[... obj]
            [self pop];//pops [... obj]
        }
    }
}

- (DTJSValue *)valueAtIndex:(NSUInteger)index{
    
    DTJSValue *jsValue = [DTJSValue valueWithUndefinedInContext:self.context];
    duk_idx_t obj_idx = [self push];//[... obj]
    if(duk_get_prop_index(self.context.dukContext, obj_idx, (duk_uarridx_t)index)){//[... obj val]
        jsValue  = [DTJSValue valueWithValAtStackTopInContext:self.context];//[... obj val]
    }
    [self pop2];//pops [obj val]
    return jsValue;
}

- (void)setValue:(id)value atIndex:(NSUInteger)index{
    
    duk_idx_t obj_idx = [self push];//[... obj]
    [[DTJSValue valueWithObject:value inContext:self.context] push];//[... obj val]
    duk_put_prop_index(self.context.dukContext, obj_idx, (duk_uarridx_t)index);//[... obj]
    [self pop]; //pops [... obj]
}

- (BOOL)isEqualToObject:(id)value{
    
    BOOL retVal = false;
    if([value isKindOfClass:[DTJSValue class]]){
        duk_idx_t idx_1 = [self push];
        duk_idx_t idx_2 = [value push];//[... val1 val2]
        retVal = duk_strict_equals(self.context.dukContext, idx_1, idx_2);
        [self pop2];
    }
    return retVal;
}

- (BOOL)isEqualWithTypeCoercionToObject:(id)value{
    
    BOOL retVal = false;
    if([value isKindOfClass:[DTJSValue class]]){
        duk_idx_t idx_1 = [self push];
        duk_idx_t idx_2 = [value push];//[... val1 val2]
        retVal = duk_equals(self.context.dukContext, idx_1, idx_2);
        [self pop2];
    }
    return retVal;
    
}

- (BOOL)isInstanceOf:(id)value{
    
    BOOL retVal = false;
    if(value){
        duk_idx_t idx_1 = [self push];
        duk_idx_t idx_2 = [value push];//[... val1 val2]
        retVal = duk_instanceof(self.context.dukContext, idx_1, idx_2);
        [self pop2];
    }
    return retVal;
}

- (DTJSValue *)callWithArguments:(NSArray *)arguments{
    
    DTJSValue *retVal = [DTJSValue valueWithUndefinedInContext:self.context];
    duk_idx_t func_idx = [self push];//[... func]
    if(duk_is_callable(self.context.dukContext, func_idx)){
        if([arguments isKindOfClass:[NSArray class]]){
            for (id obj in arguments) {
                DTJSValue *argJSValue = [DTJSValue valueWithObject:obj inContext:self.context];
                [argJSValue push];
            }//[... func arg1 arg2 arg3 ...argN]
        }
        duk_int_t rc = duk_pcall(self.context.dukContext, (duk_idx_t)[arguments count]);//[... retVal/err]
        retVal = [DTJSValue valueWithValAtStackTopInContext:self.context];
        if (rc != DUK_EXEC_SUCCESS) {
            DTJSValue *exception = retVal;
            [self.context notifyExecption:exception];
        }
        [self pop];//pops [... retVal/err]
    }
    return retVal;
}

- (DTJSValue *)constructWithArguments:(NSArray *)arguments{

    DTJSValue *retVal = [DTJSValue valueWithUndefinedInContext:self.context];
    duk_idx_t func_idx = [self push];//[... func]
    if(duk_is_callable(self.context.dukContext, func_idx)){
        if([arguments isKindOfClass:[NSArray class]]){
            for (id obj in arguments) {
                DTJSValue *argJSValue = [DTJSValue valueWithObject:obj inContext:self.context];
                [argJSValue push];
            }//[... func arg1 arg2 arg3 ...argN]
        }
        duk_int_t rc = duk_pnew(self.context.dukContext, (duk_idx_t)[arguments count]);//[... retVal/err]
        retVal = [DTJSValue valueWithValAtStackTopInContext:self.context];
        if (rc != DUK_EXEC_SUCCESS) {
            DTJSValue *exception = retVal;
            [self.context notifyExecption:exception];
        }
        [self pop];//pops [... retVal/err]
    }
    return retVal;
}

- (DTJSValue *)invokeMethod:(NSString *)method withArguments:(NSArray *)arguments{

    DTJSValue *retVal = [DTJSValue valueWithUndefinedInContext:self.context];
    if([method isKindOfClass:[NSString class]]){
        duk_idx_t obj_idx = [self push];//[... obj]
        if(duk_is_function(self.context.dukContext, obj_idx)){
            [[DTJSValue valueWithString:method inContext:self.context] push];////[... obj key]
            if([arguments isKindOfClass:[NSArray class]]){
                for (id obj in arguments) {
                    DTJSValue *argJSValue = [DTJSValue valueWithObject:obj inContext:self.context];
                    [argJSValue push];
                }//[... obj key func arg1 arg2 arg3 ...argN]
            }
            duk_int_t rc = duk_pcall_prop(self.context.dukContext, obj_idx, (duk_idx_t)[arguments count]);//[... obj retVal/err]
            retVal = [DTJSValue valueWithValAtStackTopInContext:self.context];
            if (rc != DUK_EXEC_SUCCESS) {
                DTJSValue *exception = retVal;
                [self.context notifyExecption:exception];
            }
            [self pop2];//pops [... obj retVal/err]
        }
    }
    return retVal;
}

@end

@implementation DTJSValue (SubscriptSupport)

- (DTJSValue *)objectForKeyedSubscript:(id)key{
    
    DTJSValue *jsValue = [DTJSValue valueWithUndefinedInContext:self.context];
    if(![key isKindOfClass:[NSString class]]){
        key = [[DTJSValue valueWithObject:key inContext:self.context] toString];
        if(!key){
            return jsValue;
        }
    }
    return [self valueForProperty:key];
}

- (DTJSValue *)objectAtIndexedSubscript:(NSUInteger)index{
    
    return [self valueAtIndex:index];
}

- (void)setObject:(id)object forKeyedSubscript:(NSObject <NSCopying> *)key{
    
    if (![key isKindOfClass:[NSString class]]) {
        key = [[DTJSValue valueWithObject:key inContext:self.context] toString];
        if (!key)
            return;
    }
    [self setValue:object forProperty:(NSString *)key];
}

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index{
    
    [self setValue:object atIndex:index];
}

@end


@implementation DTJSValue (Internal)

#pragma mark - convienence intializaters for JS objects

+ (DTJSValue *)valueWithJSString:(const char *) string inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isString = true;
        jsValue.value->objectValue = (void *)string;
        [jsValue retainJSObjectValue];
    }
    return jsValue;
}

+ (DTJSValue *)valueWithJSArray:(void *)array inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isArray = true;
        jsValue.value->objectValue = array;
        [jsValue retainJSObjectValue];
    }
    return jsValue;
}

+ (DTJSValue *)valueWithJSObject:(void *)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue  = [[DTJSValue alloc] initWithContext:context];
        jsValue.isObject = true;
        jsValue.value->objectValue = value;
        [jsValue retainJSObjectValue];
    }
    return jsValue;
}

+ (DTJSValue *)valueWithJSFunction:(void *)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue  = [[DTJSValue alloc] initWithContext:context];
        jsValue.isFunction = true;
        jsValue.value->objectValue = value;
        [jsValue retainJSObjectValue];
    }
    return jsValue;
}

+ (DTJSValue *)valueWithPointer:(void *)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        if(value){
            jsValue = [[DTJSValue alloc] initWithContext:context];
            jsValue.isPointer = true;
            jsValue.value->objectValue =value;
        }
    }
    return jsValue;
}


+ (DTJSValue *)valueWithObjcClass:(Class)cls inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSExporter sharedInstance] exportClass:cls inContext:context];
        jsValue[@("\xFF" "className")] = NSStringFromClass(cls);
    }
    return jsValue;
}

+ (DTJSValue *)valueWithNewFunctionInContext:(DTJSContext *)context withCallback:(DTCFunction)aCallback noOfArgs:(NSInteger)nargs {
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isFunction = true;
        duk_idx_t obj_idx =  duk_push_c_function(context.dukContext, aCallback, (duk_idx_t)nargs);//[... obj]
        jsValue.value->objectValue = duk_require_heapptr(context.dukContext, obj_idx);
        [jsValue retainJSObjectValue];
        duk_pop(context.dukContext);//pops [... obj]
    }
    return jsValue;
}

+ (DTJSValue *)valueWithValAtStackIndex:(duk_idx_t)index inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        switch (duk_get_type(context.dukContext,index)) {
            case DUK_TYPE_UNDEFINED:
            {
                jsValue = [DTJSValue valueWithUndefinedInContext:context];
            }
                break;
            case DUK_TYPE_NULL:
            {
                jsValue = [DTJSValue valueWithNullInContext:context];
            }
                break;
            case DUK_TYPE_BOOLEAN:
            {
                BOOL value = duk_require_boolean(context.dukContext, index);
                jsValue = [DTJSValue valueWithBool:value inContext:context];
            }
                break;
            case DUK_TYPE_NUMBER:
            {
                double value = duk_require_number(context.dukContext, index);
                jsValue = [DTJSValue valueWithDouble:value inContext:context ];
            }
                break;
            case DUK_TYPE_STRING:
            {
                const char *value = duk_require_string(context.dukContext, index);
                jsValue = [DTJSValue valueWithJSString:value inContext:context];
            }
                break;
            case DUK_TYPE_OBJECT:
            {
                void *value =  duk_require_heapptr(context.dukContext, index);
                if(duk_is_array(context.dukContext, index)){
                    jsValue = [DTJSValue valueWithJSArray:value inContext:context];
                }
                else if (duk_is_function(context.dukContext, index)){
                    jsValue = [DTJSValue valueWithJSFunction:value inContext:context];
                }
                else{
                    jsValue = [DTJSValue valueWithJSObject:value inContext:context];
                }
            }
                break;
            case DUK_TYPE_POINTER:
            {
                void *value = duk_require_pointer(context.dukContext, index);
                jsValue = [DTJSValue valueWithPointer:value inContext:context];
            }
                break;
            default://DUK_TYPE_NONE
                jsValue = nil;
                break;
        }
    }
    return jsValue;
}

+ (DTJSValue *)valueWithValAtStackTopInContext:(DTJSContext *)context{
    
    return [DTJSValue valueWithValAtStackIndex:duk_require_top_index(context.dukContext) inContext:context];
}

#pragma mark - DTJSValue stack operations

- (duk_idx_t)push{
    
    if(self.isUndefined){
        duk_push_undefined(self.context.dukContext);
    }
    else if (self.isNull){
        duk_push_null(self.context.dukContext);
    }
    else if (self.isBoolean){
        duk_push_boolean(self.context.dukContext, (duk_bool_t)self.value->numberValue);
    }
    else if (self.isNumber){
        duk_push_number(self.context.dukContext, self.value->numberValue);
    }
    else if (self.isString){
        duk_push_string(self.context.dukContext, (const char *)self.value->objectValue);
    }
    else if(self.isArray ||
            self.isObject ||
            self.isFunction){
        duk_push_heapptr(self.context.dukContext, self.value->objectValue);
    }
    else if (self.isPointer){
        duk_push_pointer(self.context.dukContext, self.value->objectValue);
    }
    return duk_require_top_index(self.context.dukContext);
}

- (void)pop{
    
    duk_pop(self.context.dukContext);
}

- (void)pop2{
    
    duk_pop_2(self.context.dukContext);
}

#pragma mark - DTJSValue util methods

- (void *)objectValue{
    
    if(self.isString ||
       self.isArray ||
       self.isObject ||
       self.isFunction){
        if(self.value){
            return self.value->objectValue;
        }
    }
    return nil;
}

- (void)retainJSObjectValue{
    
    if(self.isString ||
       self.isArray ||
       self.isObject ||
       self.isFunction){
        duk_push_global_stash(self.context.dukContext);//[... gblStash]
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            duk_push_array(self.context.dukContext);//[... gblStash, arr]
            duk_put_prop_string(self.context.dukContext, -2, "retainArray");//[... gblStash]
        });
        
        duk_bool_t success = duk_get_prop_string(self.context.dukContext, -1, "retainArray");//[... gblStash, arr/unf]
        if(success){
            if(duk_is_array(self.context.dukContext, -1)){
                static duk_uarridx_t arr_idx = -1;
                //push jsValue in the array
                duk_push_heapptr(self.context.dukContext, self.objectValue);//[... gblStash, arr, val]
                duk_put_prop_index(self.context.dukContext, -2, ++arr_idx);//[... gblStash, arr]
                self.retainIndex = arr_idx;
            }
        }
        duk_pop_2(self.context.dukContext);//pops [... gblStash, arr/unf]
    }
}

- (void)releaseJSObjectValue{
    
    if(self.isString ||
       self.isArray ||
       self.isObject ||
       self.isFunction){
        if(!isnan(self.retainIndex)){
            duk_push_global_stash(self.context.dukContext);//[... gblStash]
            duk_bool_t success = duk_get_prop_string(self.context.dukContext, -1, "retainArray");//[... gblStash, arr/unf]
            if(success){
                if(duk_is_array(self.context.dukContext, -1)){
                    duk_del_prop_index(self.context.dukContext, -1, self.retainIndex);
                }
            }
        }
    }
}


- (void *)toPointer{
    void *value = duk_to_pointer(self.context.dukContext, [self push]);
    [self pop];
    return value;
}

@end
