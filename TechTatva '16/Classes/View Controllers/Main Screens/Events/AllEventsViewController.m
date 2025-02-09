//
//  AllEventsViewController.m
//  TechTatva '16
//
//  Created by Abhishek Vora on 01/10/16.
//  Copyright © 2016 YASH. All rights reserved.
//

#import "AllEventsViewController.h"
#import "AllEventsTableViewCell.h"
#import "Favourite+CoreDataClass.h"
#import "Favourite+CoreDataProperties.h"
#import "ScheduleJsonDataModel.h"
#import "FeedbackTableViewController.h"

@interface AllEventsViewController () <UISearchResultsUpdating, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, UISearchControllerDelegate>

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewTopConstraint;

@end

@implementation AllEventsViewController
{
    NSArray *fetchArray;
    NSMutableArray *favouritesArray;
    NSMutableArray *filteredEvents;
    NSArray *array;
    Reachability *reachability;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    favouritesArray = [NSMutableArray new];
    filteredEvents = [NSMutableArray new];
    allEventsSegmentControl.selectedSegmentIndex = 0;
	allEventsSegmentControl.tintColor = GLOBAL_TINT_RED;
    
    reachability = [Reachability reachabilityForInternetConnection];
    if (reachability.isReachable)
    {
		SVHUD_SHOW;
        [self loadFromApi];
    }
    else
        [self loadFromCache];
    
    allEventsArray = [[NSArray alloc]initWithArray:fetchArray];
    searchedAllEventsArray = [[NSMutableArray alloc]initWithArray:allEventsArray];
	
	[allEventsTableView registerNib:[UINib nibWithNibName:@"AllEventsTableViewCell" bundle:nil] forCellReuseIdentifier:@"AllEveCell"];
    
    [self setupSearchController];
	
	[self.navigationController.navigationBar setTranslucent:NO];
	[self.navigationController.navigationBar setShadowImage:[UIImage imageNamed:@"TransparentPixel"]];
	[self.navigationController.navigationBar setBackgroundColor:GLOBAL_BACK_COLOR];
	[self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"Pixel"] forBarMetrics:UIBarMetricsDefault];
}

- (void) loadFromCache
{
    NSUserDefaults *events =[NSUserDefaults standardUserDefaults];
    //    NSLog(@"CACHE %@", [categoryData objectForKey:@"category"]);
    if ([events objectForKey:@"allevents"] != nil)
    {
        id savedData = [events objectForKey:@"allevents"];
        id requiredArray = [savedData valueForKey:@"data"];
        array = [ScheduleJsonDataModel getArrayFromJson:requiredArray];
    }
    SVHUD_HIDE;
}

- (void) saveLocalData:(id)jsonData
{
    NSUserDefaults *eventData = [NSUserDefaults standardUserDefaults];
    [eventData setObject:jsonData forKey:@"allevents"];
    [eventData synchronize];
}

- (void)setupSearchController
{
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.delegate = self;
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleProminent;
	UITextField *tfield = [self.searchController.searchBar valueForKey:@"_searchField"];
	tfield.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    self.searchController.searchBar.delegate = self;
	self.searchController.searchBar.showsScopeBar = NO;
//	self.searchController.searchBar.scopeButtonTitles = @[@"DAY 1", @"DAY 2", @"DAY 3", @"DAY 4"]; // FRAK THIS SHIT; I'LL FRAKKING PUT IT IN THE NAV BAR
    self.searchController.searchBar.backgroundColor = GLOBAL_BACK_COLOR;
    self.searchController.searchBar.tintColor = GLOBAL_TINT_RED;
	self.searchController.searchBar.barTintColor = GLOBAL_BACK_COLOR;
    self.searchController.dimsBackgroundDuringPresentation = NO;
	self.searchController.hidesNavigationBarDuringPresentation = NO;
    self.definesPresentationContext = NO;
//    allEventsTableView.tableHeaderView = self.searchController.searchBar;
	self.navigationItem.titleView = self.searchController.searchBar;
}

