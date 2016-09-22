//
//  ReactiveDataStackTests.swift
//  ReactiveDataStackTests
//
//  Created by Justin Makaila on 5/4/16.
//  Copyright © 2016 Wellth. All rights reserved.
//

import XCTest

@testable import ReactiveDataStack
import ReactiveSwift

class ReactiveDataStackTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext
            .producer
            .performBlock { context in
                return context
            }
            .save()
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
