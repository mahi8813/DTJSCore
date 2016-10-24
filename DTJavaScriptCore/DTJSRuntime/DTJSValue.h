//
//  DTDTJSValue.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DTJSContext;

EXTERN_API(NSString *const JSPropertyDescriptorWritableKey);
EXTERN_API(NSString *const JSPropertyDescriptorEnumerableKey);
EXTERN_API(NSString *const JSPropertyDescriptorConfigurableKey);
EXTERN_API(NSString *const JSPropertyDescriptorValueKey);
EXTERN_API(NSString *const JSPropertyDescriptorGetKey);
EXTERN_API(NSString *const JSPropertyDescriptorSetKey);

@interface DTJSValue : NSObject

@property (nonatomic, assign) DTJSContext *context;

+ (DTJSValue *)valueWithObject:(id)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithBool:(BOOL)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithDouble:(double)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithInt32:(int32_t)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithUInt32:(uint32_t)value inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithNewObjectInContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithNewArrayInContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithNewErrorFromMessage:(NSString *)message inContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithNullInContext:(DTJSContext *)context;
+ (DTJSValue *)valueWithUndefinedInContext:(DTJSContext *)context;

@property (readonly) BOOL isUndefined;
@property (readonly) BOOL isNull;
@property (readonly) BOOL isBoolean;
@property (readonly) BOOL isNumber;
@property (readonly) BOOL isString;
@property (readonly) BOOL isObject;
@property (readonly) BOOL isArray;
@property (readonly) BOOL isDate;

- (id)toObject;
- (id)toObjectOfClass:(Class)expectedClass;
- (BOOL)toBool;
- (double)toDouble;
- (int32_t)toInt32;
- (uint32_t)toUInt32;
- (NSNumber *)toNumber;
- (NSString *)toString;
- (NSDate *)toDate;
- (NSArray *)toArray;
- (NSDictionary *)toDictionary;

- (DTJSValue *)valueForProperty:(NSString *)property;
- (void)setValue:(id)value forProperty:(NSString *)property;
- (BOOL)deleteProperty:(NSString *)property;
- (BOOL)hasProperty:(NSString *)property;
- (void)defineProperty:(NSString *)property descriptor:(id)descriptor;
- (DTJSValue *)valueAtIndex:(NSUInteger)index;
- (void)setValue:(id)value atIndex:(NSUInteger)index;

@end
