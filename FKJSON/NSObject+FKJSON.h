//
//  NSObject+FKJSON.h
//  FKJSON
//
//  Created by y_liang on 16/9/3.
//  Copyright © 2016年 y_liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FKJSON.h"

@interface NSObject (FKJSON)

+ (instancetype)fkjson_entityFromJSON:(id)json;
- (BOOL)fkjson_fillWithJSON:(id)json;
//NSArray or NSDictionary
- (id)fkjson_JSONObject;

@end
