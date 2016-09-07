//
//  FKJSON.m
//  FKJSON
//
//  Created by y_liang on 16/9/3.
//  Copyright © 2016年 y_liang. All rights reserved.
//

#import "FKJSON.h"
#import <objc/message.h>

NSString *const FKJSON_NULL                    = @"NULL";

@interface FKJSONPropertyInfo : NSObject
@property (nonatomic, copy) NSString *name;         //属性名字
@property (nonatomic, copy) NSString *iVar;         //实例变量名字
@property (nonatomic, assign) char typePrefix;      //类型编码
@property (nonatomic, assign) Class clazz;          //属性类型（若值类型）
@property (nonatomic, assign) BOOL readonly;        //只读
@property (nonatomic, copy) NSString *setter;
@property (nonatomic, copy) NSString *getter;

- (instancetype)initWithProperty:(objc_property_t)property;
@end

@implementation FKJSONPropertyInfo

- (instancetype)init {
    NSAssert(true, @"不允许通过init初始化");
    return nil;
}

- (instancetype)initWithProperty:(objc_property_t)property {
    if (!property) return nil;
    self = [super init];
    if (self) {
        const char *propertyName = property_getName(property);
        if (propertyName) {
            self.name = [NSString stringWithUTF8String:propertyName];
        }
        
        //get property attributes
        /* 请参考官网地址
         https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW5
         */
        
        unsigned int outCount;
        objc_property_attribute_t *attributes = property_copyAttributeList(property, &outCount);
        //解析property的特征信息
        for (NSInteger i = 0; i < outCount; i++) {
            objc_property_attribute_t attri = attributes[i];
            switch (attri.name[0]) {
                case 'T': {
                    size_t len = strlen(attri.value);
                    if (len > 0) {
                        self.typePrefix = attri.value[0];
                        if (self.typePrefix == '@') {
                            if (len > 3) {
                                char clazzName[len - 2];
                                clazzName[len - 3] = '\0';
                                memcpy(clazzName, attri.value + 2, len - 3);
                                self.clazz = objc_getClass(clazzName);
                            }
                        }
                    }
                }
                    break;
                case 'V': {
                    if (attri.value) {
                        self.iVar = [NSString stringWithUTF8String:attri.value];
                    }
                }
                    break;
                case 'G': {
                    if (attri.value) {
                        self.getter = [NSString stringWithUTF8String:attri.value];
                    }
                }
                    break;
                case 'S': {
                    if (attri.value) {
                        self.setter = [NSString stringWithUTF8String:attri.value];
                    }
                }
                    break;
                case 'R': {
                    self.readonly = YES;
                }
                    break;
                default:
                    break;
            }
        }
        
        if (attributes) {
            free(attributes); attributes = NULL;
        }
        
        if (self.name.length) {
            if (!self.getter) {
                self.getter = self.name;
            }
            if (!self.setter && !self.readonly) {
                self.setter = [NSString stringWithFormat:@"set%@%@:", [self.name substringToIndex:1].uppercaseString, [self.name substringFromIndex:1]];
            }
        }
    }
    return self;
}
@end

@interface FKJSONClassInfo : NSObject
@property (nonatomic, assign, readonly) Class clazz;
@property (nonatomic, assign, readonly) Class superClazz;
@property (nonatomic, copy) NSArray<FKJSONPropertyInfo*> *properties;//存储当前类的所有属性，不做任何筛选操作

- (instancetype)initWithClass:(Class)clazz;
@end

@implementation FKJSONClassInfo

- (instancetype)init {
    NSAssert(true, @"不允许通过init初始化");
    return nil;
}

- (instancetype)initWithClass:(Class)clazz {
    if (!clazz) return nil;
    self = [super init];
    if (self) {
        _clazz = clazz;
        _superClazz = class_getSuperclass(clazz);
    }
    return self;
}

- (NSArray *)properties {
    if (!_properties) {
        unsigned int propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList(self.clazz, &propertyCount);
        if (properties) {
            NSMutableArray *propertyList = [@[] mutableCopy];
            for (unsigned int i = 0; i < propertyCount; i++) {
                FKJSONPropertyInfo *property = [[FKJSONPropertyInfo alloc] initWithProperty:properties[i]];
                [propertyList addObject:property];
            }
            free(properties);properties = NULL;
            _properties = [propertyList copy];
        }
    }
    return _properties;
}

