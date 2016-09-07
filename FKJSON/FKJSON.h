//
//  FKJSON.h
//  FKJSON
//
//  Created by y_liang on 16/9/3.
//  Copyright © 2016年 y_liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>


typedef NSDictionary<NSString *, id/* NSString/NSArray */> *FKJSONPropertyMappingType;
typedef NSDictionary<NSString *, Class> *FKJSONGenericClassMappingType;
typedef NSArray<NSString *> *FKJSONPropertyFilterType;

typedef FKJSONPropertyMappingType (^FKJSONPropertyMapping)(Class entityClass);
typedef FKJSONGenericClassMappingType (^FKJSONGenericClassMapping)(Class entityClass);
typedef FKJSONPropertyFilterType (^FKJSONPropertyFilter)(Class entityClass);

@protocol FKJSONEntity <NSObject>
@optional
- (id)fkjson_valueForKey:(NSString *)key;
- (BOOL)fkjson_setValue:(id)value forKey:(NSString *)key;
@end

@protocol FKJSONMetaEntity <NSObject>
@optional
//属性映射表
+ (FKJSONPropertyMappingType)fkjson_propertyMapping;
//设置容器属性的元素类型
+ (FKJSONGenericClassMappingType)fkjson_containerElementGenericTypeMapping;
//不需要解析的属性列表
+ (FKJSONPropertyFilterType)fkjson_propertyFilter;
@end


@interface FKJSON : NSObject

+ (id)decodeJSON:(id)json toClass:(Class)clazz;
+ (BOOL)decodeJSON:(id)json toObject:(id)object;

+ (id)decodeJSON:(id)json toClass:(Class)clazz propertyMapping:(FKJSONPropertyMapping)propertyMapping genericTypeMapping:(FKJSONGenericClassMapping)genericTypeMapping propertyFilter:(FKJSONPropertyFilter)propertyFilter;
+ (BOOL)decodeJSON:(id)json toObject:(id)object propertyMapping:(FKJSONPropertyMapping)propertyMapping genericTypeMapping:(FKJSONGenericClassMapping)genericTypeMapping propertyFilter:(FKJSONPropertyFilter)propertyFilter;


+ (id)encodeObject:(NSObject *)object;
+ (id)encodeObject:(NSObject *)object propertyMapping:(FKJSONPropertyMapping)propertyMapping propertyFilter:(FKJSONPropertyFilter)propertyFilter;

@end