- (void) loadFromApi
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            
            NSURL *custumUrl = [[NSURL alloc]initWithString:@""];
            NSData *mydata = [NSData dataWithContentsOfURL:custumUrl];
            NSError *error;
            
            if (mydata!=nil)
            {
                id jsonData = [NSJSONSerialization JSONObjectWithData:mydata options:kNilOptions error:&error];
                id requiredArray = [jsonData valueForKey:@"data"];
                array = [ScheduleJsonDataModel getArrayFromJson:requiredArray];
                [self saveLocalData:jsonData];
//                filteredEvents = [array mutableCopy];
				SVHUD_HIDE;
                dispatch_async(dispatch_get_main_queue(), ^{
					[self filterEventsForSearchString:self.searchController.searchBar.text andScopeBarTitle:[allEventsSegmentControl titleForSegmentAtIndex:allEventsSegmentControl.selectedSegmentIndex]];
                });
            }
        }
        @catch (NSException *exception) {
            
        }
        @finally {
            
        }
    });
}

- (BOOL)checkIfFavorite:(NSString *)eventID
{
    NSFetchRequest *fetchFavourite = [NSFetchRequest fetchRequestWithEntityName:@"Favourite"];
    [fetchFavourite setPredicate:[NSPredicate predicateWithFormat:@"eventID == %@", eventID]];
    NSError *error = nil;
    fetchArray = [[Favourite managedObjectContext] executeFetchRequest:fetchFavourite error:&error];
    return (fetchArray.count > 0);
}

- (IBAction)allEventsSegmentChange:(id)sender
{
    if(allEventsSegmentControl.selectedSegmentIndex == 0) {
        NSLog(@"Day 1 selected.");
    } else if(allEventsSegmentControl.selectedSegmentIndex == 1) {
        NSLog(@"Day 2 selected.");
    } else if(allEventsSegmentControl.selectedSegmentIndex == 2) {
        NSLog(@"Day 3 selected.");
    } else if(allEventsSegmentControl.selectedSegmentIndex == 3) {
        NSLog(@"Day 4 selected.");
    }
	[self filterEventsForSearchString:self.searchController.searchBar.text andScopeBarTitle:[allEventsSegmentControl titleForSegmentAtIndex:allEventsSegmentControl.selectedSegmentIndex]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (filteredEvents.count == 0)
        return 0;
    return filteredEvents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ScheduleJsonDataModel *event = [filteredEvents objectAtIndex:indexPath.row];
    static NSString *cellIdentifier = @"AllEveCell";
    AllEventsTableViewCell *cell = (AllEventsTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[AllEventsTableViewCell alloc] init];
    }
    cell.eventName.text = [NSString stringWithFormat:@"%@ R%@", event.eventName, event.round];
    cell.categoryName.text = event.catName;
    cell.venue.text = event.place;
    cell.date.text = event.date;
    cell.time.text = [NSString stringWithFormat:@"%@ - %@", event.sTime, event.eTime];
    NSString *favImageName;
    if ([self checkIfFavorite:event.eventId])
        favImageName = @"FilledFavourites.png";
    else
        favImageName = @"Favourites.png";
    [cell.favouritesButton setBackgroundImage:[UIImage imageNamed:favImageName] forState:UIControlStateNormal];
    [cell.rateEvent addTarget:self action:@selector(rateEvent:) forControlEvents:UIControlEventTouchUpInside];
    [cell.favouritesButton addTarget:self action:@selector(switchFavourites:) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self.searchController.searchBar resignFirstResponder];
}

- (BOOL) checkTheDate
{
    NSDate *now = [NSDate date];
    NSString *dateString = @"12.10.2016";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd.MM.yy"];
    NSDate *startTT = [formatter dateFromString:dateString];
    NSComparisonResult result = [now compare:startTT];
    if (result == NSOrderedAscending)
        return false;
    else
        return true;
}

