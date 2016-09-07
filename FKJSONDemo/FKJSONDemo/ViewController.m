//
//  ViewController.m
//  FKJSONDemo
//
//  Created by y_liang on 16/9/3.
//  Copyright © 2016年 y_liang. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+FKJSON.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self benchmarkGithubUser];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)benchmarkGithubUser {
    
    /// Benchmark swift .. too slow...
    /// [GithubUserBenchmark benchmark];
    
    
    printf("----------------------\n");
    printf("Benchmark (10000 times):\n");
    printf("GHUser          from json    to json    archive\n");
    
    /// get json data
    NSString *path = [[NSBundle mainBundle] pathForResource:@"user" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    
    /// Benchmark
    int count = 100000;
    NSTimeInterval begin, end;
    
    /// warm up (NSDictionary's hot cache, and JSON to model framework cache)
    
    @autoreleasepool {
        for (int i = 0; i < 1; i++) {
    
            
            //FKJSON
            [FKGHUser fkjson_entityFromJSON:json];
        }
    }
    /// warm up holder
    NSMutableArray *holder = [NSMutableArray new];
    for (int i = 0; i < 1; i++) {
        [holder addObject:[NSDate new]];
    }
    [holder removeAllObjects];
    
    
//    /*------------------- YYModel -------------------*/
//    {
//        [holder removeAllObjects];
//        begin = CACurrentMediaTime();
//        @autoreleasepool {
//            for (int i = 0; i < count; i++) {
//                YYGHUser *user = [YYGHUser yy_modelWithJSON:json];
//                [holder addObject:user];
//            }
//        }
//        end = CACurrentMediaTime();
//        printf("YYModel:         %8.2f   ", (end - begin) * 1000);
//        
//        
//        YYGHUser *user = [YYGHUser yy_modelWithJSON:json];
//        if (user.userID == 0) NSLog(@"error!");
//        if (!user.login) NSLog(@"error!");
//        if (!user.htmlURL) NSLog(@"error");
//        
//        [holder removeAllObjects];
//        begin = CACurrentMediaTime();
//        @autoreleasepool {
//            for (int i = 0; i < count; i++) {
//                NSDictionary *json = [user yy_modelToJSONObject];
//                [holder addObject:json];
//            }
//        }
//        end = CACurrentMediaTime();
//        if ([NSJSONSerialization isValidJSONObject:[user yy_modelToJSONObject]]) {
//            printf("%8.2f   ", (end - begin) * 1000);
//        } else {
//            printf("   error   ");
//        }
//        
//        
//        [holder removeAllObjects];
//        begin = CACurrentMediaTime();
//        @autoreleasepool {
//            for (int i = 0; i < count; i++) {
//                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:user];
//                [holder addObject:data];
//            }
//        }
//        end = CACurrentMediaTime();
//        printf("%8.2f\n", (end - begin) * 1000);
//    }
    
    
    /*------------------- FKModel -------------------*/
    {
        [holder removeAllObjects];
        begin = CACurrentMediaTime();
        @autoreleasepool {
            for (int i = 0; i < count; i++) {
                FKGHUser *user = [FKGHUser fkjson_entityFromJSON:json];
                [holder addObject:user];
            }
        }
        end = CACurrentMediaTime();
        printf("FKModel:         %8.2f   ", (end - begin) * 1000);
        
        
        FKGHUser *user = [FKGHUser fkjson_entityFromJSON:json];
        //        if (user.userID == 0) NSLog(@"error!");
        //        if (!user.login) NSLog(@"error!");
        //        if (!user.htmlURL) NSLog(@"error");
        
        printf("     N/A");
        
        
        printf("     N/A\n");
    }
}

@end

@implementation FKGHUser
+ (FKJSONPropertyMappingType)fkjson_propertyMapping {
    return @{
             @"userID" : @"id",
             @"avatarURL" : @"avatar_url",
             @"gravatarID" : @"gravatar_id",
             @"htmlURL" : @"html_url",
             @"followersURL" : @"followers_url",
             @"followingURL" : @"following_url",
             @"gistsURL" : @"gists_url",
             @"starredURL" : @"starred_url",
             @"subscriptionsURL" : @"subscriptions_url",
             @"organizationsURL" : @"organizations_url",
             @"reposURL" : @"repos_url",
             @"eventsURL" : @"events_url",
             @"receivedEventsURL" : @"received_events_url",
             @"siteAdmin" : @"site_admin",
             @"publicRepos" : @"public_repos",
             @"publicGists" : @"public_gists",
             @"createdAt" : @"created_at",
             @"updatedAt" : @"updated_at",
             };
}

@end