@end

@interface FKJSONConfig : NSObject
@property (nonatomic, copy) FKJSONPropertyMappingType propertyMapping;
@property (nonatomic, copy) FKJSONGenericClassMappingType containerElementGenericTypeMapping;
@property (nonatomic, copy) NSSet<NSString *> *propertyFilter;

- (FKJSONConfig *)combine:(FKJSONConfig *)config;
@end

@implementation FKJSONConfig

- (FKJSONConfig *)combine:(FKJSONConfig *)anConfig {
    NSMutableDictionary<NSString *, id> *propertyMapping = [[NSMutableDictionary alloc] initWithCapacity:5];
    NSMutableDictionary<NSString *, Class> *genericTypeMapping = [[NSMutableDictionary alloc] initWithCapacity:5];
    NSMutableSet<NSString *> *propertyFilter = [[NSMutableSet alloc] initWithCapacity:5];
    
    if (self.propertyMapping) {
        [propertyMapping addEntriesFromDictionary:self.propertyMapping];
    }
    if (anConfig.propertyMapping) {
        [propertyMapping addEntriesFromDictionary:anConfig.propertyMapping];
    }
    
    if (self.containerElementGenericTypeMapping) {
        [genericTypeMapping addEntriesFromDictionary:self.containerElementGenericTypeMapping];
    }
    if (anConfig.containerElementGenericTypeMapping) {
        [genericTypeMapping addEntriesFromDictionary:anConfig.containerElementGenericTypeMapping];
    }
    
    if (self.propertyFilter) {
        [propertyFilter unionSet:self.propertyFilter];
    }
    if (anConfig.propertyFilter) {
        [propertyFilter unionSet:anConfig.propertyFilter];
    }
    
    
    FKJSONConfig *config = [FKJSONConfig new];
    config.propertyMapping = propertyMapping;
    config.containerElementGenericTypeMapping = genericTypeMapping;
    config.propertyFilter = propertyFilter;
    return config;
}
@end

static FKJSONConfig* fkjson_create_config_from_class(Class clazz) {
    if (!clazz) return nil;
    
    NSMutableArray *clazzStack = [NSMutableArray new];
    Class superClazz = class_getSuperclass(clazz);
    while (clazz && superClazz) {
        [clazzStack addObject:clazz];
        clazz = superClazz;
        superClazz = class_getSuperclass(clazz);
    }
    
    NSMutableDictionary<NSString *, id> *propertyMapping = [[NSMutableDictionary alloc] initWithCapacity:5];
    NSMutableDictionary<NSString *, Class> *genericTypeMapping = [[NSMutableDictionary alloc] initWithCapacity:5];
    NSMutableSet<NSString *> *propertyFilter = [[NSMutableSet alloc] initWithCapacity:5];
    
    for (NSInteger i = clazzStack.count - 1; i >= 0 ; i--) {
        Class clazz = clazzStack[i];
        if ([clazz respondsToSelector:@selector(fkjson_propertyMapping)]) {
            FKJSONPropertyMappingType mapping = [(id<FKJSONMetaEntity>)clazz fkjson_propertyMapping];
            if (mapping) {
                [propertyMapping addEntriesFromDictionary:mapping];
            }
        }
        
        if ([clazz respondsToSelector:@selector(fkjson_containerElementGenericTypeMapping)]) {
            FKJSONGenericClassMappingType mapping = [(id<FKJSONMetaEntity>)clazz fkjson_containerElementGenericTypeMapping];
            if (mapping) {
                [genericTypeMapping addEntriesFromDictionary:mapping];
            }
        }
        
        if ([clazz respondsToSelector:@selector(fkjson_propertyFilter)]) {
            FKJSONPropertyFilterType filter = [(id<FKJSONMetaEntity>)clazz fkjson_propertyFilter];
            if (filter) {
                [propertyFilter addObjectsFromArray:filter];
            }
        }
    }
    
    FKJSONConfig *config = [FKJSONConfig new];
    config.propertyMapping = propertyMapping;
    config.containerElementGenericTypeMapping = genericTypeMapping;
    config.propertyFilter = propertyFilter;
    return config;
}

