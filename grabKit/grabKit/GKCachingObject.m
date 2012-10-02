//
//  GKCachingObject.m
//  grabKit
//
//  Created by Slavik Romanuk on 10/2/12.
//
//

#import "GKCachingObject.h"

@interface GKCachingObject (Private)

- (id) __init__;
- (NSMutableDictionary *) __createCachedObjectStructure__;

@end


@implementation GKCachingObject

static GKCachingObject * _instance = nil;

static NSString * GK_PATH_TO_STORAGE = nil;
static NSString * GK_PATH_TO_STORAGE_FILE = nil;

// cached object's structure constants
static const NSString * GK_TOTAL_OBJECTS_SIZE_KEY = @"total object's size";
static const NSString * GK_MAXIMUM_OBJECTS_SIZE_KEY = @"maximum object's size";
static const NSString * GK_CACHED_OBJECTS_KEY = @"cached objects";
static const NSInteger  GK_MAXIMUM_OBJECTS_SIZE_VALUE = 150 * 1024 * 1024; // 150Mb for cache size should be enough. For now.

+ (GKCachingObject *) instance {
    
    @synchronized(self)
    {
        if (_instance == nil)
        {
            GK_PATH_TO_STORAGE = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                                  stringByAppendingPathComponent:@"cache"];
            GK_PATH_TO_STORAGE_FILE = [GK_PATH_TO_STORAGE stringByAppendingPathComponent:@"cached_files.plist"];
            
            _instance = [[GKCachingObject alloc] __init__];
        }
    }
    
    return _instance;
}

- (id) init {
    if (self = [super init]) {
        _cacheingObject = [[NSMutableDictionary alloc] initWithContentsOfFile:GK_PATH_TO_STORAGE_FILE];
        if (!_cacheingObject) {
            NSLog(@"storage file could not be loaded (%@)", GK_PATH_TO_STORAGE_FILE);
            
            _cacheingObject = [self __createCachedObjectStructure__];
        }
    }
    
    return self;
}

- (NSMutableDictionary *) __createCachedObjectStructure__ {
    NSMutableDictionary * cached_object_template = [[NSMutableDictionary alloc] initWithCapacity:25];
    
    [cached_object_template setObject:[NSNumber numberWithInteger:0]
                               forKey:GK_TOTAL_SIZE_KEY];
    
    [cached_object_template setObject:[NSMutableArray arrayWithCapacity:10]
                               forKey:GK_CACHED_OBJECTS_KEY];
    
    return cached_object_template;
}


@end
