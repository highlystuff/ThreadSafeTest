//
//  ViewController.m
//  ThreadSafeTest
//
//  Created by fengyadong on 2017/9/2.
//  Copyright © 2017年 bytedance. All rights reserved.
//

#import "ViewController.h"
#import <pthread.h>
#import "os/lock.h"

#define TICK(i, str)   NSDate *startTime##str##i = [NSDate date]
#define TOCK(i, str)   NSLog(@"%@, Time%d: %f", @#str, i, -[startTime##str##i timeIntervalSinceNow])
#define CALC(i, str) double value = dict[@#str].doubleValue; \
dict[@#str] = @(-[startTime##str##i timeIntervalSinceNow] + value);

#define TestThreadSafeMode(identifier,property,time,loop,ratio) \
@autoreleasepool {  \
    TICK(time, identifier); \
    dispatch_apply(loop, self.barrierQueue, ^(size_t i) {   \
        if(!(i % ratio)) { \
            self.property = [NSString stringWithFormat:@"abc%d",loop];  \
        } else {    \
            __unused NSString * temp = self.property;   \
        }   \
    }); \
    dispatch_barrier_sync(self.barrierQueue, ^{ \
        TOCK(time, identifier); \
        CALC(time, identifier); \
    }); \
}

#define TestSingleThread(identifier,property,time,loop) \
@autoreleasepool {  \
    TICK(time, identifier); \
    for (int i = 0; i < loop; i++) {    \
        self.property = [NSString stringWithFormat:@"abc%d",loop];  \
        __unused NSString * temp = self.property;   \
    }   \
    TOCK(time, identifier); \
    CALC(time, identifier); \
}

@interface ViewController () {
    NSLock *_lock;
    NSRecursiveLock *_recursiveLock;
    NSCondition *_condition;
    NSConditionLock *_conditionLock;
    pthread_mutex_t _mutex;
    dispatch_semaphore_t _semaphore;
    os_unfair_lock _unfair_lock;
    pthread_rwlock_t _rwlock;
    dispatch_queue_t _concurrentQueue;
}

@property (nonatomic, strong) NSString *synchronizedString;
@property (nonatomic, strong) NSString *nslockString;
@property (nonatomic, strong) NSString *recursiveLockString;
@property (nonatomic, strong) NSString *nsconditionString;
@property (nonatomic, strong) NSString *nsconditionLockString;
@property (nonatomic, strong) NSString *pthreadMutexString;
@property (nonatomic, strong) NSString *semaphoreString;
@property (nonatomic, strong) NSString *rwlockString;
@property (nonatomic, strong) NSString *unfairlockString;
@property (nonatomic, strong) NSString *barrierString;
@property (atomic, strong) NSString *atomicString;
@property (nonatomic, strong) NSString *nonatomicString;
@property (atomic, assign) NSUInteger atomicNumber;
@property (nonatomic, assign) NSUInteger nonatomicNumber;

@property (nonatomic, strong) dispatch_queue_t barrierQueue;



@end

@implementation ViewController

NSMutableDictionary<NSString *,NSNumber *> *dict;

@synthesize synchronizedString = _synchronizedString;
@synthesize nslockString = _nslockString;
@synthesize recursiveLockString = _recursiveLockString;
@synthesize nsconditionString = _nsconditionString;
@synthesize nsconditionLockString = _nsconditionLockString;
@synthesize pthreadMutexString = _pthreadMutexString;
@synthesize semaphoreString = _semaphoreString;
@synthesize rwlockString = _rwlockString;
@synthesize unfairlockString = _unfairlockString;
@synthesize barrierString = _barrierString;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
}

- (void)setup {
    _lock = [[NSLock alloc] init];
    _recursiveLock = [[NSRecursiveLock alloc] init];
    _condition = [[NSCondition alloc] init];
    _conditionLock = [[NSConditionLock alloc] init];
    pthread_mutex_init(&_mutex, NULL);
    _semaphore = dispatch_semaphore_create(1);
    _unfair_lock = OS_UNFAIR_LOCK_INIT;
    pthread_rwlock_init(&_rwlock, NULL);
    _concurrentQueue = dispatch_queue_create("concurrent", DISPATCH_QUEUE_CONCURRENT);
    dict = [NSMutableDictionary dictionaryWithCapacity:10];
    self.barrierQueue = dispatch_queue_create("barrier", DISPATCH_QUEUE_CONCURRENT);
    
    self.atomicNumber = 0;
    self.nonatomicNumber = 0;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Test Method

- (void)testMultiThread {
    int loop = 100000; //loop times
    int times = 10; //test times
    int ratio = 10; //the ratio of read to write
    for (int i = 0; i < times; i++) {
        TestThreadSafeMode(Synchronize,synchronizedString,i,loop,ratio)
        TestThreadSafeMode(NSLock,nslockString,i,loop,ratio)
        TestThreadSafeMode(NSRecursiveLock,recursiveLockString,i,loop,ratio)
        TestThreadSafeMode(NSCondition,nsconditionLockString,i,loop,ratio)
        TestThreadSafeMode(NSConditionLock,nsconditionLockString,i,loop,ratio)
        TestThreadSafeMode(PthreadMutex,pthreadMutexString,i,loop,ratio)
        TestThreadSafeMode(Semaphore,semaphoreString,i,loop,ratio)
        TestThreadSafeMode(RWLock,rwlockString,i,loop,ratio)
        TestThreadSafeMode(UnfairLock,unfairlockString,i,loop,ratio)
        TestThreadSafeMode(Barrier,barrierString,i,loop,ratio)
        TestThreadSafeMode(Atomic,atomicString,i,loop,ratio)
    }
    dispatch_barrier_sync(self.barrierQueue, ^{
        NSLog(@"%@", dict);
        [dict removeAllObjects];
    });
}

- (void)testSingleThread {
    int loop = 1000000; //loop times
    int times = 10; //test times
    for (int i = 0; i < times; i++) {
        TestSingleThread(Atomic,atomicString,i,loop)
        TestSingleThread(Nonatomic,nonatomicString,i,loop)
    }
    
    NSLog(@"%@", dict);
    [dict removeAllObjects];
}

- (void)testComplex {
    int loop = 100000; //loop times
    dispatch_apply(loop, self.barrierQueue, ^(size_t i) {
        self.atomicNumber++;
    });
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        NSLog(@"atomicNumber total:%lu", (unsigned long)self.atomicNumber);
    });
    
    dispatch_apply(loop, self.barrierQueue, ^(size_t i) {
        [_lock lock];
        self.nonatomicNumber++;
        [_lock unlock];
    });
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        NSLog(@"nonatomicNumber total:%lu", (unsigned long)self.nonatomicNumber);
    });
}