static FKJSONClassInfo* fkjson_get_class_info(Class clazz) {
    NSString *key = NSStringFromClass(clazz);
    if (!clazz || !key) return nil;
    
    static NSCache<NSString*, FKJSONClassInfo*> *s_class_info_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_class_info_cache = [NSCache new];
    });
    
    FKJSONClassInfo *clazzInfo = [s_class_info_cache objectForKey:key];
    
    if (!clazzInfo) {
        clazzInfo = [[FKJSONClassInfo alloc] initWithClass:clazz];
        if (clazzInfo) {
            [s_class_info_cache setObject:clazzInfo forKey:key];
        }
    }
    return clazzInfo;
}

static FKJSONConfig * fkjson_get_global_config_for_class(Class clazz) {
    NSString *key = NSStringFromClass(clazz);
    
    static NSCache<NSString*, FKJSONConfig*> *s_config_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_config_cache = [NSCache new];
    });
    
    FKJSONConfig *config = [s_config_cache objectForKey:key];
    
    if (!config) {
        config = fkjson_create_config_from_class(clazz);
        if (config) {
            [s_config_cache setObject:config forKey:key];
        }
    }
    return config;
}

//函数内部不做参数类型校验
static id fkjson_object_for_key_path_in_dictionary(NSDictionary *dic, NSString *keyPath) {
    if (!dic || !keyPath.length) return nil;
    NSArray *keyComponents = [keyPath componentsSeparatedByString:@"."];
    id value = nil;
    NSUInteger max = keyComponents.count;
    for (NSUInteger i = 0; i < max; i++) {
        value = dic[keyComponents[i]];
        if (i + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            } else {
                return nil;
            }
        }
    }
    return value;
}
static void fkjson_set_value_for_key_path_in_dictionary(id value, NSString *keyPath, NSMutableDictionary *dic) {
    if (!value || !keyPath || !dic) return;
    if (![keyPath isKindOfClass:NSString.class]) return;
    if (!keyPath.length) return;
    
    NSArray *keyComponents = [keyPath componentsSeparatedByString:@"."];
    NSUInteger max = keyComponents.count;
    if (max == 0) return;
    if (max == 1) {
        dic[keyPath] = value;
        return;
    }
    
    NSMutableDictionary *superDic = dic;
    NSMutableDictionary *subDic = nil;
    for (NSUInteger i = 0; i < max; i++) {
        NSString *key = keyComponents[i];
        id object = superDic[key];
        if ([object isKindOfClass:NSMutableDictionary.class]) {
            subDic = (NSMutableDictionary *)object;
        } else if ([object isKindOfClass:NSDictionary.class]) {
            subDic = [(NSDictionary *)object mutableCopy];
        } else {
            subDic = [@{} mutableCopy];
        }
        superDic[key] = subDic;
        
        if (i + 1 < max) {
            superDic = superDic;subDic = nil;
            continue;
        } else {
            subDic[key] = value;
        }
    }
}

static void fkjson_safe_kvc_set(id object, NSString *key, id value) {
    @try {
        [object setValue:value forKey:key];
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    } @finally {
        
    }
}

static id fkjson_safe_kvc_get(id object, NSString *key) {
    @try {
        return [object valueForKey:key];
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    } @finally {
        
    }
    return nil;
}

