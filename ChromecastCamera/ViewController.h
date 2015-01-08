//
//  ViewController.h
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <MobileCoreServices/UTCoreTypes.h>


#import <GoogleCast/GoogleCast.h>
#import "AppDelegate.h"

#define SharedWebServer ((AppDelegate *)[[UIApplication sharedApplication] delegate]).webServer

@interface ViewController : UIViewController <GCKDeviceScannerListener,
GCKDeviceManagerDelegate,
GCKMediaControlChannelDelegate,
UIActionSheetDelegate, UINavigationControllerDelegate,UIImagePickerControllerDelegate, UIPopoverControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageViewIcon;

@property (weak, nonatomic) IBOutlet UILabel *labelCast;
@property (weak, nonatomic) IBOutlet UILabel *labelURL;

- (IBAction)buttonCast:(id)sender;
- (IBAction)buttonBunny:(id)sender;
- (IBAction)buttonWebsite:(id)sender;

@end

