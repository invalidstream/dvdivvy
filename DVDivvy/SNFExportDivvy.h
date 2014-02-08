//
//  SNFExportDivvy.h
//  DVDivvy
//
//  Created by Chris Adamson on 10/5/13.
//  Copyright (c) 2013 Subsequently & Furthermore, Inc. CC0 License - http://creativecommons.org/about/cc0//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SNFExportDivvyDelegate.h"

@interface SNFExportDivvy : NSObject

@property (strong) AVAsset *asset;
@property (strong) NSURL *assetURL;
@property (strong) NSURL *outputDirectoryURL;
@property (weak) id<SNFExportDivvyDelegate> delegate;

-(void) setTimeRanges: (CMTimeRange[]) timeRanges count: (NSInteger) count;

-(void) startDivvy;

/** Returns overall progress of all exports, on a scale of 0 to 1. Returns -1 if
	no export is underway.
 */
-(float) progress;

@end
