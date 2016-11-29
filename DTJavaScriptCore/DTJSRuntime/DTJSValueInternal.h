//
//  DTJSValueInternal.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 28/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "duktape.h"
#import "DTJSValue.h"

#define DUK_CALLBACK(funcName) duk_ret_t funcName(duk_context *ctx)

typedef duk_c_function DukCallback;

@interface DTJSValue (Internal)

+ (DTJSValue *)valueWithJSString:(const char *) string inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithJSArray:(void *)array inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithJSObject:(void *)object inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithObjcClass:(Class)cls inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithNewFunctionWithAssociatedDukCallback:(DukCallback)aDukCallback inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithValAtStackIndex:(duk_idx_t)index inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithValAtStackTopInContext:(DTJSContext *)context;

- (duk_idx_t)push;
- (void)pop;
- (void)pop2;

@end
