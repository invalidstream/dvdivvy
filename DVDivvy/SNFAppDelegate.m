//
//  SNFAppDelegate.m
//  DVDivvy
//
//  Created by Chris Adamson on 9/20/13.
//  Copyright (c) 2013 Subsequently & Furthermore, Inc. CC0 License - http://creativecommons.org/about/cc0//

#import "SNFAppDelegate.h"
#import "SNFMainWindowController.h"


@implementation SNFAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
}


-(void) openDocument: (id) sender {
	NSLog (@"openDocument: %@", sender);
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel beginSheetModalForWindow:self.window
					  completionHandler:^(NSInteger result)
	 {
		 if (result == NSCancelButton) {
			 return;
		 }
		 NSLog (@"got %@", [openPanel URL]);
		 NSLog (@"window is %@, window controller is %@",
				self.window, [self.window windowController]);
		 [[self.window windowController] openURL: [openPanel URL]];
	 }];
	
}

-(void) newDocument: (id) sender {
	NSBeep();
}

@end