static id fkjson_transform_value_to_normal_type_property(id value, FKJSONPropertyInfo *property) {
    if (value == nil || value == (id)kCFNull) {
        return nil;
    }
    switch (property.typePrefix)
    {
        case 'c'://	A char
        case 'i'://	An int
        case 's'://	A short
        case 'l'://	A longl is treated as a 32-bit quantity on 64-bit programs.
        case 'q'://	A long long
        case 'C'://	An unsigned char
        case 'I'://	An unsigned int
        case 'S'://	An unsigned short
        case 'L'://	An unsigned long
        case 'Q'://	An unsigned long long
        {
            if ([value respondsToSelector:@selector(longLongValue)]) {
                return @([(NSNumber *)value longLongValue]);
            }
            return nil;
        } break;
        case 'B'://	A C++ bool or a C99 _Bool
        {
            if ([value respondsToSelector:@selector(boolValue)]) {
                return @([(NSNumber *)value boolValue]);
            }
            return nil;
        } break;
        case 'f'://	A float
        case 'd'://	A double
        {
            if ([value respondsToSelector:@selector(doubleValue)]) {
                return @([(NSNumber *)value doubleValue]);
            } else if ([value respondsToSelector:@selector(longLongValue)]) {
                return @([(NSNumber *)value longLongValue]);
            }
            return nil;
        } break;
        case 'v'://	A void
        {// 默认的不支持
            return nil;
        } break;
        case '*'://	A character string (char *)
        {// 转换成NSString encode
            if ([value isKindOfClass:[NSString class]]) {
                if (![[(NSString *)value uppercaseString] isEqualToString:FKJSON_NULL]) {
                    return value;
                }
            } else {
                if (value) return [NSString stringWithFormat:@"%@",value];
            }
            return nil;
        } break;
        case '@'://	An object (whether statically typed or typed id)
        {// 将对象还原出来 再 encode
            return nil;
        } break;
        case '#'://	A class object (Class)
        {
            Class clazz = Nil;
            if ([value isKindOfClass:[NSString class]]) {
                clazz = NSClassFromString(value);
            }
            return clazz;
        }break;
        case ':'://	A method selector (SEL) ,@encode(SEL) ':v@:@'
        case '[': //[array type]	An array (C array)
        case '{': //{name=type...}	A structure
        case '(': //(name=type...)	A union
        case 'b': //'bnum'	A bit field of num bits
        case '^': //^type	A pointer to type
        case '?': //	An unknown type (among other things, this code is used for function pointers)
        default:
        {// 以上数据取出
            return nil;
        } break;
    }
    return nil;
}

static id fkjson_transform_value_to_oc_container(id value, Class targetClazz, Class genericType) {
    if (!value) return nil;
    
    if ([targetClazz isSubclassOfClass:NSArray.class]) {//数组
        NSArray *valueArray = nil;
        if ([value isKindOfClass:NSArray.class]) valueArray = value;
        else if ([value isKindOfClass:[NSSet class]]) valueArray = ((NSSet *)value).allObjects;
        
        if (valueArray) {
            if (!genericType) {
                if (targetClazz == NSArray.class) return valueArray;
                else return [valueArray mutableCopy];
            } else {
                NSMutableArray *objectArray = [NSMutableArray new];
                for (id obj in valueArray) {
                    if ([obj isKindOfClass:genericType]) {
                        [objectArray addObject:obj];
                    } else {
                        id anObject = [FKJSON decodeJSON:obj toClass:genericType];
                        if (anObject) [objectArray addObject:anObject];
                    }
                }
                return objectArray;
            }
        }
    } else if ([targetClazz isSubclassOfClass:NSDictionary.class]) {//字典
        if ([value isKindOfClass:NSDictionary.class]) {
            if (!genericType) {
                if (targetClazz == NSDictionary.class) return value;
                else return [(NSDictionary *)value mutableCopy];
            } else {
                NSMutableDictionary *dic = [NSMutableDictionary new];
                [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                    if ([oneValue isKindOfClass:genericType]) {
                        dic[oneKey] = oneValue;
                    } else {
                        id anObject = [FKJSON decodeJSON:oneValue toClass:genericType];
                        if (anObject) dic[oneKey] = anObject;
                    }
                }];
                return dic;
            }
        }
    } else if ([targetClazz isSubclassOfClass:NSSet.class]) {//set
        NSSet *valueSet = nil;
        if ([value isKindOfClass:[NSArray class]]) valueSet = [NSSet setWithArray:value];
        else if ([value isKindOfClass:[NSSet class]]) valueSet = ((NSSet *)value);
        if (!genericType) {
            if (targetClazz == NSSet.class) return valueSet;
            else return [valueSet mutableCopy];
        } else {
            NSMutableSet *set = [NSMutableSet new];
            for (id one in valueSet) {
                if ([one isKindOfClass:genericType]) {
                    [set addObject:one];
                } else {
                    id anObject = [FKJSON decodeJSON:one toClass:genericType];
                    if (anObject) [set addObject:anObject];
                }
            }
            return set;
        }
    }
    return nil;
}

