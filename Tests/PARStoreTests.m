//  PARStoreTests
//  Created by Charles Parnot on 3/2/13.
//  Copyright (c) 2013 Charles Parnot. All rights reserved.

#import "PARStoreTests.h"
#import "PARStoreExample.h"
#import "PARNotificationSemaphore.h"

@implementation PARStoreTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (NSString *)deviceIdentifierForTest
{
    return @"948E9EEE-3398-4DD7-9183-C56866EF2350";
}

- (void)testCreateThenLoadDocument
{
    // first load = create and load store
    NSURL *url = [[self urlWithUniqueTmpDirectory] URLByAppendingPathComponent:@"doc.parstore"];
    PARStoreExample *document1 = [PARStoreExample storeWithURL:url deviceIdentifier:[self deviceIdentifierForTest]];
    [document1 loadNow];
    STAssertTrue([document1 loaded], @"Document not loaded");
    [document1 closeNow];
    STAssertFalse([document1 loaded], @"Document should not be loaded after closing it");
    document1 = nil;
    
    // second load = load document
    PARStoreExample *document2 = [PARStoreExample storeWithURL:url deviceIdentifier:[self deviceIdentifierForTest]];
    [document2 loadNow];
    STAssertTrue([document2 loaded], @"Document not loaded");
    [document2 closeNow];
    STAssertFalse([document2 loaded], @"Document should not be loaded after closing it");
    document2 = nil;
}

- (void)testCreateThenDeleteDocument
{
    // first load = create and load document
    NSURL *url = [[self urlWithUniqueTmpDirectory] URLByAppendingPathComponent:@"doc.parstore"];
    PARStoreExample *document1 = [PARStoreExample storeWithURL:url deviceIdentifier:[self deviceIdentifierForTest]];
    [document1 loadNow];
    STAssertTrue([document1 loaded], @"Document not loaded");
    
    PARNotificationSemaphore *semaphore = [PARNotificationSemaphore semaphoreForNotificationName:PARStoreDidDeleteNotification object:document1];
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForDeleting error:NULL byAccessor:^(NSURL *newURL)
     {
         NSError *fmError = nil;
         BOOL fileDeletionSucceeeded = [[NSFileManager defaultManager] removeItemAtURL:newURL error:&fmError];
         STAssertTrue(fileDeletionSucceeeded, @"The file could not be deleted by NSFileManager: %@", [url path]);
     }];
    BOOL completedWithoutTimeout = [semaphore waitUntilNotificationWithTimeout:15.0];
    STAssertTrue(completedWithoutTimeout, @"Timeout while waiting for document deletion");
    
    STAssertTrue([document1 deleted], @"Document should be marked as deleted");
    [document1 closeNow];
    STAssertFalse([document1 deleted], @"Document should not marked as deleted anymore after closing it");
    document1 = nil;
}

