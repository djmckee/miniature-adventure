//
//  InterfaceController.h
//  BusWatch WatchKit Extension
//
//  Created by Dylan McKee on 26/04/2015.
//  Copyright (c) 2015 djmckee. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface InterfaceController : WKInterfaceController

@property (weak) IBOutlet WKInterfaceTable *table;


-(IBAction)refresh:(id)sender;

@end