static NSNumber *fkjson_transform_value_to_number(id value) {
    static NSCharacterSet *dot;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        dic = @{@"TRUE" :   @(YES),
                @"True" :   @(YES),
                @"true" :   @(YES),
                @"FALSE" :  @(NO),
                @"False" :  @(NO),
                @"false" :  @(NO),
                @"YES" :    @(YES),
                @"Yes" :    @(YES),
                @"yes" :    @(YES),
                @"NO" :     @(NO),
                @"No" :     @(NO),
                @"no" :     @(NO),
                @"NIL" :    (id)kCFNull,
                @"Nil" :    (id)kCFNull,
                @"nil" :    (id)kCFNull,
                @"NULL" :   (id)kCFNull,
                @"Null" :   (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(NULL)" : (id)kCFNull,
                @"(Null)" : (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<NULL>" : (id)kCFNull,
                @"<Null>" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSNumber *num = dic[value];
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            double num = atof(cstring);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } else {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            return @(atoll(cstring));
        }
    }
    return nil;
}

//##################################################
@interface FKJSON()
@property (nonatomic, copy) FKJSONPropertyMapping propertyMapping;
@property (nonatomic, copy) FKJSONGenericClassMapping genericTypeMapping;
@property (nonatomic, copy) FKJSONPropertyFilter propertyFilter;
@end

@implementation FKJSON

+ (id)decodeJSON:(id)json toClass:(Class)clazz {
    return [self decodeJSON:json toClass:clazz propertyMapping:NULL genericTypeMapping:NULL propertyFilter:NULL];
}
+ (BOOL)decodeJSON:(id)json toObject:(id)object {
    return [self decodeJSON:json toObject:object propertyMapping:NULL genericTypeMapping:NULL propertyFilter:NULL];
}

+ (id)decodeJSON:(id)json toClass:(Class)clazz propertyMapping:(FKJSONPropertyMapping)propertyMapping genericTypeMapping:(FKJSONGenericClassMapping)genericTypeMapping propertyFilter:(FKJSONPropertyFilter)propertyFilter {
    if (!clazz) return nil;
    id object = [clazz new];
    return [self decodeJSON:json toObject:object propertyMapping:propertyMapping genericTypeMapping:genericTypeMapping propertyFilter:propertyFilter] ? object : nil;
}

static NSDictionary* fkjson_dictionary_with_json(id json) {
    if (!json) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return dic;
}

+ (BOOL)decodeJSON:(id)json toObject:(id)object propertyMapping:(FKJSONPropertyMapping)propertyMapping genericTypeMapping:(FKJSONGenericClassMapping)genericTypeMapping propertyFilter:(FKJSONPropertyFilter)propertyFilter {
    NSDictionary *jsonDic = fkjson_dictionary_with_json(json);
    if (jsonDic) {
        FKJSON *jsonCoder = [FKJSON new];
        jsonCoder.propertyMapping = propertyMapping;
        jsonCoder.genericTypeMapping = genericTypeMapping;
        jsonCoder.propertyFilter = propertyFilter;
        return [jsonCoder decodeJSONDictionary:jsonDic toObject:object];
    } else {
        return NO;
    }
}

//按照类的继承层次解析JSON
- (BOOL)decodeJSONDictionary:(NSDictionary *)json toObject:(id)object {
    if (!json || !object) return NO;
    if (![json isKindOfClass:NSDictionary.class]) return NO;
    
    BOOL rt = YES;
    Class clazz = [object class];
    FKJSONConfig *config = [FKJSONConfig new];
    if (self.propertyMapping) {
        config.propertyMapping = self.propertyMapping(clazz);
    }
    if (self.genericTypeMapping) {
        config.containerElementGenericTypeMapping = self.genericTypeMapping(clazz);
    }
    if (self.propertyFilter) {
        FKJSONPropertyFilterType filter = self.propertyFilter(clazz);
        if (filter) {
            config.propertyFilter = [NSSet setWithArray:filter];
        }
    }
    
    FKJSONClassInfo *clazzInfo = fkjson_get_class_info(clazz);
    while (clazzInfo && clazzInfo.superClazz != Nil) {//根类（NSObject/NSProxy）不予解析
        rt = [self decodeJSONDictionary:json toObject:object withJSONClassInfo:clazzInfo configInfo:config];
        clazzInfo = fkjson_get_class_info(clazzInfo.superClazz);
    }
    
    return rt;
}

//解析某个继承层次上的所有属性
- (BOOL)decodeJSONDictionary:(NSDictionary *)json toObject:(id)object withJSONClassInfo:(FKJSONClassInfo *)clazzInfo configInfo:(FKJSONConfig *)anConfig {
    if (!json || !object || !clazzInfo) return  NO;
    if (![json isKindOfClass:NSDictionary.class]) return NO;
    if (![object isKindOfClass:clazzInfo.clazz]) return NO;
    
    //step 0:获取配置信息
    FKJSONConfig *config = fkjson_get_global_config_for_class([object class]);
    if (config && anConfig) {
        config = [config combine:anConfig];
    } else {
        config = anConfig;
    }
    
    // step 1:从jsonDic中读取property对应的原始value
    for (FKJSONPropertyInfo *property in clazzInfo.properties) {
        //过滤掉不需要关心的属性
        if ([config.propertyFilter containsObject:property.name]) continue;
        
        NSString *keyPath = config.propertyMapping[property.name];
        if (!keyPath) keyPath = property.name;
        
        __block id value = nil;
        if ([keyPath isKindOfClass:[NSString class]]) {//单个key/keyPath
            value = fkjson_object_for_key_path_in_dictionary(json, keyPath);
        } else if ([keyPath isKindOfClass:[NSArray class]]){//multi keys/keyPaths
            NSArray *keyPaths = (NSArray *)keyPath;keyPath = nil;
            [keyPaths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj isKindOfClass:[NSString class]]) {
                    NSString *keyPath = (NSString *)obj;
                    value = fkjson_object_for_key_path_in_dictionary(json, keyPath);
                    if (value) {
                        *stop = YES;
                    }
                }
            }];
        }
        
        // step 2:询问是否需要自定义解析规则，特别是在处理一些特殊类型的时候，比如：c struct、c array、以及其他无法解析的类型
        BOOL setFlag = NO;
        if ([object respondsToSelector:@selector(fkjson_setValue:forKey:)]) {
            setFlag = [(id<FKJSONEntity>)object fkjson_setValue:value forKey:property.name];
        }
        if (!setFlag) {
            // step 3:自动将value转换为正确的property type
            if (property.typePrefix == '@') {
                value = [self transformValue:value toOcTypeProperty:property withJSONConfig:config];
            } else {
                value = fkjson_transform_value_to_normal_type_property(value, property);
            }
            
            //设置property的值
            if (value) {
                fkjson_safe_kvc_set(object, property.iVar, value);
            }
        }
    }
    return YES;
}

