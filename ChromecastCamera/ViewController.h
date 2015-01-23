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
#import <Social/Social.h>
#import <iAd/iAd.h>

#import "AppDelegate.h"
#import "WSAssetPicker.h"

#define SharedWebServer ((AppDelegate *)[[UIApplication sharedApplication] delegate]).webServer

#define SharedUserModel ((AppDelegate *)[[UIApplication sharedApplication] delegate]).userModel

// TODO: Remove unneeded delegates
@interface ViewController : UIViewController <GCKDeviceScannerListener,
GCKDeviceManagerDelegate,
GCKMediaControlChannelDelegate,
UIActionSheetDelegate, UINavigationControllerDelegate,UIImagePickerControllerDelegate, UIPopoverControllerDelegate,
    ADBannerViewDelegate,
    WSAssetPickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageViewIcon;

// switches
@property (weak, nonatomic) IBOutlet UISwitch *switchSpeed;
@property (weak, nonatomic) IBOutlet UISwitch *switchRandomize;
@property (weak, nonatomic) IBOutlet UISwitch *switchRepeat;
@property (weak, nonatomic) IBOutlet UISwitch *switchLandscape;

// button properties
@property (weak, nonatomic) IBOutlet UIButton *buttonShowLibrary;
@property (weak, nonatomic) IBOutlet UIButton *buttonStartStop;
@property (weak, nonatomic) IBOutlet UIButton *buttonBack;
@property (weak, nonatomic) IBOutlet UIButton *buttonPause;
@property (weak, nonatomic) IBOutlet UIButton *buttonNext;

// button actions
- (IBAction)buttonShowLibraryTouch:(id)sender;
- (IBAction)buttonSocialTouch:(id)sender;

// media playback controls
- (IBAction)buttonStartStopTouch:(id)sender;
- (IBAction)buttonBackTouch:(id)sender;
- (IBAction)buttonPauseTouch:(id)sender;
- (IBAction)buttonNextTouch:(id)sender;





@end

