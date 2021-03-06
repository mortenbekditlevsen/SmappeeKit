//
//  FutureFunctionalTests.swift
//  Future
//
//  Created by Le VanNghia on 6/1/15.
//  Copyright (c) 2015 Le VanNghia. All rights reserved.
//


import UIKit
import XCTest
import Result
import Future

class FutureFunctionalTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
}

extension FutureFunctionalTests {
    func testMap() {
        let f = requestString("12345") <^> { $0.characters.count }
        checkFutureShouldNotBeCompleted(f)
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, 5, "Future should return 5")
            case .Failure: XCTAssertFalse(true, "Future should not be failed")
            }
        }
        
        let f2 = f <^> { "\($0)" }
        checkFutureShouldNotBeCompleted(f2)
        f2.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, "5", "Future should return 5 as a String")
            case .Failure: XCTAssertFalse(true, "Future should not be failed")
            }
        }
    }
    
    func testFlatMap() {
        let f = requestString("12345")
            .flatMap(requestStringLength)
        
        checkFutureShouldNotBeCompleted(f)
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, 5, "Future should return 5")
            case .Failure: XCTAssertFalse(true, "Future should not be failed")
            }
        }
    }
    
    func testFlatMapAndMap() {
        let f = requestString("12345")
            .map { $0.characters.count }
            .flatMap(requestStringFromNumber)
        
        checkFutureShouldNotBeCompleted(f)
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, "5", "Future should return 5 as a String")
            case .Failure: XCTAssertFalse(true, "Future should not be failed")
            }
        }
    }
    
    func testMapFlatMapOperators() {
        let f = requestString("12345") <^> { $0.characters.count } >>- requestStringFromNumber
        
        checkFutureShouldNotBeCompleted(f)
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, "5", "Future should return 5 as a String")
            case .Failure: XCTAssertFalse(true, "Future should not be failed")
            }
        }
    }
    
    func testFlatMapMapOperators() {
        let f = (requestString("12345") >>- requestStringLength) <^> { "\($0)" }
        checkFutureShouldNotBeCompleted(f)
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, "5", "Future should return 5 as a String")
            case .Failure: XCTAssertFalse(true, "Future should not be failed")
            }
        }
    }
    
    func testFilter() {
        let noSuchElementError = NSError(domain: "noSuchElement", code: 1, userInfo: nil)
        
        let f = requestString("12345")
            .filter(noSuchElementError) { $0.characters.count > 2 }
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, "12345", "Future should return 12345 as a String")
            case .Failure: XCTAssertFalse(true, "Future should not be failed")
            }
        }
    }
    
    func testFilterWhenPredicateIsSatisfied() {
        let noSuchElementError = NSError(domain: "noSuchElement", code: 1, userInfo: nil)
        
        let f = requestString("12345")
            .filter(noSuchElementError) { $0.characters.count > 5 }
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertNil(bv, "Future should return nil")
            case .Failure(let be): XCTAssertEqual(be, noSuchElementError, "Future should return noSuchElement error")
            }
        }
    }
    
    func testAndThen() {
        var sideeffect = 0
        
        let f = requestString("12345")
            .andThen { result in sideeffect = (result.value?.characters.count)! }
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, "12345", "Future should return 12345 as a String")
            case .Failure: XCTAssertFalse(true, "Future should not return an error")
            }
            XCTAssertEqual(sideeffect, 5, "SideEffect value should equal to 5")
        }
    }
    
    func testAndThenCombineWithFlatMap() {
        var sideeffect = 0
        let f = requestString("12345")
            .andThen { result in sideeffect = (result.value?.characters.count)! }
            .flatMap(requestStringLength)
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, 5, "Future should return 5")
            case .Failure: XCTAssertFalse(true, "Future should not return an error")
            }
            XCTAssertEqual(sideeffect, 5, "SideEffect value should equal to 5")
        }
    }
    
    func testRecover() {
        let f = requestStringReturnError("error message")
            .recover { _ in "OK" }
        
        f.onComplete { result in
            switch result {
            case .Success(let bv): XCTAssertEqual(bv, "OK", "Future should return OK")
            case .Failure: XCTAssertFalse(true, "Future should not return an error")
            }
        }
    }
    
    func testZip() {
        let f1 = requestString("12345")
        let f2 = requestStringFromNumber(1)
        
        let f = f1.zip(f2)
        f.onComplete { result in
            switch result {
            case .Success(let bv):
                XCTAssertEqual(bv.0, "12345", "Future should return tupple of 12345, 1")
                XCTAssertEqual(bv.1, "1", "Future should return tupple of 12345, 1")
            case .Failure: XCTAssertFalse(true, "Future should not return an error")
            }
        }
    }
}