- (id)transformValue:(id)value toOcTypeProperty:(FKJSONPropertyInfo *)property withJSONConfig:(FKJSONConfig *)configInfo {
    if (!value || !property) return nil;
    if ([property.clazz isSubclassOfClass:NSArray.class] ||
        [property.clazz isSubclassOfClass:NSSet.class] ||
        [property.clazz isSubclassOfClass:NSDictionary.class]) { //1、对象容器，需要询问元素类型
        Class genericClass = configInfo.containerElementGenericTypeMapping[property.name];
        return fkjson_transform_value_to_oc_container(value, property.clazz, genericClass);
    } else if (property.clazz == NSString.class) {//3 NSString
        if ([value isKindOfClass:NSString.class]) {
            return [value copy];
        } else {
            if ([value respondsToSelector:@selector(stringValue)]) {
                return [(NSNumber *)value stringValue];
            } else {
                NSCAssert(true, @"无法解析成NSString");
                return nil;
            }
        }
    } else if (property.clazz == NSMutableString.class) {
        if ([value isKindOfClass:NSString.class]) {
            return [value mutableCopy];
        } else {
            if ([value respondsToSelector:@selector(stringValue)]) {
                return [[(NSNumber *)value stringValue] mutableCopy];
            } else {
                NSCAssert(true, @"无法解析成NSMutableString");
                return nil;
            }
        }
    } else if (property.clazz == NSNumber.class) {//NSNumber
        return fkjson_transform_value_to_number(value);
    } else if (property.clazz == NSValue.class) {//NSValue
        if ([value isKindOfClass:NSValue.class]) return value;
    } else if (property.clazz == NSData.class) {//NSData
        if ([value isKindOfClass:NSDate.class]) {
            return [(NSData *)value copy];
        } else if ([value isKindOfClass:NSString.class]) {
            return [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
        }
    } else if (property.clazz == NSMutableData.class) {
        if ([value isKindOfClass:NSDate.class]) {
            return [(NSData *)value mutableCopy];
        } else if ([value isKindOfClass:NSString.class]) {
            return [[(NSString *)value dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
        }
    } else if (property.clazz == NSDate.class) {//日期
        if ([value isKindOfClass:NSDate.class]) {
            return value;
        } else {//支持时间戳
            NSNumber *timeNumber = nil;
            if ([value isKindOfClass:NSNumber.class]) {
                timeNumber = value;
            } else if ([value isKindOfClass:NSString.class]) {
                timeNumber = @([(NSString *)value doubleValue]);
            }
            if (timeNumber) {
                NSString *timeString = [timeNumber stringValue];
                NSTimeInterval timeInterval = [timeNumber doubleValue];
                if (timeString.length == 10) {
                    return [NSDate dateWithTimeIntervalSince1970:timeInterval];
                } else if (timeString.length == 13) {
                    return [NSDate dateWithTimeIntervalSince1970:timeInterval/1000.0f];
                }
            }
            NSCAssert(true, @"无法解析成时间格式");
        }
    } else if (property.clazz == NSURL.class) {
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length]) {
            return [NSURL URLWithString:(NSString *)value];
        } else if ([value isKindOfClass:NSURL.class]) {
            return value;
        }
    } else {//普通对象
        id object = [property.clazz new];
        return [self decodeJSONDictionary:value toObject:object] ? object : nil;
    }
    return nil;
}

/*  By apple:
 Returns YES if the given object can be converted to JSON data, NO otherwise. The object must have the following properties:
 - Top level object is an NSArray or NSDictionary
 - All objects are NSString, NSNumber, NSArray, NSDictionary, or NSNull
 - All dictionary keys are NSStrings
 - NSNumbers are not NaN or infinity
 Other rules may apply. Calling this method or attempting a conversion are the definitive ways to tell if a given object can be converted to JSON data.
 */
+ (id)encodeObject:(NSObject *)object {
    return [self encodeObject:object propertyMapping:NULL propertyFilter:NULL];
}
+ (id)encodeObject:(NSObject *)object propertyMapping:(FKJSONPropertyMapping)propertyMapping propertyFilter:(FKJSONPropertyFilter)propertyFilter {
    if (object) {
        FKJSON *jsonCoder = [FKJSON new];
        jsonCoder.propertyMapping = propertyMapping;
        jsonCoder.propertyFilter = propertyFilter;
        return [jsonCoder encodeObject:object];
    } else {
        return nil;
    }
}

- (id)encodeObject:(NSObject *)object {
    NSObject *rtObject = [self generalEncodeObject:object];
    if ([rtObject isKindOfClass:NSArray.class] || [rtObject isKindOfClass:NSDictionary.class]) return rtObject;
    return nil;
}

- (NSObject *)generalEncodeObject:(NSObject *)object {
    if (!object) return nil;
    
    if ([object isKindOfClass:NSString.class]) return object;
    if ([object isKindOfClass:NSNumber.class]) return object;
    if ([object isKindOfClass:NSNull.class]) return object;
    
    if ([object isKindOfClass:NSDate.class]) return @([[NSDate date] timeIntervalSince1970]);
    if ([object isKindOfClass:NSURL.class]) return [(NSURL *)object absoluteString];
    if ([object isKindOfClass:NSData.class]) return nil;
    if ([object isKindOfClass:NSValue.class]) return nil;
    
    if ([object isKindOfClass:NSDictionary.class]) {
        if ([NSJSONSerialization isValidJSONObject:object]) return object;
        NSMutableDictionary *mutableDic = [[NSMutableDictionary alloc] initWithCapacity:5];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *stringKey = [key isKindOfClass:NSString.class] ? key : [key description];
            if (!stringKey.length) return ;
            id object = [self generalEncodeObject:obj];
            if (object == nil) object = (id)kCFNull;
            mutableDic[stringKey] = object;
        }];
        return mutableDic;
    }
    
    if ([object isKindOfClass:NSArray.class]) {
        if ([NSJSONSerialization isValidJSONObject:object]) return object;
        NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithCapacity:5];
        for (id obj in (NSArray *)object) {
            id value = [self generalEncodeObject:obj];
            if (value && value != (id)kCFNull) [mutableArray addObject:value];
        }
        
        return mutableArray;
    }
    
    if ([object isKindOfClass:NSSet.class]) {
        NSArray *array = [(NSSet *)object allObjects];
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithCapacity:5];
        for (id obj in array) {
            id value = [self generalEncodeObject:obj];
            if (value && value != (id)kCFNull) [mutableArray addObject:value];
        }
        
        return mutableArray;
    }
    
    //自定义类型
    return [self encodeCustomTypeObject:object];
}

