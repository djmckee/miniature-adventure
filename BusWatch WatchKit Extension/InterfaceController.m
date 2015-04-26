//
//  InterfaceController.m
//  BusWatch WatchKit Extension
//
//  Created by Dylan McKee on 26/04/2015.
//  Copyright (c) 2015 djmckee. All rights reserved.
//

#import "InterfaceController.h"
#import "HTMLDocument.h"
#import "HTMLElement.h"
#import "HTMLSelector.h"
#import "HTMLNode.h"
#import "BusCell.h"

@interface InterfaceController()

@end

@implementation InterfaceController

NSString *const BusStopId = @"South%20Gosforth%20Roundabout%23132804";
// South%20Gosforth%20Roundabout%23132804

// obtain your BusStopId from http://app.arrivabus.co.uk/journeyplanner/stboard/en?ld=std&OK#focus - find your bus stop, click 'Show Arrivals', and deconstruct the URL (manually 😓 to find the ID you need).

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    // Configure interface objects here.
    [self setTitle:@"BusWatch"];
    
    // reload data on launch
    [self reloadData];
    
    // and re-load every minute on timer...
    [NSTimer scheduledTimerWithTimeInterval:(60.0) target:self selector:@selector(reloadData) userInfo:nil repeats:YES];

}

-(void)reloadData {
    
    // get the current date so we can get time from it.
    NSDate *currentDate = [NSDate date];
    
    // set up a date formatter so we can parse current time into HH:mm
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"HH:mm"];
    NSString *timeString = [formatter stringFromDate:currentDate];
    
    // URL String is a constant template.
    NSString *urlString = @"http://app.arrivabus.co.uk/journeyplanner/stboard/en?input=BUSSTOPID&boardType=dep&time=TIMEPLACEHOLDER&maxJourneys=50&dateBegin=&dateEnd=&selectDate=&productsFilter=1111111111111111&start=yes&dirInput=&viewMode=COMPACT&";
    
    // set up variables in template (current time and bus stop ID).
    urlString = [urlString stringByReplacingOccurrencesOfString:@"TIMEPLACEHOLDER" withString:timeString];
    urlString = [urlString stringByReplacingOccurrencesOfString:@"BUSSTOPID" withString:BusStopId];

    NSLog(@"urlString = %@", urlString);
    
    // create URL from our curated string.
    NSURL *URL = [NSURL URLWithString:urlString];
    
    // fake user agent to stop blocking of our unofficial client.
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPAdditionalHeaders = @{ @"User-Agent": @"Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2049.0 Safari/537.36" };
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    // begin URL request
    [[session dataTaskWithURL:URL completionHandler:
      ^(NSData *data, NSURLResponse *response, NSError *error) {
          NSLog(@"done task! got response = %@", response);
          NSString *contentType = nil;
          if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
              NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
              contentType = headers[@"Content-Type"];
          }
          
          // we got data! parse it...
          
          HTMLDocument *page = [HTMLDocument documentWithData:data
                                            contentTypeHeader:contentType];
          
          // look inside the table of bus times
          NSArray *busses = [page nodesMatchingSelector:@"#main > ul > li > div > table > tbody > tr > td"];
          NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
          
          NSMutableArray *array = [NSMutableArray array];
          
          // gross HTML Parsing.
          int count = 0;
          NSMutableDictionary *dict;
          for (HTMLElement *bus in busses) {
              count++;
              if (count < 2) {
                  continue;
              }
              
              NSString *string = [bus.textContent stringByTrimmingCharactersInSet:whitespace];
              
              if ([string containsString:@"Bus   "] || [string containsString:@"Bus  "]) {
                  string = [string stringByReplacingOccurrencesOfString:@"Bus  " withString:@""];
                  string = [string stringByTrimmingCharactersInSet:whitespace];
              }
              
              if ([string containsString:@" - "]) {
                  string = [string substringToIndex:[string rangeOfString:@" - "].location];
                  
                  // bus time
                  if (!dict) {
                      continue;
                  }
                  
                  if ([string containsString:@"\n"]) {
                      string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

                  }
                  
                  [dict setObject:string forKey:@"busTime"];
                  [array addObject:dict];
                  
              } else {
                  dict = [NSMutableDictionary dictionary];
                  [dict setObject:string forKey:@"busName"];
              }
              
              if ([string isEqualToString:@"Bus"]) {
                  break;
              }
              

              NSLog(@"%@", string);
          }
          
          // we're only interested in what's being tracked live - get rid of static busses!
          NSMutableArray *liveBusses = [NSMutableArray array];
          for (NSDictionary *dict in array) {
              if ([[dict objectForKey:@"busTime"] containsString:@"')"]) {
                  // they're definitely tracking this bus live...
                  [liveBusses addObject:dict];
              }
          }
          
          // do some sorting...
          liveBusses = [NSMutableArray arrayWithArray:[liveBusses sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
              NSString *first = [(NSDictionary*)a objectForKey:@"busTime"];
              NSString *second = [(NSDictionary*)b objectForKey:@"busTime"];
              return [first compare:second];
          }]];
          
          // we only care about live busses.
          array = liveBusses;
          
          // Configure interface objects here.
          [self.table setNumberOfRows:array.count withRowType:@"BusCell"];
        
          
          NSLog(@"array = %@", array);
          
          // set up table view cells for each row in the array.
          for (int i = 0; i < array.count; i++) {
              BusCell *row = [self.table rowControllerAtIndex:i];
              NSDictionary *busInfo = [array objectAtIndex:i];
              row.busLabel.text = [busInfo objectForKey:@"busName"];
              row.timeLabel.text = [busInfo objectForKey:@"busTime"];
              
              if ([[busInfo objectForKey:@"busTime"] containsString:@"+0'"]) {
                  // on time - make it green
                  row.timeLabel.textColor = [UIColor greenColor];
              } else if ([[busInfo objectForKey:@"busTime"] containsString:@"(-"]) {
                  // the bus is early :o make it blue
                  row.timeLabel.textColor = [UIColor blueColor];

              }else {
                  // not on time - make it red
                  row.timeLabel.textColor = [UIColor redColor];

              }
              
          }
          
          
      }] resume];

}

-(IBAction)refresh:(id)sender{
    // reload data on refersh button click too.
    [self reloadData];
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

@end



