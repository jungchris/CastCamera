//
//  InterfaceController.m
//  ChromecastCamera WatchKit Extension
//
//  Created by Chris Jungmann on 4/1/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import "InterfaceController.h"
#import "ViewController.h"

@interface InterfaceController()

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    // Configure interface objects here.
    
    // refactor setting up the images & buttons:
    // top image
    [self.imageTopWatch setImage:[UIImage imageNamed:@"watch-play"]];
    
    // left button
    [self.buttonLeft setTitle:@""];
    [self.buttonLeft setBackgroundImageNamed:@"watch-play"];

    // right button
    [self.buttonRight setTitle:@""];
    [self.buttonRight setBackgroundImageNamed:@"watch-next"];
    
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    
    NSLog(@"Watch willActivate");
    
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
    
    NSLog(@"Watch didDeactivate");

}

- (IBAction)buttonLeftTouch {
    
    NSLog(@"Watch left button touched");
    [self.buttonLeft setTitle:@"Play"];

    NSDictionary *appData = [[NSDictionary alloc] initWithObjects:@[@"left"] forKeys:@[@"buttonTouched"]];
    [self sendActionToParentApplication:appData];
    
}

- (IBAction)buttonRightTouch {
    
    NSLog(@"Watch right button touched");

    NSDictionary *appData = [[NSDictionary alloc] initWithObjects:@[@"right"] forKeys:@[@"buttonTouched"]];
    [self sendActionToParentApplication:appData];
    
}

// communicate with parent app
- (void)sendActionToParentApplication:(NSDictionary *)appData {
    
    // call receiver in parent AppDelegate
    [WKInterfaceController openParentApplication:appData reply:^(NSDictionary *replyInfo, NSError *error) {
        
        NSLog(@"%@ %@",replyInfo, error);
    }];
    
}


@end



