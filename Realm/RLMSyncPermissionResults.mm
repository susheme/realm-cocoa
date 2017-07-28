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

#import "RLMSyncPermissionResults.h"

#import "RLMCollection_Private.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMQueryUtil.hpp"
#import "RLMResults_Private.hpp"
#import "RLMSchema_Private.hpp"
#import "RLMSyncPermissionValue_Private.hpp"
#import "RLMSyncUtil_Private.hpp"
#import "RLMUtil.hpp"

using namespace realm;

namespace {

NSError *translate_permission_exception_to_error(std::exception_ptr ptr, bool get) {
    NSError *error = nil;
    try {
        std::rethrow_exception(ptr);
    } catch (PermissionChangeException const& ex) {
        error = (get
                 ? make_permission_error_get(@(ex.what()), ex.code)
                 : make_permission_error_change(@(ex.what()), ex.code));
    }
    catch (const std::exception &exp) {
        RLMSetErrorOrThrow(RLMMakeError(RLMErrorFail, exp), &error);
    }
    return error;
}

bool keypath_is_valid(NSString *keypath)
{
    static NSSet<NSString *> *valid = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        valid = [NSSet setWithArray:@[RLMSyncPermissionSortPropertyPath,
                                      RLMSyncPermissionSortPropertyUserID,
                                      RLMSyncPermissionSortPropertyUpdated]];
    });
    return [valid containsObject:keypath];
}

}

/// Sort by the Realm Object Server path to the Realm to which the permission applies.
RLMSyncPermissionSortProperty const RLMSyncPermissionSortPropertyPath       = @"path";
/// Sort by the identity of the user to whom the permission applies.
RLMSyncPermissionSortProperty const RLMSyncPermissionSortPropertyUserID     = @"userId";
/// Sort by the date the permissions were last updated.
RLMSyncPermissionSortProperty const RLMSyncPermissionSortPropertyUpdated    = @"updatedAt";

@interface RLMSyncPermissionResults ()
@property (nonatomic, strong) RLMSchema *schema;
@property (nonatomic, strong) RLMObjectSchema *objectSchema;
@end

@implementation RLMSyncPermissionResults

#pragma mark - Public API

- (RLMPropertyType)type {
    return RLMPropertyTypeObject;
}

- (NSString *)objectClassName {
    return NSStringFromClass([RLMSyncPermissionValue class]);
}

- (RLMRealm *)realm {
    return nil;
}

- (RLMSyncPermissionValue *)objectAtIndex:(NSUInteger)index {
    return translateErrors([&] {
        return [[RLMSyncPermissionValue alloc] initWithPermission:Permission(_results, index)];
    });
}

- (RLMSyncPermissionValue *)firstObject {
    return self.count == 0 ? nil : [self objectAtIndex:0];
}

- (RLMSyncPermissionValue *)lastObject {
    return self.count == 0 ? nil : [self objectAtIndex:(self.count - 1)];
}

- (NSUInteger)indexOfObject:(RLMSyncPermissionValue *)object {
    // FIXME: Replace this stupid implementation with a custom predicate.
    // NOTE: Be aware: isEqual: does some weird stuff with paths.
    for (NSUInteger i=0; i<self.count; i++) {
        if ([[self objectAtIndex:i] isEqual:object]) {
            return i;
        }
    }
    return NSNotFound;
}

- (NSUInteger)indexOfObjectWithPredicate:(NSPredicate *)predicate {
    return translateErrors([&] {
        auto& group = _results.get_realm()->read_group();
        auto query = RLMPredicateToQuery(predicate, self.objectSchema, self.schema, group);
        return RLMConvertNotFound(_results.index_of(std::move(query)));
    });
}

- (RLMSyncPermissionResults *)objectsWithPredicate:(NSPredicate *)predicate {
    return translateErrors([&] {
        auto query = RLMPredicateToQuery(predicate, self.objectSchema, self.schema, _results.get_realm()->read_group());
        return [[RLMSyncPermissionResults alloc] initWithResults:_results.filter(std::move(query))];
    });
}