- (void)testFilePackageIsNotDirectory
{
    // create and load document
    NSURL *url = [[self urlWithUniqueTmpDirectory] URLByAppendingPathComponent:@"doc.parstore"];
    PARStoreExample *sound1 = [PARStoreExample storeWithURL:url deviceIdentifier:[self deviceIdentifierForTest]];
    [sound1 loadNow];
    STAssertTrue([sound1 loaded], @"Document not loaded");
    [sound1 closeNow];
    sound1 = nil;
    
    // mess up the file package
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
    STAssertTrue(success, @"Could not remove directory:\nurl: %@\nerror: %@", url, error);
    success = [@"blah" writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    STAssertTrue(success, @"Could not write string to disk:\nurl: %@\nerror: %@", url, error);
    
    // second load = load document
    PARStoreExample *store2 = [PARStoreExample storeWithURL:url deviceIdentifier:[self deviceIdentifierForTest]];
    [store2 loadNow];
    STAssertFalse([store2 loaded], @"Corrupted document should not load");
    [store2 closeNow];
    store2 = nil;
}

- (void)testStoreSync
{
	NSURL *url = [[self urlWithUniqueTmpDirectory] URLByAppendingPathComponent:@"SyncTest.parstore"];
	
    PARStoreExample *store1 = [PARStoreExample storeWithURL:url deviceIdentifier:@"1"];
    [store1 loadNow];
	STAssertTrue([store1 loaded], @"Store not loaded");
	STAssertNil(store1.title, @"A new store should not have a title");
	
	PARStoreExample *store2 = [PARStoreExample storeWithURL:url deviceIdentifier:@"2"];
    [store2 loadNow];
	STAssertTrue([store2 loaded], @"Store not loaded");
	STAssertNil(store2.title, @"A new store should not have a title");
	
    // change first store --> should trigger a change in the second store
    PARNotificationSemaphore *semaphore = [PARNotificationSemaphore semaphoreForNotificationName:PARStoreDidSyncNotification object:store2];
    NSString *title = @"The Title";
	store1.title = title;
    BOOL completedWithoutTimeout = [semaphore waitUntilNotificationWithTimeout:10.0];
	
    STAssertTrue(completedWithoutTimeout, @"Timeout while waiting for document change");
	STAssertEqualObjects(store1.title, title, @"Title is '%@' but should be '%@'", store1.title, title);
	STAssertEqualObjects(store2.title, title, @"Title is '%@' but should be '%@'", store2.title, title);
    
    [store1 closeNow];
    [store2 closeNow];
}

// same as `testStoreSync` but changing store 2
- (void)testDeviceAddition
{
	NSURL *url = [[self urlWithUniqueTmpDirectory] URLByAppendingPathComponent:@"SyncTest.parstore"];
	
    PARStoreExample *store1 = [PARStoreExample storeWithURL:url deviceIdentifier:@"1"];
    [store1 loadNow];
	STAssertTrue([store1 loaded], @"Store not loaded");
	STAssertNil(store1.title, @"A new store should not have a title");
    
    // add second device --> should trigger a sync in the first store, though no change yet
	PARStoreExample *store2 = [PARStoreExample storeWithURL:url deviceIdentifier:@"2"];
    [store2 loadNow];
	STAssertTrue([store2 loaded], @"Store not loaded");
	STAssertNil(store2.title, @"A new store should not have a title");
	
    // change second store --> should trigger a change in the first store
    PARNotificationSemaphore *semaphore = [PARNotificationSemaphore semaphoreForNotificationName:PARStoreDidSyncNotification object:store1];
    NSString *title = @"The Title";
	store2.title = title;
    BOOL completedWithoutTimeout = [semaphore waitUntilNotificationWithTimeout:10.0];
	
    STAssertTrue(completedWithoutTimeout, @"Timeout while waiting for document change");
	STAssertEqualObjects(store1.title, title, @"Title is '%@' but should be '%@'", store1.title, title);
	STAssertEqualObjects(store2.title, title, @"Title is '%@' but should be '%@'", store2.title, title);
    
    [store1 closeNow];
    [store2 closeNow];
}

// old bug now fixed
- (void) testStoreLoadNotificationDeadlock
{
	NSUUID *deviceUUID = [NSUUID UUID];
	NSURL *url = [[self urlWithUniqueTmpDirectory] URLByAppendingPathComponent:@"doc.parstore"];
	
	// create a store
	PARStoreExample *store1 = [PARStoreExample storeWithURL:url deviceIdentifier:[deviceUUID UUIDString]];
	[store1 loadNow];
    NSString *title = @"The Title";
	store1.title = title;
	[store1 closeNow];
	
	// load store at same url again
	PARStoreExample *store2 = [PARStoreExample storeWithURL:url deviceIdentifier:[deviceUUID UUIDString]];
	
    // accessing a property on the dataQueue should not result in a dead-lock
	[[NSNotificationCenter defaultCenter] addObserverForName:PARStoreDidLoadNotification object:store2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note)
     {
         NSString *title2 = store2.title;
         title2 = nil;
     }];
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
		// fires did load notification on data queue, observer accesses layout, which also performs sync op on dataqueue
		[store2 loadNow];
		dispatch_semaphore_signal(sema);
	});
    
	long waitResult = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10.0 * NSEC_PER_SEC));
	// NSLog(@"Wait result: %ld", waitResult);
	
	STAssertTrue(waitResult == 0, @"Timeout while waiting for document to load");
}

@end