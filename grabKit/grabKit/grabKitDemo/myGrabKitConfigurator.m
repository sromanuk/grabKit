/*
 * This file is part of the GrabKit package.
 * Copyright (c) 2012 Pierre-Olivier Simonard <pierre.olivier.simonard@gmail.com>
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
 * associated documentation files (the "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
 * following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in all copies or substantial 
 * portions of the Software.
 *  
 * The Software is provided "as is", without warranty of any kind, express or implied, including but not 
 * limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no
 * event shall the authors or copyright holders be liable for any claim, damages or other liability, whether
 * in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the 
 * use or other dealings in the Software.
 *
 * Except as contained in this notice, the name(s) of (the) Author shall not be used in advertising or otherwise
 * to promote the sale, use or other dealings in this Software without prior written authorization from (the )Author.
 */

#import "myGrabKitConfigurator.h"

@implementation myGrabKitConfigurator


// Connection to services


// Facebook - https://developers.facebook.com/apps

- (NSString*)facebookAppId {
	return @"385201648221818";
}



// Flickr - http://www.flickr.com/services/apps/create/apply/

- (NSString*)flickrApiKey {
    return @"bc85cf92f26ee62793f0b18786a4a7f9";
}

- (NSString*)flickrApiSecret {
    return @"34cec929af30f64e";
}

- (NSString*)flickrRedirectUri{
    return @"uniframeflickr://";
}



// Instragram - http://instagram.com/developer/clients/register/

- (NSString*)instagramAppId {
    return @"936b4b30e58041b1b86541f1586109d8";
}

- (NSString*)instagramRedirectUri {
    return @"grabkitdemoappinstagram://";
}



// Picasa - https://code.google.com/apis/console/

- (NSString*)picasaClientId {
    return @"301419300289.apps.googleusercontent.com";
}

- (NSString*)picasaClientSecret {
    return  @"mChy4Y2YJ1j8El1J96taVPMO";
}



// Others

// The name of the album "Tagged photos" on Facebook, as you want GrabKit to return it.
// Hint : use localization here.
- (NSString*)facebookTaggedPhotosAlbumName {
    
 return @"Tagged photos";   
}

@end
