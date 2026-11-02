#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCReminderMetadata : NSObject
@property(nonatomic, readonly) BOOL flagged;
@property(nonatomic, copy, readonly) NSArray<NSString *> *tags;
@end

@interface RCReminderMetadataStore : NSObject
+ (nullable RCReminderMetadata *)readReminder:(NSString *)identifier
                                       error:(NSError **)error;
+ (nullable RCReminderMetadata *)updateReminder:(NSString *)identifier
                                       flagged:(nullable NSNumber *)flagged
                                       addTags:(NSArray<NSString *> *)addTags
                                    removeTags:(NSArray<NSString *> *)removeTags
                                     renameTag:(nullable NSString *)renameTag
                                         toTag:(nullable NSString *)toTag
                                         error:(NSError **)error;
@end

@interface RCReminderAttachment : NSObject
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *kind;
@property(nonatomic, copy, readonly) NSString *contentType;
@property(nonatomic, readonly) unsigned long long byteCount;
@property(nonatomic, copy, readonly, nullable) NSURL *fileURL;
@end

@interface RCReminderAttachmentStore : NSObject
+ (nullable NSArray<RCReminderAttachment *> *)readAttachments:(NSString *)identifier
                                                      error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
