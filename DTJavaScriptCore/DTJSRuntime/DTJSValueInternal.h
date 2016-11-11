//
//  DTJSValueInternal.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 28/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "duk_config.h"

typedef union Value{
    double numberValue;
    void *objectValue;
}Value;

@interface DTJSValue (Internal)

@property (nonatomic, assign) Value *value;

//redeclared to allow readwrite internally
@property (readwrite) BOOL isUndefined;
@property (readwrite) BOOL isNull;
@property (readwrite) BOOL isBoolean;
@property (readwrite) BOOL isNumber;
@property (readwrite) BOOL isString;
@property (readwrite) BOOL isObject;
@property (readwrite) BOOL isArray;
@property (readwrite) BOOL isDate;

+ (DTJSValue *)valueWithJSString:(const char *) string inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithJSArray:(void *)array inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithJSObject:(void *)object inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithValAtStackIndex:(duk_idx_t)index inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithValAtStackTopInContext:(DTJSContext *)context;

- (duk_idx_t)push;
- (void)pop;
- (void)pop2;

@end
