//
//  SNFExportDivvy.m
//  DVDivvy
//
//  Created by Chris Adamson on 10/5/13.
//  Copyright (c) 2013 Subsequently & Furthermore, Inc. CC0 License - http://creativecommons.org/about/cc0//

#import "SNFExportDivvy.h"

#define MAXIMUM_TIME_RANGES 100

@interface SNFExportDivvy()
@property (strong) AVAssetExportSession *exporter;
@property (assign) NSInteger currentExportRangeIndex;
@end


@implementation SNFExportDivvy {
	CMTimeRange _timeRanges[MAXIMUM_TIME_RANGES];
	NSInteger _timeRangesCount;
}

/** Copies off the array of CFTimeRange structs, since it's possible the caller
	has them on the stack and they'll go out of scope during the asynchronous export
 */
-(void) setTimeRanges: (CMTimeRange[]) timeRanges count: (NSInteger) count {
	if (count > MAXIMUM_TIME_RANGES) {
		NSException *tooManySegmentsException = [NSException exceptionWithName:@"Too many segments"
																		reason:@"Can only divvy 100 segments"
																	  userInfo:nil];
		[tooManySegmentsException raise];
	}
	_timeRangesCount = count;
	for (int i=0; i<count; i++) {
		_timeRanges[i] = timeRanges[i];
	}
}


-(void) startDivvy {
	self.currentExportRangeIndex = 0;
	[self nextExport];
}

-(void) nextExport {
	self.exporter = [AVAssetExportSession exportSessionWithAsset:self.asset
													  presetName:AVAssetExportPresetPassthrough];
	
	NSString *outputFileType;
	NSString *outputExtension = [self.assetURL pathExtension];
	if ([outputExtension isEqualToString:@"mp4"] ||
		[outputExtension isEqualToString:@"MP4"] ||
		[outputExtension isEqualToString:@"m4v"]) {
		outputFileType = AVFileTypeMPEG4;
	} else {
		outputFileType = AVFileTypeQuickTimeMovie;
	}
	self.exporter.outputFileType = outputFileType;
	
	NSString *outputName = [NSString stringWithFormat:@"%@-part%0.2ld.%@",
							[[self.assetURL lastPathComponent] stringByDeletingPathExtension],
							self.currentExportRangeIndex,
							[self.assetURL pathExtension]];
	NSURL *outputURL = [self.outputDirectoryURL URLByAppendingPathComponent:outputName];
	self.exporter.outputURL = outputURL;
	NSString *outputPath = [outputURL path];
	if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
		[[NSFileManager defaultManager] removeItemAtURL:outputURL
												  error:nil];
	}
	
	self.exporter.timeRange = _timeRanges[self.currentExportRangeIndex];
	NSLog (@"start export %ld", (long)self.currentExportRangeIndex);
	__weak SNFExportDivvy *weakSelf = self;
	[self.exporter exportAsynchronouslyWithCompletionHandler:^{
		NSLog (@"export %ld done, error is %@",
			   weakSelf.currentExportRangeIndex,
			   weakSelf.exporter.error);
		weakSelf.currentExportRangeIndex++;
		if (weakSelf.currentExportRangeIndex < _timeRangesCount) {
			[weakSelf nextExport];
		} else {
			[weakSelf.delegate divvyDidFinish:weakSelf];
		}
	}];

}

-(float) progress {
	if (! self.exporter) {
		return -1;
	}
	if (self.exporter.status == AVAssetExportSessionStatusCompleted &&
		self.currentExportRangeIndex == _timeRangesCount) {
		return 1;
	}
	if (self.exporter.status != AVAssetExportSessionStatusExporting) {
		return -1;
	}

	float progress = self.currentExportRangeIndex / (float) _timeRangesCount;
	progress += [self.exporter progress] * (1.0 / (float) _timeRangesCount);
	
	return progress;
}

@end
