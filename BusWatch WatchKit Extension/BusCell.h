//
//  BusCell.h
//  BusWatch
//
//  Created by Dylan McKee on 26/04/2015.
//  Copyright (c) 2015 djmckee. All rights reserved.
//

#import <Foundation/Foundation.h>
@import WatchKit;

@interface BusCell : NSObject

@property (weak) IBOutlet WKInterfaceLabel *busLabel;
@property (weak) IBOutlet WKInterfaceLabel *timeLabel;

@end
