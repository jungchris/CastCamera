//
//  CCJImageEngine.h
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/15/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface CCJImageEngine : NSObject

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)size;

+ (UIImage *)imageWithImage:(UIImage *)image scaledToMaxWidth:(CGFloat)width maxHeight:(CGFloat)height;

+ (UIImage*)imageWithImage:(UIImage*)sourceImage scaledToWidth:(float)i_width;

+ (UIImage *)scaleImage:(UIImage *)sourceImage toSize:(CGSize)newSize;

@end
