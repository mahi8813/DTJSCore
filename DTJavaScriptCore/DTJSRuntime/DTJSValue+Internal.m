//
//  DTJSValue+Internal.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 28/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSValue+Internal.h"
#import "DTJSContext.h"
#include "duktape.h"

@implementation DTJSValue (Internal)

@dynamic value;
@dynamic isUndefined;
@dynamic isNull;
@dynamic isBoolean;
@dynamic isNumber;
@dynamic isString;
@dynamic isObject;
@dynamic isArray;
@dynamic isDate;

+ (DTJSValue *)valueWithJSString:(const char *) string inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isString = true;
        jsValue.value->objectValue = (void *)string;
    }
    return jsValue;
}

+ (DTJSValue *)valueWithJSArray:(void *)array inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue = [[DTJSValue alloc] initWithContext:context];
        jsValue.isArray = true;
        jsValue.value->objectValue = array;
    }
    return jsValue;
}

+ (DTJSValue *)valueWithJSObject:(void *)value inContext:(DTJSContext *)context{
    
    DTJSValue *jsValue = nil;
    if(context){
        jsValue  = [[DTJSValue alloc] initWithContext:context];
        jsValue.isObject = true;
        jsValue.value->objectValue = value;
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
                void *value =  duk_get_heapptr(context.dukContext, index);
                if(duk_is_array(context.dukContext, index)){
                    jsValue = [DTJSValue valueWithJSArray:value inContext:context];
                }
                else{
                    jsValue = [DTJSValue valueWithJSObject:value inContext:context];
                }
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
    
    return [DTJSValue valueWithValAtStackIndex:-1 inContext:context];
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
            self.isObject){
        duk_push_heapptr(self.context.dukContext, self.value->objectValue);
    }
    return duk_require_top_index(self.context.dukContext);
}

- (void)pop{
    
    duk_pop(self.context.dukContext);
}

@end
