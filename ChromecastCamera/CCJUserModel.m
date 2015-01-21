//
//  CCJUserModel.m
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/15/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import "CCJUserModel.h"

@implementation CCJUserModel

// default init with '0' for userID
- (id)initWithIdentifier:(int)userID {
    
    self = [super init];
    
    if (self) {
        
        self.userID = userID;
        
        self.userSpeedySwitchOn = NO;
        self.userRandomSwitchOn = NO;
        self.userRepeatSwitchOn = NO;
        self.userLandcapeSwitchOn = NO;
    }
    return self;
}

// initialize with data
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super init];
    
    // save switches
    self.userSpeedySwitchOn = [aDecoder decodeBoolForKey:@"userSpeedySwitchOn"];
    self.userRandomSwitchOn = [aDecoder decodeBoolForKey:@"userRandomSwitchOn"];
    self.userRepeatSwitchOn = [aDecoder decodeBoolForKey:@"userRepeatSwitchOn"];
    self.userLandcapeSwitchOn = [aDecoder decodeBoolForKey:@"userLandcapeSwitchOn"];
    
    return self;
}

// save the data stream
- (void)encodeWithCoder:(NSCoder *)aCoder {
    
    // save switches
    [aCoder encodeBool:self.userSpeedySwitchOn forKey:@"userSpeedySwitchOn"];
    [aCoder encodeBool:self.userRandomSwitchOn forKey:@"userRandomSwitchOn"];
    [aCoder encodeBool:self.userRepeatSwitchOn forKey:@"userRepeatSwitchOn"];
    [aCoder encodeBool:self.userLandcapeSwitchOn forKey:@"userLandcapeSwitchOn"];
    
}

#pragma mark - Persistence Methods

- (BOOL)saveUserPreferences {
    
    NSLog(@"CCJUserModel - saveUserPreferences");
    NSString *path = [self documentDirectoryPath];
    return [NSKeyedArchiver archiveRootObject:self toFile:path];
    
}

- (CCJUserModel *)restoreUserPreferences {
    
    //    NSLog(@"CCJUserModel - restoreUserPreferences");
    NSString *path = [self documentDirectoryPath];
    
    if ([NSKeyedUnarchiver unarchiveObjectWithFile:path]) {
        // looks good
        NSLog(@"***> CCJUserModel NSKeyedUnarchiver unarchiveObjectWithFile:");
        return [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    } else {
        // it appears nothing was previously saved
        NSLog(@"***> CCJUserModel NSKeyedUnarchiver nil");
        return nil;
    }
}


// return the /Documents file path
- (NSString *)documentDirectoryPath {
    
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString *documentDirectory  = [documentDirectories firstObject];
    return [documentDirectory stringByAppendingPathComponent:@"user.archive"];
}


@end
