//
//  GKCachingObject.h
//  grabKit
//
//  Created by Slavik Romanuk on 10/2/12.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * NSCache has no ability to store it to disk, and I don't think it's a good idea to store photo path in the SQLite
 * because we will change a lot of objects on the runtime but SQL quiries could be slow in this case.
 *
 * In memory objects are better for this particular situation. [IMHO]
 */


enum GK_IMAGE_SERVICE {
    GK_SERVICE_FACEBOOK = 0,
    GK_SERVICE_FLICKR,
    GK_SERVICE_INSTAGRAM,
    GK_SERVICE_PICASA,
    GK_SERVICE_GALLERY,
    GK_SERVICE_500PX,
    
    GK_ENUM_MAX_VALUE // Always should be the last Enum value.
};

typedef enum GK_IMAGE_SERVICE GK_IMAGE_SERVICE_TYPE;


@interface GKCachingObject : NSObject {
    NSMutableDictionary * _cacheingObject;
    NSOperationQueue * _downloadsOperationQueue;
}


+ (GKCachingObject *) instance;

- (BOOL) addFileFromURL: (NSURL *) url;
- (UIImage *) getCachedImage;
- (NSArray *) getArrayOfCachedImages: (NSUInteger) count;

- (void) addGrabbingService: (GK_IMAGE_SERVICE_TYPE) serviceName;
- (void) removeGrabbingService: (GK_IMAGE_SERVICE_TYPE) serviceName;
- (BOOL) hasCachedImages;

@end
