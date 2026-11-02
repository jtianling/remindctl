#import "ReminderKitBridge.h"
#import "ReminderKitAccess.h"
#import <dlfcn.h>

void RCRequire(id object, NSArray<NSString *> *selectors) {
  for (NSString *name in selectors) {
    if (!object || ![object respondsToSelector:NSSelectorFromString(name)]) {
      @throw [NSException exceptionWithName:@"ReminderKitUnavailable"
                                    reason:[@"Missing ReminderKit interface: "
                                               stringByAppendingString:name]
                                  userInfo:nil];
    }
  }
}

void RCSetError(NSError **error, NSString *message, NSError *underlying) {
  if (!error) return;
  NSMutableDictionary *info = [@{NSLocalizedDescriptionKey: message} mutableCopy];
  if (underlying) info[NSUnderlyingErrorKey] = underlying;
  *error = [NSError errorWithDomain:@"remindctl.ReminderKit" code:1 userInfo:info];
}

id RCStore(void) {
  static void *framework;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    framework = dlopen(
        "/System/Library/PrivateFrameworks/ReminderKit.framework/ReminderKit",
        RTLD_NOW | RTLD_LOCAL);
  });
  if (!framework) {
    @throw [NSException exceptionWithName:@"ReminderKitUnavailable"
                                  reason:@"Unable to load system ReminderKit framework"
                                userInfo:nil];
  }
  Class storeClass = NSClassFromString(@"REMStore");
  RCRequire(storeClass, @[@"new"]);
  id store = [storeClass new];
  RCRequire(store, @[@"fetchReminderWithObjectID:error:"]);
  return store;
}

id RCReminder(id<RCNativeStore> store, NSString *identifier, NSError **error) {
  NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
  if (!uuid) {
    RCSetError(error, @"Native metadata requires a UUID reminder identifier", nil);
    return nil;
  }
  Class<RCObjectIDFactory> factory = NSClassFromString(@"REMReminder");
  RCRequire(factory, @[@"objectIDWithUUID:"]);
  NSError *failure = nil;
  id reminder = [store fetchReminderWithObjectID:[factory objectIDWithUUID:uuid]
                                         error:&failure];
  if (!reminder) {
    NSString *detail = failure.description ?: @"Reminder not found";
    RCSetError(error, [@"Unable to read native reminder metadata: "
                         stringByAppendingString:detail], failure);
  }
  return reminder;
}

@interface RCReminderMetadata ()
@property(nonatomic, readwrite) BOOL flagged;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *tags;
@end

@implementation RCReminderMetadata
@end

static NSArray<id<RCHashtag>> *RCTags(id<RCHashtagContext> context) {
  RCRequire(context, @[@"hashtags"]);
  id tags = [context hashtags];
  if ([tags isKindOfClass:NSSet.class] || [tags isKindOfClass:NSOrderedSet.class]) {
    tags = [tags allObjects];
  }
  if (![tags isKindOfClass:NSArray.class]) {
    @throw [NSException exceptionWithName:@"ReminderKitSchemaError"
                                  reason:@"Invalid native hashtag collection"
                                userInfo:nil];
  }
  for (id<RCHashtag> tag in tags) {
    RCRequire(tag, @[@"name"]);
    if (![[tag name] isKindOfClass:NSString.class]) {
      @throw [NSException exceptionWithName:@"ReminderKitSchemaError"
                                    reason:@"Invalid native hashtag name"
                                  userInfo:nil];
    }
  }
  return tags;
}

static RCReminderMetadata *RCSnapshot(id<RCNativeReminder> reminder) {
  RCRequire(reminder, @[@"flaggedContext", @"hashtagContext"]);
  id<RCFlagContext> flag = [reminder flaggedContext];
  RCRequire(flag, @[@"flagged"]);
  RCReminderMetadata *result = [RCReminderMetadata new];
  result.flagged = [flag flagged] != 0;
  NSMutableArray<NSString *> *names = [NSMutableArray array];
  for (id<RCHashtag> tag in RCTags([reminder hashtagContext])) {
    [names addObject:[tag name]];
  }
  result.tags = [names sortedArrayUsingSelector:@selector(compare:)];
  return result;
}

static id<RCHashtag> RCFindTag(NSArray<id<RCHashtag>> *tags, NSString *name) {
  for (id<RCHashtag> tag in tags) {
    if ([[tag name] caseInsensitiveCompare:name] == NSOrderedSame) return tag;
  }
  return nil;
}

