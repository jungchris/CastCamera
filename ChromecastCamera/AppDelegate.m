//
//  AppDelegate.m
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

@synthesize webServer;
@synthesize userModel;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // setup basic web server
    webServer = [[GCDWebServer alloc] init];
    
    // initialize the app user representation.  This app is single user
    userModel = [[CCJUserModel alloc] initWithIdentifier:0];
    
    // this code needs to ensure userModel is not overwritten to nil when no archive file exists
//    if ([userModel restoreUserPreferences]) {
//        NSLog(@"> Restoring user model from user.archive");
//        userModel = [userModel restoreUserPreferences];
//    } else {
//        NSLog(@"> Nothing to restore from items.archive");
//    }
    
    // set the nav bar and nav item colors
    [self customizeUserInterface];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.

}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    // save the user (preferences) model
//    BOOL success = [userModel saveUserPreferences];
//    if (!success) {
//        NSLog(@"(CCJAppDelegate) Error: Unable to save user preferences");
//    }
    
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

// customize appearance
- (void)customizeUserInterface {
    
    // set nav bar backgound
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:0.77 green:0.69 blue:0.99 alpha:1.0]];     // 0.95,0.52,0.01
    
    // set nav bar title color
    [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor], NSForegroundColorAttributeName, nil]];
    
    // set nav bar other text labels and buttons color
    [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:0.25f green:0.45f blue:0.90f alpha:1]];
    
}

@end
