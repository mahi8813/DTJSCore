//
//  DTJSConstants.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 23/12/16.
//  Copyright © 2016 kony. All rights reserved.
//

#ifndef DTJSConstants_h
#define DTJSConstants_h

#import "duktape.h"

#define DUK_C_FUNCTION(funcName) static duk_ret_t funcName(duk_context *ctx)

typedef duk_c_function DTCFunction;

#endif /* DTJSConstants_h */