static void RCValidateTag(id<RCHashtagContext> context, NSString *name) {
  NSString *normalized = [context nameWithDisallowedCharactersReplaced:name];
  if (![name isEqualToString:normalized]) {
    @throw [NSException exceptionWithName:@"InvalidTag"
                                  reason:[@"Invalid native tag name: "
                                             stringByAppendingString:name]
                                userInfo:nil];
  }
}

static void RCEditTags(id<RCHashtagContext> context, NSArray<NSString *> *add,
                       NSArray<NSString *> *remove, NSString *oldName,
                       NSString *newName) {
  RCRequire(context, @[@"hashtags", @"addHashtagWithType:name:",
                       @"removeHashtag:", @"nameWithDisallowedCharactersReplaced:"]);
  NSArray<id<RCHashtag>> *original = RCTags(context);
  for (NSString *name in add) RCValidateTag(context, name);
  if (newName) RCValidateTag(context, newName);
  id<RCHashtag> renamed = oldName ? RCFindTag(original, oldName) : nil;
  if (oldName && !renamed) {
    @throw [NSException exceptionWithName:@"TagNotFound"
                                  reason:[@"Tag not found on reminder: "
                                             stringByAppendingString:oldName]
                                userInfo:nil];
  }
  for (NSString *name in remove) {
    id tag = RCFindTag(RCTags(context), name);
    if (tag) [context removeHashtag:tag];
  }
  if (renamed) [context removeHashtag:renamed];
  NSArray<NSString *> *names = newName ? [add arrayByAddingObject:newName] : add;
  for (NSString *name in names) {
    if (!RCFindTag(RCTags(context), name)) {
      [context addHashtagWithType:0 name:name];
    }
  }
}

@implementation RCReminderMetadataStore
+ (RCReminderMetadata *)readReminder:(NSString *)identifier error:(NSError **)error {
  @try {
    id reminder = RCReminder(RCStore(), identifier, error);
    return reminder ? RCSnapshot(reminder) : nil;
  } @catch (NSException *exception) {
    RCSetError(error, [NSString stringWithFormat:@"%@: %@", exception.name,
                       exception.reason], nil);
    return nil;
  }
}

+ (RCReminderMetadata *)updateReminder:(NSString *)identifier
                               flagged:(NSNumber *)flagged
                               addTags:(NSArray<NSString *> *)addTags
                            removeTags:(NSArray<NSString *> *)removeTags
                             renameTag:(NSString *)renameTag
                                 toTag:(NSString *)toTag
                                 error:(NSError **)error {
  BOOL didSave = NO;
  @try {
    id store = RCStore();
    id reminder = RCReminder(store, identifier, error);
    if (!reminder) return nil;
    Class requestClass = NSClassFromString(@"REMSaveRequest");
    RCRequire(requestClass, @[@"alloc"]);
    RCRequire([requestClass alloc], @[@"initWithStore:"]);
    id<RCNativeSaveRequest> request = [(id<RCNativeSaveRequest>)[requestClass alloc]
                                     initWithStore:store];
    RCRequire(request, @[@"updateReminder:", @"saveSynchronouslyWithError:"]);
    id<RCNativeReminder> change = [request updateReminder:reminder];
    RCRequire(change, @[@"flaggedContext", @"hashtagContext"]);
    if (flagged) {
      id<RCFlagContext> context = [change flaggedContext];
      RCRequire(context, @[@"setFlagged:"]);
      [context setFlagged:flagged.boolValue ? 1 : 0];
    }
    if (addTags.count || removeTags.count || renameTag) {
      RCEditTags([change hashtagContext], addTags, removeTags, renameTag, toTag);
    }
    RCSnapshot(change);
    NSError *failure = nil;
    if (![request saveSynchronouslyWithError:&failure]) {
      NSString *detail = failure.description ?: @"No error details returned";
      RCSetError(error, [@"Unable to save native reminder metadata: "
                           stringByAppendingString:detail], failure);
      return nil;
    }
    didSave = YES;
    NSError *verificationError = nil;
    id saved = RCReminder(RCStore(), identifier, &verificationError);
    if (!saved) {
      RCSetError(error, [NSString stringWithFormat:
          @"Native metadata was saved, but verification failed: %@. "
           "Inspect info --native before retrying a tag rename.",
          verificationError.localizedDescription], verificationError);
      return nil;
    }
    return RCSnapshot(saved);
  } @catch (NSException *exception) {
    NSString *prefix = didSave
        ? @"Native metadata was saved, but verification failed. "
           "Inspect info --native before retrying a tag rename. "
        : @"";
    RCSetError(error, [NSString stringWithFormat:@"%@%@: %@", prefix,
                       exception.name, exception.reason], nil);
    return nil;
  }
}
@end
