//
//  DTJSVirtualMachine.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import "DTJSVirtualMachine.h"
#import "duktape.h"

@implementation DTJSVirtualMachine

#pragma mark initializers

- (instancetype)init{
    
    if(self = [super init]){
        duk_context *ctx = duk_create_heap_default();
        if (!ctx) {
            printf("Failed to create a Duktape heap.\n");
        }
        self.mainContext = ctx;
    }
    return self;
}

#pragma mark dealloc

- (void)dealloc{
    
    if(self.mainContext){
        duk_destroy_heap(self.mainContext);
        self.mainContext = nil;
    }
    [super dealloc];
}

@end
