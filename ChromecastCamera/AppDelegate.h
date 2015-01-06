//
//  AppDelegate.h
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) GCDWebServer *webServer;

@end

