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

@implementation RCReminderAttachmentStore
+ (NSArray<RCReminderAttachment *> *)readAttachments:(NSString *)identifier
                                              error:(NSError **)error {
  @try {
    id<RCAttachmentReminder> reminder = RCReminder(RCStore(), identifier, error);
    if (!reminder) return nil;
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
    Class imageClass = NSClassFromString(@"REMImageAttachment");
    RCRequire(fileClass, @[@"class"]);
    RCRequire(imageClass, @[@"class"]);
    NSMutableArray *result = [NSMutableArray array];
    for (id item in attachments) {
      if ([item isKindOfClass:fileClass]) {
        [result addObject:RCAttachmentSnapshot(item)];
      }
    }
    return [result copy];
  } @catch (NSException *exception) {
    RCSetError(error, [NSString stringWithFormat:@"%@: %@", exception.name,
                       exception.reason], nil);
    return nil;
  }
}
@end