- (void) rateEvent :(id) sender
{
    if ([self checkTheDate])
    {
        NSIndexPath *indexPath = [allEventsTableView indexPathForRowAtPoint:[sender convertPoint:CGPointZero toView:allEventsTableView]];
        ScheduleJsonDataModel *event = [filteredEvents objectAtIndex:indexPath.row];
        UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
        UINavigationController * navController = [storyboard instantiateViewControllerWithIdentifier:@"feedbackNav"];
        FeedbackTableViewController * destController = [navController viewControllers][0];
        destController.title = event.eventName;
        destController.nameOfEvent = event.eventName;
        destController.nameOfCategory = event.catName;
        destController.eventId = event.eventId;
        destController.categoryId = event.catId;
        [self presentViewController:navController animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Too Early!" message:@"TechTatva 16 has not yet started. No categories are trending. Check back later" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }
}

- (void) switchFavourites:(id) someObject
{
    
    NSIndexPath *indexPath = [allEventsTableView indexPathForRowAtPoint:[someObject convertPoint:CGPointZero toView:allEventsTableView]];
    
    ScheduleJsonDataModel *event = [filteredEvents objectAtIndex:indexPath.row];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Favourite"];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"eventID == %@", event.eventId]];
    NSError *error = nil;
    
    NSArray *fetchedArray = [[Favourite managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    
    if (fetchedArray.count > 0)
    {
//        UIAlertView *addedAlert = [[UIAlertView alloc]initWithTitle:@"Event Already Added!" message:nil delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:nil, nil];
//        [addedAlert show];
        
        // Remove from favs
        
        Favourite *favouriteEvent = fetchedArray.firstObject;
        NSLog(@"delete this %@", favouriteEvent.eventID);
        
        [[Favourite managedObjectContext] deleteObject:favouriteEvent];
        
        if (![[Favourite managedObjectContext] save:&error])
        {
            
            NSLog(@"%@",error);
            
        }
        
    }
    else
    {
//        AllEventsTableViewCell *allEvent = [allEventsTableView cellForRowAtIndexPath:indexPath];
        
        NSManagedObjectContext * context = [Favourite managedObjectContext];
        
        Favourite *favouriteEvent = [NSEntityDescription insertNewObjectForEntityForName:@"Favourite" inManagedObjectContext:context];
        
        favouriteEvent.favourite = @"1";
        favouriteEvent.eventID = event.eventId;
		favouriteEvent.eventName = event.eventName;
		favouriteEvent.categoryID = event.catId;
		favouriteEvent.categoryName = event.catName;
		favouriteEvent.date = event.date;
		favouriteEvent.startTime = event.sTime;
		favouriteEvent.endTime = event.eTime;
		favouriteEvent.location = event.place;
		favouriteEvent.round = event.round;
        // CONTINUE
        
        if (![context save:&error])
        {
            
            NSLog(@"%@",error);
            
        }
        
    
    }
    
    [allEventsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView beginUpdates];
    if (!([indexPath compare:self.selectedIndexPath] == NSOrderedSame))
        self.selectedIndexPath = indexPath;
    else
        self.selectedIndexPath = nil;
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [tableView endUpdates];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath compare:self.selectedIndexPath] == NSOrderedSame)
        return 235.f;
    return 66.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	return [UIView new];
}

#pragma mark - Filtering

- (void)filterEventsForSearchString:(NSString *)searchString andScopeBarTitle:(NSString *)scopeTitle
{
    if ([searchString isEqualToString:@"Harambe"])
    {
        UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
        UINavigationController *navController = [storyboard instantiateViewControllerWithIdentifier:@"easterEggNav"];
        [self presentViewController:navController animated:YES completion:nil];
    }
    filteredEvents = [NSMutableArray arrayWithArray:array];
	[filteredEvents sortUsingComparator:^NSComparisonResult(ScheduleJsonDataModel *obj1, ScheduleJsonDataModel *obj2) {
		if ([obj1.catName isEqualToString:@"Turing"]) {
			return NSOrderedAscending;
		} else if ([obj2.catName isEqualToString:@"Turing"]) {
			return NSOrderedDescending;
		} return [obj1.eventName compare:obj2.eventName];
	}];
	if (allEventsSegmentControl.selectedSegmentIndex != 4)
		[filteredEvents filterUsingPredicate:[NSPredicate predicateWithFormat:@"day == %@", [scopeTitle substringFromIndex:4]]];
	if (searchString.length > 0) {
			[filteredEvents filterUsingPredicate:[NSPredicate predicateWithFormat:@"eventName contains[cd] %@  OR catName contains[cd] %@", searchString, searchString]];
	}
    [allEventsTableView reloadData];
}

#pragma mark - Search controller results updating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    UISearchBar *searchBar = searchController.searchBar;
	[self filterEventsForSearchString:searchBar.text andScopeBarTitle:[allEventsSegmentControl titleForSegmentAtIndex:allEventsSegmentControl.selectedSegmentIndex]];
}

#pragma mark - Search bar delegate

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    if (searchBar.text.length > 0)
        [self filterEventsForSearchString:searchBar.text andScopeBarTitle:searchBar.scopeButtonTitles[searchBar.selectedScopeButtonIndex]];
    else
        [self searchBarCancelButtonClicked:searchBar];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	filteredEvents = [array mutableCopy];
	[allEventsTableView reloadData];
}

@end
