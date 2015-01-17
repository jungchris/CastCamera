//
//  CCJImageEngine.m
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/15/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import "CCJImageEngine.h"

@implementation CCJImageEngine



// Resize but keep the aspect ratio: http://stackoverflow.com/questions/7645454/resize-uiimage-by-keeping-aspect-ratio-and-width
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)size {
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(size, NO, [[UIScreen mainScreen] scale]);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToMaxWidth:(CGFloat)width maxHeight:(CGFloat)height {
    CGFloat oldWidth = image.size.width;
    CGFloat oldHeight = image.size.height;
    
    CGFloat scaleFactor = (oldWidth > oldHeight) ? width / oldWidth : height / oldHeight;
    
    CGFloat newHeight = oldHeight * scaleFactor;
    CGFloat newWidth = oldWidth * scaleFactor;
    CGSize newSize = CGSizeMake(newWidth, newHeight);
    
    return [self imageWithImage:image scaledToSize:newSize];
}

// this allows me to scale to a width, without caring about height
+ (UIImage*)imageWithImage:(UIImage*)sourceImage scaledToWidth:(float)i_width
{
    float oldWidth = sourceImage.size.width;
    float scaleFactor = i_width / oldWidth;
    
    float newHeight = sourceImage.size.height * scaleFactor;
    float newWidth = oldWidth * scaleFactor;
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [sourceImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

// Works!
// process from https://gist.github.com/tomasbasham/10533743
+ (UIImage *)scaleImage:(UIImage *)sourceImage toSize:(CGSize)newSize {
    
    CGRect scaledImageRect = CGRectZero;
    
    CGFloat aspectWidth = newSize.width / sourceImage.size.width;
    CGFloat aspectHeight = newSize.height / sourceImage.size.height;
    CGFloat aspectRatio = MAX ( aspectWidth, aspectHeight );
    
    scaledImageRect.size.width = sourceImage.size.width * aspectRatio;
    scaledImageRect.size.height = sourceImage.size.height * aspectRatio;
    scaledImageRect.origin.x = (newSize.width - scaledImageRect.size.width) / 2.0f;
    scaledImageRect.origin.y = (newSize.height - scaledImageRect.size.height) / 2.0f;
    
    UIGraphicsBeginImageContextWithOptions( newSize, NO, 0 );
    [sourceImage drawInRect:scaledImageRect];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
    
}


@end
