//
//  SNFExportDivvyDelegate.h
//  DVDivvy
//
//  Created by Chris Adamson on 10/5/13.
//  Copyright (c) 2013 Subsequently & Furthermore, Inc. CC0 License - http://creativecommons.org/about/cc0//

#import <Foundation/Foundation.h>
@class SNFExportDivvy;

@protocol SNFExportDivvyDelegate <NSObject>

-(void) divvyDidFinish: (SNFExportDivvy*) divvy;

@end
