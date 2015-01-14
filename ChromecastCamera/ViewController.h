//
//  ViewController.h
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MobileCoreServices/UTCoreTypes.h>

#import <GoogleCast/GoogleCast.h>
#import "AppDelegate.h"

#import "WSAssetPicker.h"

#define SharedWebServer ((AppDelegate *)[[UIApplication sharedApplication] delegate]).webServer

// TODO: Remove unneeded delegates
@interface ViewController : UIViewController <GCKDeviceScannerListener,
GCKDeviceManagerDelegate,
GCKMediaControlChannelDelegate,
UIActionSheetDelegate, UINavigationControllerDelegate,UIImagePickerControllerDelegate, UIPopoverControllerDelegate, WSAssetPickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageViewIcon;

- (IBAction)buttonShowLibrary:(id)sender;

- (IBAction)buttonCast:(id)sender;
- (IBAction)buttonBunny:(id)sender;
- (IBAction)buttonWebsite:(id)sender;

- (IBAction)switchSpeed:(id)sender;
- (IBAction)switchRandomize:(id)sender;
- (IBAction)switchRepeat:(id)sender;

@end