- (NSDictionary *)encodeCustomTypeObject:(id)object {
    if (!object) return nil;
    
    Class clazz = [object class];
    FKJSONConfig *config = [FKJSONConfig new];
    if (self.propertyMapping) {
        config.propertyMapping = self.propertyMapping(clazz);
    }
    if (self.genericTypeMapping) {
        config.containerElementGenericTypeMapping = self.genericTypeMapping(clazz);
    }
    if (self.propertyFilter) {
        FKJSONPropertyFilterType filter = self.propertyFilter(clazz);
        if (filter) {
            config.propertyFilter = [NSSet setWithArray:filter];
        }
    }
    
    //逐层序列化
    FKJSONClassInfo *clazzInfo = fkjson_get_class_info(clazz);
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:5];
    while (clazzInfo && clazzInfo.superClazz != Nil) {//根类（NSObject/NSProxy）不予序列化
        NSDictionary *rt = [self encodeCustomTypeObject:object withJSONClassInfo:clazzInfo configInfo:config];
        if (rt) [dictionary addEntriesFromDictionary:rt];
        clazzInfo = fkjson_get_class_info(clazzInfo.superClazz);
    }
    return dictionary;
}

//序列化某个继承层次上的属性
- (NSDictionary *)encodeCustomTypeObject:(id)object withJSONClassInfo:(FKJSONClassInfo *)clazzInfo configInfo:(FKJSONConfig *)anConfig {
    if (!object || !clazzInfo) return  nil;
    if (![object isKindOfClass:clazzInfo.clazz]) return nil;
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:5];
    //step 0:获取配置信息
    FKJSONConfig *config = fkjson_get_global_config_for_class([object class]);
    if (config && anConfig) {
        config = [config combine:anConfig];
    } else {
        config = anConfig;
    }
    
    // step 1:从classInfo中读取property的信息
    for (FKJSONPropertyInfo *property in clazzInfo.properties) {
        //过滤掉不需要关心的属性
        if ([config.propertyFilter containsObject:property.name]) continue;
        
        // step 2:询问是否需要自定义的序列化规则，特别是在处理一些特殊类型的时候，比如：c struct、c array、以及其他无法解析的类型
        id value = nil;
        if ([object respondsToSelector:@selector(fkjson_valueForKey:)]) {
            value = [(id<FKJSONEntity>)object fkjson_valueForKey:property.name];
        }
        
        if (!value) value = fkjson_safe_kvc_get(object, property.name);
        
        // step 3:自动将value转换为正确的JSONObject Type
        value = [self generalEncodeObject:value];
        
        //设值
        NSString *keyPath = config.propertyMapping[property.name];
        if ([keyPath isKindOfClass:NSArray.class]) {
            NSArray *keyPaths = (NSArray *)keyPath;
            if (keyPath.length) keyPath = keyPaths[0];
            else keyPath = nil;
        }
        if (!keyPath) keyPath = property.name;
        
        fkjson_set_value_for_key_path_in_dictionary([self generalEncodeObject:value], keyPath, dictionary);
    }
    return dictionary;
}

@end
