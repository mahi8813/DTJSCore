//
//  DTJSExport.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 20/11/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DTJSValueInternal.h"

DUK_CALLBACK(JSObjectConstructorCallback);

@class DTJSValue;
@class DTJSContext;

@interface DTJSExport : NSObject

+ (void)exportClass:(Class)cls toJSValue:(DTJSValue *)jsValue inContext:(DTJSContext *)context;

@end

@interface NSString (JSMethod)

+ (NSString *)jsMethodStringWithSelector:(SEL)aSelector;

@end
