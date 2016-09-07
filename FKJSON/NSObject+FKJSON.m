//
//  NSObject+FKJSON.m
//  FKJSON
//
//  Created by y_liang on 16/9/3.
//  Copyright © 2016年 y_liang. All rights reserved.
//

#import "NSObject+FKJSON.h"

@implementation NSObject (FKJSON)

+ (instancetype)fkjson_entityFromJSON:(id)json {
    return [FKJSON decodeJSON:json toClass:[self class]];
}
- (BOOL)fkjson_fillWithJSON:(id)json {
    return [FKJSON decodeJSON:json toObject:self];
}

- (id)fkjson_JSONObject {
    return [FKJSON encodeObject:self];
}
@end
