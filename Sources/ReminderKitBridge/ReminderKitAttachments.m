#import "ReminderKitBridge.h"
#import "ReminderKitAccess.h"

@protocol RCAttachmentReminder
- (id)attachmentContext;
@end

@protocol RCAttachmentContext
- (id)attachments;
@end

@protocol RCAttachmentID
- (NSUUID *)uuid;
@end

@protocol RCFileAttachment
- (id)objectID;
- (NSString *)uti;
- (unsigned long long)fileSize;
- (NSURL *)fileURL;
@end

@interface RCReminderAttachment ()
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *kind;
@property(nonatomic, copy, readwrite) NSString *contentType;
@property(nonatomic, readwrite) unsigned long long byteCount;
@property(nonatomic, copy, readwrite, nullable) NSURL *fileURL;
@end

@implementation RCReminderAttachment
@end

static RCReminderAttachment *RCAttachmentSnapshot(id<RCFileAttachment> item) {
  RCRequire(item, @[@"objectID", @"uti", @"fileSize", @"fileURL"]);
  id<RCAttachmentID> objectID = [item objectID];
  RCRequire(objectID, @[@"uuid"]);
  NSUUID *uuid = [objectID uuid];
  NSString *uti = [item uti];
  NSURL *url = [item fileURL];
  if (![uuid isKindOfClass:NSUUID.class] ||
      ![uti isKindOfClass:NSString.class] || !uti.length ||
      (url && (![url isKindOfClass:NSURL.class] || !url.isFileURL))) {
    @throw [NSException exceptionWithName:@"ReminderKitSchemaError"
                                  reason:@"Invalid native attachment metadata"
                                userInfo:nil];
  }
  RCReminderAttachment *result = [RCReminderAttachment new];
  result.identifier = uuid.UUIDString;
  result.contentType = uti;
  result.kind = [(id)item isKindOfClass:NSClassFromString(@"REMImageAttachment")]
      ? @"image" : @"file";
  result.byteCount = [item fileSize];
  result.fileURL = url;
  return result;
}

static NSArray *RCFileAttachments(id<RCAttachmentReminder> reminder) {
  RCRequire(reminder, @[@"attachmentContext"]);
  id<RCAttachmentContext> context = [reminder attachmentContext];
  RCRequire(context, @[@"attachments"]);
  id attachments = [context attachments];
  if ([attachments isKindOfClass:NSSet.class]) {
    attachments = [attachments allObjects];
  } else if ([attachments isKindOfClass:NSOrderedSet.class]) {
    attachments = [attachments array];
  }
  if (![attachments isKindOfClass:NSArray.class]) {
    @throw [NSException exceptionWithName:@"ReminderKitSchemaError"
                                  reason:@"Invalid native attachment collection"
                                userInfo:nil];
  }
  Class fileClass = NSClassFromString(@"REMFileAttachment");
  RCRequire(fileClass, @[@"class"]);
  NSMutableArray *files = [NSMutableArray array];
  for (id item in attachments) {
    if ([item isKindOfClass:fileClass]) [files addObject:item];
  }
  return [files copy];
}

@implementation RCReminderAttachmentStore
+ (NSArray<RCReminderAttachment *> *)readAttachments:(NSString *)identifier
                                              error:(NSError **)error {
  @try {
    id<RCAttachmentReminder> reminder = RCReminder(RCStore(), identifier, error);
    if (!reminder) return nil;
    Class imageClass = NSClassFromString(@"REMImageAttachment");
    RCRequire(imageClass, @[@"class"]);
    NSMutableArray *result = [NSMutableArray array];
    for (id item in RCFileAttachments(reminder)) {
      [result addObject:RCAttachmentSnapshot(item)];
    }
    return [result copy];
  } @catch (NSException *exception) {
    RCSetError(error, [NSString stringWithFormat:@"%@: %@", exception.name,
                       exception.reason], nil);
    return nil;
  }
}
@end

@interface RCReminderAttachmentSummary ()
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite, nullable) NSNumber *count;
@property(nonatomic, copy, readwrite, nullable) NSString *failure;
@end

@implementation RCReminderAttachmentSummary
@end

static RCReminderAttachmentSummary *RCAttachmentSummary(
    id store, NSString *identifier) {
  RCReminderAttachmentSummary *result = [RCReminderAttachmentSummary new];
  result.identifier = identifier;
  @try {
    NSError *error = nil;
    id reminder = RCReminder(store, identifier, &error);
    if (reminder) {
      result.count = @(RCFileAttachments(reminder).count);
    } else {
      result.failure = error.localizedDescription ?: @"Native reminder unavailable";
    }
  } @catch (NSException *exception) {
    result.failure = [NSString stringWithFormat:@"%@: %@", exception.name,
                      exception.reason];
  }
  return result;
}

@implementation RCReminderAttachmentDiscovery
+ (NSArray<RCReminderAttachmentSummary *> *)readSummaries:
    (NSArray<NSString *> *)identifiers error:(NSError **)error {
  @try {
    id store = RCStore();
    NSMutableArray *results = [NSMutableArray array];
    for (NSString *identifier in identifiers) {
      [results addObject:RCAttachmentSummary(store, identifier)];
    }
    return [results copy];
  } @catch (NSException *exception) {
    RCSetError(error, [NSString stringWithFormat:@"%@: %@", exception.name,
                       exception.reason], nil);
    return nil;
  }
}
@end
