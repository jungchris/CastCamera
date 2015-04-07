//
//  InterfaceController.h
//  ChromecastCamera WatchKit Extension
//
//  Created by Chris Jungmann on 4/1/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface InterfaceController : WKInterfaceController

// this image may simply show connection status
@property (weak, nonatomic) IBOutlet WKInterfaceImage *imageTopWatch;

// button actions
// I'd like to also implement a double-tap or long-touch detection
- (IBAction)buttonLeftTouch;
- (IBAction)buttonRightTouch;

// button properties (since they change dynamically)
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonLeft;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonRight;


@end