- (RLMSyncPermissionResults *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending {
    return [self sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:keyPath
                                                                                    ascending:ascending]]];
}

- (RLMSyncPermissionResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    if (properties.count == 0) {
        return self;
    }
    for (RLMSortDescriptor *descriptor in properties) {
        if (!keypath_is_valid(descriptor.keyPath)) {
            @throw RLMException(@"Invalid keypath specified. Use one of the constants defined in "
                                @" `RLMSyncPermissionSortProperty`.");
        }
    }
    return translateErrors([&] {
        auto sorted = _results.sort(RLMSortDescriptorsToKeypathArray(properties));
        return [[RLMSyncPermissionResults alloc] initWithResults:std::move(sorted)];
    });
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (RLMNotificationToken *)addNotificationBlock:(void(^)(RLMSyncPermissionResults *results,
                                                        RLMCollectionChange *change,
                                                        NSError *error))block {
    auto cb = [=](const realm::CollectionChangeSet& changes, std::exception_ptr ptr) {
        if (ptr) {
            NSError *error = translate_permission_exception_to_error(std::move(ptr), true);
            REALM_ASSERT(error);
            block(nil, nil, error);
        } else {
            // Finished successfully
            block(self, [[RLMCollectionChange alloc] initWithChanges:changes], nil);
        }
    };
    return [[RLMCancellationToken alloc] initWithToken:_results.add_notification_callback(std::move(cb)) realm:nil];
}
#pragma clang diagnostic pop

- (id)aggregate:(__unused NSString *)property
         method:(__unused util::Optional<Mixed> (Results::*)(size_t))method
     methodName:(__unused NSString *)methodName returnNilForEmpty:(__unused BOOL)returnNilForEmpty {
    // We don't support any of the min/max/average/sum APIs; they don't make sense for this collection type.
    return nil;
}

- (id)valueForKey:(__unused NSString *)key {
    @throw RLMException(@"valueForKey: is not supported for RLMSyncPermissionResults");
}

- (void)setValue:(__unused id)value forKey:(__unused NSString *)key {
    @throw RLMException(@"setValue:forKey: is not supported for RLMSyncPermissionResults");
}

#pragma mark - System

- (RLMSchema *)schema {
    if (!_schema) {
        _schema = [RLMSchema dynamicSchemaFromObjectStoreSchema:_results.get_realm()->schema()];
    }
    return _schema;
}

- (RLMObjectSchema *)objectSchema {
    if (!_objectSchema) {
        _objectSchema = [RLMObjectSchema objectSchemaForObjectStoreSchema:_results.get_object_schema()];
    }
    return _objectSchema;
}

- (NSString *)description {
    return RLMDescriptionWithMaxDepth(@"RLMSyncPermissionResults", self, 1);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])buffer
                                    count:(NSUInteger)len {
    // FIXME: It would be nice to have a shared fast enumeration implementation for `realm::Results`-only RLMResults.
    NSUInteger thisSize = self.count;
    if (state->state == 0) {
        state->extra[0] = 0;
        state->extra[1] = (long)thisSize;
        state->state = 1;
    }
    NSUInteger objectsInBuffer = 0;
    long idx = state->extra[0];
    if ((unsigned long)idx == thisSize) {
        // finished
        return 0;
    }
    state->itemsPtr = buffer;
    state->mutationsPtr = state->extra + 1;
    while (true) {
        if (objectsInBuffer == len) {
            // Buffer is full.
            state->extra[0] = idx;
            return objectsInBuffer;
        }
        if ((unsigned long)idx == thisSize) {
            // finished
            state->extra[0] = idx;
            return objectsInBuffer;
        }
        // Otherwise, add an object and advance the index pointer.
        RLMSyncPermissionValue * __autoreleasing thisPermission = [self objectAtIndex:idx];
        buffer[objectsInBuffer] = thisPermission;
        idx++;
        objectsInBuffer++;
    }
}

@end
