#import "ReminderKitContracts.h"

void RCRequire(id object, NSArray<NSString *> *selectors);
void RCSetError(NSError **error, NSString *message, NSError *underlying);
id RCStore(void);
id RCReminder(id<RCNativeStore> store, NSString *identifier, NSError **error);
