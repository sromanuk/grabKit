//
//  GKCachingObject.m
//  grabKit
//
//  Created by Slavik Romanuk on 10/2/12.
//
//

#import "GKCachingObject.h"

#import "PXAPI.h"
#import "GrabKit.h"
#import "GRKServiceGrabber.h"
#import "GRKAlbum.h"
#import "GRKImage.h"
#import "GRKPhoto.h"
#import "SBJsonParser.h"


@interface GKCachingObject (Private)

- (id) __init__;
- (NSMutableDictionary *) __createCachedObjectStructure__;
- (void) __timerJob__: (NSTimer *) timer;
- (void) __implementGrabberBlocks__;
- (void) __loadPopularPhotoForServiceGrabber__: (GRKServiceGrabber *) _grabber;
- (void) __load500pxPhotos__;

@end


@implementation GKCachingObject

typedef void (^GrabberServiceBlock)();


static GKCachingObject * _instance = nil;
static NSTimer * _downloadTimer = nil;
static GrabberServiceBlock _initializedServicesCache[GK_ENUM_MAX_VALUE]; // store not objects but blocks here. and invoke 'em.
static NSMutableDictionary * _grabberObjects = nil;

static NSString * GK_PATH_TO_STORAGE = nil;
static NSString * GK_PATH_TO_STORAGE_FILE = nil;

static const NSInteger GK_CACHE_EMPTY = -1;
static NSInteger _nextCacheIndex = GK_CACHE_EMPTY;


// cached object's structure constants
static const NSString * GK_TOTAL_OBJECTS_SIZE_KEY = @"total object's size";
static const NSString * GK_MAXIMUM_OBJECTS_SIZE_KEY = @"maximum object's size";
static const NSString * GK_CACHED_OBJECTS_KEY = @"cached objects";
static const NSInteger  GK_MAXIMUM_OBJECTS_SIZE_VALUE = 150 * 1024 * 1024; // 150Mb for cache size should be enough. For now.

static const NSUInteger kNumberOfElementsPerPage = 5;


static NSObject * _lockMutex = nil;

static const NSTimeInterval GL_TIMER_INTERVAL = 10.0;

void (^GrabberServiceBlock_Instagram) ();
void (^GrabberServiceBlock_Facebook) ();
void (^GrabberServiceBlock_Gallery) ();
void (^GrabberServiceBlock_Flickr) ();
void (^GrabberServiceBlock_Picasa) ();
void (^GrabberServiceBlock_500PX) ();



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
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:GK_PATH_TO_STORAGE]) {
                
                [[NSFileManager defaultManager] createDirectoryAtPath:GK_PATH_TO_STORAGE
                                          withIntermediateDirectories:NO
                                                           attributes:nil
                                                                error:nil];
            }
            
        } else {
            NSInteger currentCacheSize = [[_cacheingObject objectForKey:GK_TOTAL_OBJECTS_SIZE_KEY] integerValue];
            if (currentCacheSize > 0) {
                _nextCacheIndex = 0;
            }
        }
        
        _downloadTimer = [NSTimer timerWithTimeInterval:GL_TIMER_INTERVAL
                                                 target:self
                                               selector:@selector(__timerJob__:)
                                               userInfo:nil
                                                repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_downloadTimer forMode:NSDefaultRunLoopMode];
        
        _lockMutex = [[NSObject alloc] init];
        _grabberObjects = [[NSMutableDictionary alloc] initWithCapacity:5];
        
        [self __implementGrabberBlocks__];
        
        _downloadsOperationQueue = [[NSOperationQueue alloc] init];
    }
    
    return self;
}

- (void) __implementGrabberBlocks__ {
    
    GrabberServiceBlock_Instagram = ^{
        [self __loadPopularPhotoForServiceName__:@"GRKInstagramGrabber"];
    };
    
    GrabberServiceBlock_Facebook = ^{
        [self __loadPopularPhotoForServiceName__:@"GRKFacebookGrabber"];
    };
    
    GrabberServiceBlock_Gallery = ^{
        [self __loadPopularPhotoForServiceName__:@"GRKDeviceGrabber"];
    };
    
    GrabberServiceBlock_Flickr = ^{
        [self __loadPopularPhotoForServiceName__:@"GRKFlickrGrabber"];
    };
    
    GrabberServiceBlock_Picasa = ^{
        [self __loadPopularPhotoForServiceName__:@"GRKPicasaGrabber"];
    };
    
    GrabberServiceBlock_500PX = ^{
        [self __load500pxPhotos__];
    };
}

