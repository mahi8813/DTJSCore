//
//  DTJSExporter.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 20/11/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DTJSValue;
@class DTJSContext;

@interface DTJSExporter : NSObject

+ (DTJSValue *)exportClass:(Class)cls inContext:(DTJSContext *)context;
+ (NSString *)propertyNameFromSelector:(SEL)selector;

@end
