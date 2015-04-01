//
//  CCJUserModel.h
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/15/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCJUserModel : NSObject <NSCoding>

@property (nonatomic) int userID;

@property BOOL userSpeedySwitchOn;
@property BOOL userRandomSwitchOn;
@property BOOL userRepeatSwitchOn;
@property BOOL userLandcapeSwitchOn;

// initializer
- (id)initWithIdentifier:(int)userID;

- (BOOL)saveUserPreferences;
- (CCJUserModel *)restoreUserPreferences;

@end