- (void) __load500pxPhotos__ {
    static NSInteger pageNumber = 1;
    
    PXAPIHelper * pxapi = [[PXAPIHelper alloc] init];
    
    NSURLRequest * request = [pxapi urlRequestForPhotoFeature:PXAPIHelperPhotoFeaturePopular
                                               resultsPerPage:kNumberOfElementsPerPage
                                                         page:pageNumber];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:_downloadsOperationQueue
                           completionHandler:^(NSURLResponse * response, NSData * data, NSError * error) {
                               NSLog(@"error is %@", error);
                               
                               NSString * responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; // JSON object
                               
                               SBJsonParser * parser = [[SBJsonParser alloc] init];
                               NSObject * jsonObject = [parser objectWithString:responseData];
                               if ([jsonObject isKindOfClass:[NSDictionary class]]) {
                                   
                                   NSArray * photosArray = (NSArray *) [(NSDictionary *) jsonObject objectForKey:@"photos"];
                                   
                                   for (NSDictionary * photo in photosArray) {
                                       NSString  * urlString = (NSString *) [[photo objectForKey:@"image_url"] lastObject];
                                       if (urlString != nil && ![urlString isEqualToString:@""]) {
                                           NSURL * url = [[NSURL alloc] initWithString:urlString];
                                           
                                           [self addFileFromURL:url];
                                       }
                                   }
                                   
                               } else {
                                   NSLog(@"Can't recognize object's type %@", jsonObject);
                               }
                           }];
    
    pageNumber++;
}

- (void) __loadPopularPhotoForServiceName__: (NSString *) serviceName {
    if (serviceName == nil || [serviceName isEqualToString:@""]) {
        NSLog(@"service name is empty");
        return ;
    }
    
    static NSInteger _lastLoadedPageIndex = 1;
    static NSUInteger _lastLoadedPhotosPageIndex = 1;
    
    NSObject<GRKServiceGrabberProtocol> * _grabber = [_grabberObjects objectForKey:serviceName];
    
    if (_grabber == nil) {
        Class grabberClass = NSClassFromString(serviceName);
        
        @try {
            _grabber = [[grabberClass alloc] init];
            [_grabberObjects setObject:_grabber
                                forKey:serviceName];
        } @catch (NSException *exception) {
            NSLog(@" exception : %@", exception);
            return ;
        }
    }
    
    if (_grabber == nil) {
        NSLog(@"Can't create grabber service's object for %@", serviceName);
        return;
    }
    
    NSLog(@"grabber service object created for service name %@", serviceName);
    
    [_grabber albumsOfCurrentUserAtPageIndex:_lastLoadedPageIndex
                   withNumberOfAlbumsPerPage:kNumberOfElementsPerPage
                            andCompleteBlock:^(NSArray *results) {
                                
                                _lastLoadedPageIndex ++;
                                
                                GRKAlbum * popularPhotoAlbum = nil;
                                for( GRKAlbum * newAlbum in results ) {
                                    NSRange range = [[[newAlbum name] lowercaseString] rangeOfString:@"popular"];
                                    if (range.location != NSNotFound) {
                                        popularPhotoAlbum = newAlbum;
                                        break ;
                                    }
                                }
                                
                                NSLog(@"album selected and it is %@", popularPhotoAlbum);
                                
                                [_grabber fillAlbum:popularPhotoAlbum
                              withPhotosAtPageIndex:_lastLoadedPhotosPageIndex
                          withNumberOfPhotosPerPage:kNumberOfElementsPerPage
                                   andCompleteBlock:^(NSArray *results) {
                                       
                                       NSLog(@"album filled");
                                       
                                       _lastLoadedPhotosPageIndex ++;
                                       
                                       NSArray * photos = [popularPhotoAlbum photos];
                                       for (GRKPhoto * photo in photos) {
                                           NSArray * images = [photo images];
                                           
                                           for (GRKImage * image in images) {
                                               NSURL * imageUrl = [image URL];
                                               
                                               [self performSelectorInBackground:@selector(addFileFromURL:) withObject:imageUrl];
                                           }
                                       }
                                       
                                   } andErrorBlock:^(NSError *error) {
                                       NSLog(@" error for page %d : %@", _lastLoadedPhotosPageIndex,  error);
                                   }];
                                
                            } andErrorBlock:^(NSError *error) {
                                
                                NSLog(@" error ! %@", error);
                                
                            }];
}

- (void) __timerJob__: (NSTimer *) timer {
    @synchronized (_lockMutex) {
        for (int i = 0; i < GK_ENUM_MAX_VALUE; i++) {
            if (_initializedServicesCache[i] != 0) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                         (unsigned long)NULL), _initializedServicesCache[i]);
            }
        }
    }
}

- (void) addGrabbingService: (GK_IMAGE_SERVICE_TYPE) serviceName {
    if (serviceName > GK_ENUM_MAX_VALUE) {
        return ;
    }
    
    @synchronized (_lockMutex) {
        if (_initializedServicesCache[serviceName] != 0) {
            return ;
        }
        
        switch (serviceName) {
            case GK_SERVICE_500PX: {
                _initializedServicesCache[serviceName] = GrabberServiceBlock_500PX;
                break ;
            }
            
            case GK_SERVICE_FACEBOOK: {
                _initializedServicesCache[serviceName] = GrabberServiceBlock_Facebook;
                break ;
            }
                
            case GK_SERVICE_FLICKR: {
                _initializedServicesCache[serviceName] = GrabberServiceBlock_Flickr;
                break ;
            }
                
            case GK_SERVICE_GALLERY: {
                _initializedServicesCache[serviceName] = GrabberServiceBlock_Gallery;
                break ;
            }
                
            case GK_SERVICE_INSTAGRAM: {
                _initializedServicesCache[serviceName] = GrabberServiceBlock_Instagram;
                break ;
            }
                
            case GK_SERVICE_PICASA: {
                _initializedServicesCache[serviceName] = GrabberServiceBlock_Picasa;
                break ;
            }
                
            default:
                break ;
        }
    }
    
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
//                                             (unsigned long)NULL), ^{
//        for (int i = 100; i > 0; i--) {
//            sleep(10);
//            UIImage * img = [[GKCachingObject instance] getCachedImage];
//            if (img) {
//                NSLog(@"image from cache received");
//            } else {
//                NSLog(@"image from cache was not received");
//            }
//        }
//    });
}

