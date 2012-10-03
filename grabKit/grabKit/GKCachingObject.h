//
//  GKCachingObject.h
//  grabKit
//
//  Created by Slavik Romanuk on 10/2/12.
//
//

#import <Foundation/Foundation.h>

/**
 * NSCache has no ability to store it to disk, and I don't think it's a good idea to store photo path in the SQLite
 * because we will change a lot of objects on the runtime but SQL quiries could be slow in this case.
 *
 * In memory objects are better for this particular situation. [IMHO]
 */

@interface GKCachingObject : NSObject {
    NSMutableDictionary * _cacheingObject;
    NSOperationQueue * _downloadsOperationQueue;
}

+ (GKCachingObject *) instance;

@end
