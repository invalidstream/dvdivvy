//
//  SNFEpisodeSlicer.h
//  DVDivvy
//
//  Created by Chris Adamson on 9/20/13.
//  Copyright (c) 2013 Subsequently & Furthermore, Inc. CC0 License - http://creativecommons.org/about/cc0//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface SNFMainWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) AVAsset *asset;

-(BOOL) openURL: (NSURL*) url;

@end
