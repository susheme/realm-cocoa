////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

#import "RLMResults.h"
#import "RLMSyncUser.h"

NS_ASSUME_NONNULL_BEGIN

@class RLMSyncPermissionValue;

/**
 A property on which a `RLMSyncPermissionResults` can be queried or filtered.

 @warning If building `NSPredicate`s using format strings including these
          string constants, use %K instead of %@ as the substitution parameter.
 */
typedef NSString * RLMSyncPermissionSortProperty NS_STRING_ENUM;

/// Sort by the Realm Object Server path to the Realm to which the permission applies.
extern RLMSyncPermissionSortProperty const RLMSyncPermissionSortPropertyPath;
/// Sort by the identity of the user to whom the permission applies.
extern RLMSyncPermissionSortProperty const RLMSyncPermissionSortPropertyUserID;
/// Sort by the date the permissions were last updated.
extern RLMSyncPermissionSortProperty const RLMSyncPermissionSortPropertyUpdated;

/**
 A collection object representing the results of a permissions query.

 This collection will automatically update its contents at the start of each runloop
 iteration, but the objects it vends are immutable.

 Permission results objects are thread-confined, and should not be shared across
 threads.

 @warning Permission results must only be fetched on threads that have an active
          run loop. In most cases this will be the main thread.
 */
@interface RLMSyncPermissionResults : RLMResults<RLMSyncPermissionValue *>

// Refine a number of method signatures to provide a more specific return result.

/// :nodoc:
- (RLMSyncPermissionResults *)objectsWithPredicate:(NSPredicate *)predicate;
/// :nodoc:
- (RLMSyncPermissionResults *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending;
/// :nodoc:
- (RLMSyncPermissionResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties;
/// :nodoc:
- (RLMNotificationToken *)addNotificationBlock:(void(^)(RLMSyncPermissionResults *,
                                                        RLMCollectionChange *,
                                                        NSError *))block;

/// :nodoc:
- (id)valueForKey:(NSString *)key
__attribute__((unavailable("valueForKey: is not supported for RLMSyncPermissionResults")));

/// :nodoc:
- (void)setValue:(nullable id)value forKey:(NSString *)key
__attribute__((unavailable("setValue:forKey: is not supported for RLMSyncPermissionResults")));

@end

NS_ASSUME_NONNULL_END