- (void) removeGrabbingService: (GK_IMAGE_SERVICE_TYPE) serviceName {
    @synchronized (_lockMutex) {
        if (serviceName < GK_ENUM_MAX_VALUE) {
            _initializedServicesCache[serviceName] = 0;
        }
    }
}

- (NSMutableDictionary *) __createCachedObjectStructure__ {
    NSMutableDictionary * cached_object_template = [[NSMutableDictionary alloc] initWithCapacity:5];
    
    [cached_object_template setObject:[NSNumber numberWithInteger:0]
                               forKey:GK_TOTAL_OBJECTS_SIZE_KEY];
    
    [cached_object_template setObject:[[NSMutableArray alloc] initWithCapacity:10]
                               forKey:GK_CACHED_OBJECTS_KEY];
    
    return cached_object_template;
}

- (BOOL) addFileFromURL: (NSURL *) url {
    if (url == nil) {
        NSLog(@"Adding image from URL and URL is nil");
        return NO;
    }
    NSLog(@"Adding image from URL and URL is %@", [url absoluteString]);
    
    @synchronized(self) {
        NSInteger currentCacheSize = [[_cacheingObject objectForKey:GK_TOTAL_OBJECTS_SIZE_KEY] integerValue];
        if (currentCacheSize >= GK_MAXIMUM_OBJECTS_SIZE_VALUE) {
            NSLog(@"cache is full");
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
            
            if (receivedImage == nil) NSLog(@"received image was nil!");
            
            @synchronized(self) {
                NSInteger currentCacheSize = [[_cacheingObject objectForKey:GK_TOTAL_OBJECTS_SIZE_KEY] integerValue];
                NSLog(@"currentCacheSize = %d, data length = %d, GK_MAXIMUM_OBJECTS_SIZE_VALUE = %d", currentCacheSize, [data length], GK_MAXIMUM_OBJECTS_SIZE_VALUE);
                
                if (currentCacheSize + [data length] > GK_MAXIMUM_OBJECTS_SIZE_VALUE && _nextCacheIndex != GK_CACHE_EMPTY) {
                    
                    NSString * path = [[_cacheingObject objectForKey:GK_CACHED_OBJECTS_KEY] objectAtIndex:0];
                    
                    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
                    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
                    long long fileSize = [fileSizeNumber longLongValue];
                    if (currentCacheSize > fileSize) currentCacheSize -= fileSize;
                    [_cacheingObject setObject:[NSNumber numberWithInteger:currentCacheSize] forKey:GK_TOTAL_OBJECTS_SIZE_KEY];
                    
                    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
                    NSLog (@"removed file at path %@", path);
                    
                    [[_cacheingObject objectForKey:GK_CACHED_OBJECTS_KEY] removeObjectAtIndex:0];
                    
                    _nextCacheIndex--;
                }
                
                if (currentCacheSize + [data length] < GK_MAXIMUM_OBJECTS_SIZE_VALUE) {
                    NSLog(@"cleaning was probably done. currentCacheSize = %d, data length = %d, GK_MAXIMUM_OBJECTS_SIZE_VALUE = %d",
                          currentCacheSize, [data length], GK_MAXIMUM_OBJECTS_SIZE_VALUE);
                    
                    [[_cacheingObject objectForKey:GK_CACHED_OBJECTS_KEY] addObject:pngPath];
                    [_cacheingObject setObject:[NSNumber numberWithInteger:currentCacheSize + [data length]]
                                        forKey:GK_TOTAL_OBJECTS_SIZE_KEY];
                    
                    [_cacheingObject writeToFile:GK_PATH_TO_STORAGE_FILE atomically:NO];
                    
                    if (_nextCacheIndex == GK_CACHE_EMPTY) _nextCacheIndex = 0;
                }
                // if cache is full we should set timer interval to the greater value.
                // it does not seems like possible, so we should re-create the timer.
                // in this case it would be probably a better solution to create another
                // timer that will start this one.
                // thois solution will be a better one because when we lost an internet
                // connection we also should create another timer and only after the
                // much greater interval try to start download timer again.
                //
                // that is why let's make it so.
                
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
            NSLog(@"path to cached image is %@, image is %@", path, image);
            
            _nextCacheIndex++;
        } else {
            NSLog(@"problem during receiving image from cache, nextCacheIndex is %d and objects", _nextCacheIndex);
        }
        
        NSLog(@"cache count %d", [cache count]);
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
