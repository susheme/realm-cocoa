////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

import XCTest
import RealmSwift

class SwiftSyncObject: Object {
    @objc dynamic var stringProp: String = ""
}

class SwiftHugeSyncObject: Object {
    @objc dynamic var dataProp: NSData?

    required init() {
        super.init()
        let size = 1000000
        let ptr = malloc(size)
        dataProp = NSData(bytes: ptr, length: size)
        free(ptr)
    }

    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        fatalError("init(realm:schema:) has not been implemented")
    }
    required init(value: Any, schema: RLMSchema) {
        fatalError("init(value:schema:) has not been implemented")
    }
}

// MARK: Test case

class SwiftSyncTestCase: RLMSyncTestCase {

    var task: Process?

    let authURL: URL = URL(string: "http://127.0.0.1:9080")!
    let realmURL: URL = URL(string: "realm://localhost:9080/~/testBasicSync")!

    /// For testing, make a unique Realm URL of the form "realm://localhost:9080/~/X",
    /// where X is either a custom string passed as an argument, or an UUID string.
    static func uniqueRealmURL(customName: String? = nil) -> URL {
        return URL(string: "realm://localhost:9080/~/\(customName ?? UUID().uuidString)")!
    }

    func executeChild(file: StaticString = #file, line: UInt = #line) {
        XCTAssert(0 == runChildAndWait(), "Tests in child process failed", file: file, line: line)
    }

    func basicCredentials(register: Bool, usernameSuffix: String = "", file: StaticString = #file, line: UInt = #line) -> SyncCredentials {
        return .usernamePassword(username: "\(file)\(line)\(usernameSuffix)", password: "a", register: register)
    }

    func synchronouslyOpenRealm(url: URL, user: SyncUser, file: StaticString = #file, line: UInt = #line) throws -> Realm {
        let semaphore = DispatchSemaphore(value: 0)
        let basicBlock = { (error: Error?) in
            if let error = error {
                let process = self.isParent ? "parent" : "child"
                XCTFail("Received an asynchronous error: \(error) (process: \(process))", file: file, line: line)
            }
            semaphore.signal()
        }
        SyncManager.shared.setSessionCompletionNotifier(basicBlock)
        let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: url))
        let realm = try Realm(configuration: config)
        // FIXME: Perhaps we should have a reasonable timeout here, instead of allowing bad code to stall forever.
        _ = semaphore.wait(timeout: .distantFuture)
        return realm
    }

    func immediatelyOpenRealm(url: URL, user: SyncUser) throws -> Realm {
        return try Realm(configuration: Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: url)))
    }

    func synchronouslyLogInUser(for credentials: SyncCredentials,
                                server url: URL,
                                file: StaticString = #file,
                                line: UInt = #line) throws -> SyncUser {
        let process = isParent ? "parent" : "child"
        var theUser: SyncUser? = nil
        let ex = expectation(description: "Should log in the user properly")
        SyncUser.logIn(with: credentials, server: url) { user, error in
            XCTAssertNotNil(user, file: file, line: line)
            XCTAssertNil(error,
                         "Error when trying to log in a user: \(error!) (process: \(process))",
                         file: file,
                         line: line)
            theUser = user
            ex.fulfill()
        }
        waitForExpectations(timeout: 4, handler: nil)
        XCTAssertNotNil(theUser, file: file, line: line)
        XCTAssertEqual(theUser!.state, .active,
                      "User should have been valid, but wasn't. (process: \(process))",
                      file: file,
                      line: line)
        return theUser!
    }

    func checkCount<T: Object>(expected: Int,
                               _ realm: Realm,
                               _ type: T.Type,
                               file: StaticString = #file,
                               line: UInt = #line) {
        let actual = realm.objects(type).count
        XCTAssert(actual == expected,
                  "Error: expected \(expected) items, but got \(actual) (process: \(isParent ? "parent" : "child"))",
                  file: file,
                  line: line)
    }
}
