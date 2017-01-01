//
//  DTJSValueInternal.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 28/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSValue.h"
#import "DTJSConstants.h"

@interface DTJSValue (Internal)

+ (DTJSValue *)valueWithJSString:(const char *) string inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithJSArray:(void *)array inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithJSObject:(void *)object inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithJSFunction:(void *)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithPointer:(void *)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithObjcClass:(Class)cls inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithNewFunctionInContext:(DTJSContext *)context withCallback:(DTCFunction)aCallback noOfArgs:(NSInteger)nargs;
+ (DTJSValue *)valueWithValAtStackIndex:(duk_idx_t)index inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithValAtStackTopInContext:(DTJSContext *)context;

- (duk_idx_t)push;
- (void)pop;
- (void)pop2;
- (void *)objectValue;
- (void)retainJSObjectValue;
- (void)releaseJSObjectValue;
- (void *)toPointer;


@end
