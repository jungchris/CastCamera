//
//  ViewController.h
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GoogleCast/GoogleCast.h>

@interface ViewController : UIViewController <GCKDeviceScannerListener,
GCKDeviceManagerDelegate,
GCKMediaControlChannelDelegate,
UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet UILabel *labelCast;
- (IBAction)buttonCast:(id)sender;

@end

