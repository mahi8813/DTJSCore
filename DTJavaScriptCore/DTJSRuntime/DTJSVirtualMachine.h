//
//  DTJSVirtualMachine.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "duk_config.h"

@interface DTJSVirtualMachine : NSObject

@property (nonatomic, assign) duk_context *mainContext;

- (instancetype)init;

@end
