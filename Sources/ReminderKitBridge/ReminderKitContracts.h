#import <Foundation/Foundation.h>

@protocol RCObjectIDFactory
+ (id)objectIDWithUUID:(NSUUID *)uuid;
@end

@protocol RCNativeStore
- (id)fetchReminderWithObjectID:(id)objectID error:(NSError **)error;
@end

@protocol RCNativeReminder
- (id)flaggedContext;
- (id)hashtagContext;
@end

@protocol RCFlagContext
- (NSInteger)flagged;
- (void)setFlagged:(NSInteger)flagged;
@end

@protocol RCHashtag
- (NSString *)name;
@end

@protocol RCHashtagContext
- (NSArray<id<RCHashtag>> *)hashtags;
- (NSString *)nameWithDisallowedCharactersReplaced:(NSString *)name;
- (id)addHashtagWithType:(NSInteger)type name:(NSString *)name;
- (void)removeHashtag:(id)hashtag;
@end

@protocol RCNativeSaveRequest
- (id)initWithStore:(id)store;
- (id<RCNativeReminder>)updateReminder:(id)reminder;
- (BOOL)saveSynchronouslyWithError:(NSError **)error;
@end