#pragma mark - Getters & Setters

- (NSString *)synchronizedString {
    @synchronized (self) {
        return _synchronizedString;
    }
}

- (void)setSynchronizedString:(NSString *)synchronizedString {
    @synchronized (self) {
        if (_synchronizedString != synchronizedString) {
            _synchronizedString = synchronizedString;
        }
    }
}

- (NSString *)nslockString {
    [_lock lock];
    NSString *string = _nslockString;
    [_lock unlock];
    return string;
}

- (void)setNslockString:(NSString *)nslockString {
    [_lock lock];
    if (_nslockString != nslockString) {
        _nslockString = nslockString;
    }
    [_lock unlock];
}

- (NSString *)recursiveLockString {
    [_recursiveLock lock];
    NSString *string = _recursiveLockString;
    [_recursiveLock unlock];
    return string;
}

- (void)setRecursiveLockString:(NSString *)recursiveLockString {
    [_recursiveLock lock];
    if (_recursiveLockString != recursiveLockString) {
        _recursiveLockString = recursiveLockString;
    }
    [_recursiveLock unlock];
}

- (NSString *)nsconditionString {
    [_condition lock];
    NSString *string = _nsconditionString;
    [_condition unlock];
    return string;
}

- (void)setNsconditionString:(NSString *)nsconditionString {
    [_condition lock];
    if (_nsconditionString != nsconditionString) {
        _nsconditionString = nsconditionString;
    }
    [_condition unlock];
}

- (NSString *)nsconditionLockString {
    [_conditionLock lock];
    NSString *string = _nsconditionLockString;
    [_conditionLock unlock];
    return string;
}

- (void)setNsconditionLockString:(NSString *)nsconditionLockString{
    [_conditionLock lock];
    if (_nsconditionLockString != nsconditionLockString) {
        _nsconditionLockString = nsconditionLockString;
    }
    [_conditionLock unlock];
}

- (NSString *)pthreadMutexString {
    pthread_mutex_lock(&_mutex);
    NSString *string = _pthreadMutexString;
    pthread_mutex_unlock(&_mutex);
    return string;
}

- (void)setPthreadMutexString:(NSString *)pthreadMutexString {
    pthread_mutex_lock(&_mutex);
    if (_pthreadMutexString != pthreadMutexString) {
        _pthreadMutexString = pthreadMutexString;
    }
    pthread_mutex_unlock(&_mutex);
}

- (NSString *)semaphoreString {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSString *string = _semaphoreString;
    dispatch_semaphore_signal(_semaphore);
    return string;
}

- (void)setSemaphoreString:(NSString *)semaphoreString {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_semaphoreString != semaphoreString) {
        _semaphoreString = semaphoreString;
    }
    dispatch_semaphore_signal(_semaphore);
}

- (NSString *)rwlockString {
    pthread_rwlock_rdlock(&_rwlock);
    NSString *string = _rwlockString;
    pthread_rwlock_unlock(&_rwlock);
    return string;
}

- (void)setRwlockString:(NSString *)rwlockString {
    pthread_rwlock_wrlock(&_rwlock);
    if (_rwlockString != rwlockString) {
        _rwlockString = rwlockString;
    }
    pthread_rwlock_unlock(&_rwlock);
}

- (NSString *)unfairlockString {
    os_unfair_lock_lock(&_unfair_lock);
    NSString *string = _semaphoreString;
    os_unfair_lock_unlock(&_unfair_lock);
    return string;
}

- (void)setUnfairlockString:(NSString *)unfairlockString {
    os_unfair_lock_lock(&_unfair_lock);
    if (_unfairlockString != unfairlockString) {
        _unfairlockString = unfairlockString;
    }
    os_unfair_lock_unlock(&_unfair_lock);
}

- (NSString *)barrierString {
    __block NSString *string;
    dispatch_sync(_concurrentQueue, ^{
        string = _barrierString;
    });
    return string;
}

- (void)setBarrierString:(NSString *)barrierString {
    dispatch_barrier_async(_concurrentQueue, ^{
        if (_barrierString != barrierString) {
            _barrierString = barrierString;
        }
    });
}

#pragma IBAction

- (IBAction)btn1Clicked {
    [self testMultiThread];
}

- (IBAction)btn2Clicked {
    [self testSingleThread];
}

- (IBAction)btn3Clicked {
    [self testComplex];
}

@end
