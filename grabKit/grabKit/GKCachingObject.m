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

static const NSInteger GK_CACHE_EMPTY = -1;
static NSInteger _nextCacheIndex = GK_CACHE_EMPTY;

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

- (id) __init__ {
    if (self = [super init]) {
        _cacheingObject = [[NSMutableDictionary alloc] initWithContentsOfFile:GK_PATH_TO_STORAGE_FILE];
        if (!_cacheingObject) {
            NSLog(@"storage file could not be loaded (%@)", GK_PATH_TO_STORAGE_FILE);
            
            _cacheingObject = [self __createCachedObjectStructure__];
        }
        
        _downloadsOperationQueue = [[NSOperationQueue alloc] init];
    }
    
    return self;
}

- (NSMutableDictionary *) __createCachedObjectStructure__ {
    NSMutableDictionary * cached_object_template = [[NSMutableDictionary alloc] initWithCapacity:25];
    
    [cached_object_template setObject:[NSNumber numberWithInteger:0]
                               forKey:GK_TOTAL_OBJECTS_SIZE_KEY];
    
    [cached_object_template setObject:[NSMutableArray arrayWithCapacity:10]
                               forKey:GK_CACHED_OBJECTS_KEY];
    
    return cached_object_template;
}

- (BOOL) addFileFromURL: (NSURL *) url {
    if (url == nil) {
        return NO;
    }
    
    @synchronized(self) {
        NSInteger currentCacheSize = [[_cacheingObject objectForKey:GK_TOTAL_OBJECTS_SIZE_KEY] integerValue];
        if (currentCacheSize >= GK_MAXIMUM_OBJECTS_SIZE_VALUE) {
            return NO;
        }
    }
    
    NSURLRequest * theRequest = [NSURLRequest requestWithURL:url
                                                 cachePolicy:NSURLRequestUseProtocolCachePolicy
                                             timeoutInterval:60.0];
    
    [NSURLConnection sendAsynchronousRequest:theRequest
                                       queue:_downloadsOperationQueue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               
        if ([data length] > 0 && error == nil) {
            NSString * filename = [NSString stringWithFormat:@"%f.png", [[NSDate date] timeIntervalSince1970]];
            NSString * pngPath = [GK_PATH_TO_STORAGE stringByAppendingPathComponent:filename];
            
            UIImage * receivedImage = [UIImage imageWithData:data];
            [UIImagePNGRepresentation(receivedImage) writeToFile:pngPath atomically:NO];
            
            @synchronized(self) {
                NSInteger currentCacheSize = [[_cacheingObject objectForKey:GK_TOTAL_OBJECTS_SIZE_KEY] integerValue];
                if (currentCacheSize + [data length] > GK_MAXIMUM_OBJECTS_SIZE_VALUE && _nextCacheIndex != GK_CACHE_EMPTY) {
                    
                    NSString * path = [[_cacheingObject objectForKey:GK_CACHED_OBJECTS_KEY] objectAtIndex:0];
                    
                    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
                    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
                    long long fileSize = [fileSizeNumber longLongValue];
                    if (currentCacheSize > fileSize) currentCacheSize -= fileSize;
                    [_cacheingObject setObject:[NSNumber numberWithInteger:currentCacheSize] forKey:GK_TOTAL_OBJECTS_SIZE_KEY];
                    
                    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
                    
                    [[_cacheingObject objectForKey:GK_CACHED_OBJECTS_KEY] removeObjectAtIndex:0];
                    
                    _nextCacheIndex--;
                }
                
                if (currentCacheSize + [data length] < GK_MAXIMUM_OBJECTS_SIZE_VALUE) {
                    [[_cacheingObject objectForKey:GK_CACHED_OBJECTS_KEY] addObject:pngPath];
                    [_cacheingObject setObject:[NSNumber numberWithInteger:currentCacheSize + [data length]]
                                        forKey:GK_TOTAL_OBJECTS_SIZE_KEY];
                    
                    if (_nextCacheIndex == GK_CACHE_EMPTY) _nextCacheIndex = 0;
                }
            }
        }
    }];
    
    return YES;
}

- (UIImage *) getCachedImage {
    
    UIImage * image = nil;
    
    @synchronized(self) {
        NSArray * cache = [_cacheingObject objectForKey:GK_CACHED_OBJECTS_KEY];
        
        if ([cache count] > _nextCacheIndex && [cache count] > 0) {
            NSString * path = [cache objectAtIndex:_nextCacheIndex];
            image = [[UIImage alloc] initWithContentsOfFile:path];
            
            _nextCacheIndex++;
        }
    }
    
    return image;
}

- (NSArray *) getArrayOfCachedImages: (NSUInteger) count {
    if (count == 0) count = 1;
    
    NSMutableArray * resultArray = [[NSMutableArray alloc] initWithCapacity:count];
    
    for (int i = 0; i < count; i++) {
        UIImage * gettedCachedImage = [self getCachedImage];
        if (gettedCachedImage != nil) {
            [resultArray addObject:gettedCachedImage];
        }
    }
    
    return [resultArray count] > 0 ? resultArray : nil;
}

@end
