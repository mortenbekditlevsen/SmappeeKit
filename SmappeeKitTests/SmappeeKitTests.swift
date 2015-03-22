//
//  SmappeeKitTests.swift
//  SmappeeKitTests
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit
import XCTest
import SwiftyJSON

class SmappeeKitTests: XCTestCase, SmappeeControllerLoginStateDelegate {
    
    var controller: SmappeeController! = nil
    var returnLoginError = false
    
    var serviceLocation: ServiceLocation!
    var appliances : [Appliance]!
    var maxNumber : Int!
    var from : NSDate!
    var to : NSDate!
    var aggregation : SmappeeAggregation!
    var actuator : Actuator!

    func configureAccessTokenResponse() {
        let endPoint = SmappeeRequest.tokenEndPoint
        let data = JSON(["access_token": "testToken", "refresh_token": "testRefreshToken"]).rawData()
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureAccessTokenUnexpectedJSONResponse() {
        let endPoint = SmappeeRequest.tokenEndPoint
        let data = JSON(["wrong_key": "testToken"]).rawData()
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureSingleInvalidJSONResponse() {
        let data = "invalidjson".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        NSURLConnectionMock.sharedInstance.overrideSingleResponse = (nil, data, nil)
    }
    
    func configureAccessTokenErrorResponse() {
        let endPoint = SmappeeRequest.tokenEndPoint
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, nil, NSError(domain: "ErrorDomain", code: 12345, userInfo: nil))
    }
    
    func configureServiceLocationResponse() {
        let endPoint = serviceLocationEndPoint
        let data = JSON(["serviceLocations": [
            ["serviceLocationId": 1, "name": "Home"],
            ["serviceLocationId": 2, "name": "Cottage"],
            ["serviceLocationId": 3, "name": "Shop"],
        ]]).rawData()

        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureServiceLocationUnexpectedJSONResponse() {
        let endPoint = serviceLocationEndPoint
        let data = JSON(["serviceLocations": [
            ["serviceLocationId": 1, "name": "Home"],
            ["serviceLocationId": 2, "name": "Cottage"],
            ["unexpected": 3],
        ]]).rawData()
        
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureServiceLocationInfoResponse() {
        let endPoint = serviceLocationInfoEndPoint(serviceLocation)
        let data = JSON(["serviceLocationId": 1,
            "name": "Home",
            "electricityCurrency": "DKK",
            "electricityCost": 2.25,
            "lon": 9.0,
            "lat": 52.1
            ]).rawData()
        
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureServiceLocationInfoUnexpectedJSONResponse() {
        let endPoint = serviceLocationInfoEndPoint(serviceLocation)
        let data = JSON(["serviceLocationId": 1,
            "name": "Home",
            "electricityCurrency": "DKK",
            "electricityCost": 2.25,
            "lon": 9.0,
            ]).rawData()
        
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }

    func configureServiceLocationErrorResponse() {
        let endPoint = serviceLocationEndPoint
        
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, nil, NSError(domain: "ErrorDomain", code: 12345, userInfo: nil))
    }
    
    func configureConsumptionEndPoint(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation) {
        let endPoint = consumptionEndPoint(serviceLocation, from, to, aggregation)
        let data = JSON(
            ["consumptions": [
                ["consumption": 10.0,
                    "alwaysOn": 5.0,
                    "timestamp": 1234.0,
                    "solar": 10.0],
                ["consumption": 10.0,
                    "alwaysOn": 5.0,
                    "timestamp": 1234.0,
                    "solar": 10.0],
                ["consumption": 10.0,
                    "alwaysOn": 5.0,
                    "timestamp": 1234.0,
                    "solar": 10.0]]]).rawData()
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureConsumptionEndPointUnexpectedJSON(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation) {
        let endPoint = consumptionEndPoint(serviceLocation, from, to, aggregation)
        let data = JSON(
            ["consumptions": [
                ["consumption": 10.0,
                    "alwaysOn": 5.0,
                    "timestamp": 1234.0,
                    "solar": 10.0],
                ["consumption": 10.0,
                    "alwaysOn": 5.0,
                    "timestamp": 1235.0,
                    "solar": 10.0],
                ["consumptionx": 10.0,
                    "alwaysOn": 5.0,
                    "timestamp": 1236.0,
                    "solar": 10.0]]]).rawData()
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureEventsEndPoint(serviceLocation: ServiceLocation, appliances: Array<Appliance>, maxNumber: Int, from: NSDate, to: NSDate) {
        let endPoint = eventsEndPoint(serviceLocation, appliances, maxNumber, from, to)
        let data = JSON([
            ["applianceId": 1,
                "activePower": 5.0,
                "timestamp": 1234.0],
            ["applianceId": 1,
                "activePower": 5.0,
                "timestamp": 1234.0],
            ["applianceId": 1,
                "activePower": 5.0,
                "timestamp": 1234.0],
            ]).rawData()
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }
    
    func configureEventsEndPointUnexpectedJSONResponse(serviceLocation: ServiceLocation, appliances: Array<Appliance>, maxNumber: Int, from: NSDate, to: NSDate) {
        let endPoint = eventsEndPoint(serviceLocation, appliances, maxNumber, from, to)
        let data = JSON([
            ["applianceId": 1,
                "activePower": 5.0,
                "timestamp": 1234.0],
            ["applianceId": 1,
                "activePower": 5.0,
                "timestamp": 1234.0],
            ["applianceId": 1,
                "activePower": 5.0,
                "timestampx": 1234.0],
            ]).rawData()
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }

    func configureActuatorEndPoint(actuator: Actuator, on: Bool) {
        let endPoint = actuatorEndPoint(actuator, on)
        let data = JSON([]).rawData()
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, data, nil)
    }

    
    func configureServiceLocationAccessTokenExpiredResponse() {
        let endPoint = serviceLocationEndPoint
        
        NSURLConnectionMock.sharedInstance.urlMapping[endPoint] = (nil, nil, NSError(domain: NSURLErrorDomain, code: -1012, userInfo: nil))
    }
    
    func configureSingleAccessTokenExpiredResponse() {
        NSURLConnectionMock.sharedInstance.overrideSingleResponse = (nil, nil, NSError(domain: NSURLErrorDomain, code: -1012, userInfo: nil))
    }

    
    func loginStateChangedFrom(loginState oldLoginState: SmappeeLoginState, toLoginState newLoginState: SmappeeLoginState) {
        // For debugging purposes
        println("\nChanged login state from: '\(oldLoginState)' to '\(newLoginState)'\n\n")
    }
    
    override func setUp() {
        super.setUp()
        
        serviceLocation = ServiceLocation(id: 1, name: "Home")
        appliances = [Appliance(serviceLocation: serviceLocation,
            id: 1, name: "Espresso Machine", type: "")]
        maxNumber = 10
        from = NSDate()
        to = NSDate()
        aggregation = .Daily
        actuator = Actuator(serviceLocation: serviceLocation, id: 1, name: "Outdoor lights")

        configureAccessTokenResponse()
        configureServiceLocationResponse()
        configureServiceLocationInfoResponse()
        
        controller = SmappeeController(clientId: "xxx", clientSecret: "yyy", loginState: .LoggedIn(accessToken: "dummyAccessToken", refreshToken: "dummyRefreshToken"))

        controller.loginStateDelegate = self
        returnLoginError = false
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // TODO: Test logout/login flow
    
    func testLoggedIn() {
        XCTAssert(controller.isLoggedIn(), "User should be logged in when tests start")
    }

    func testLogOut() {
        XCTAssert(controller.isLoggedIn(), "User should be logged in when tests start")
        controller.logOut()
        XCTAssert(!controller.isLoggedIn(), "User should be logged out")
    }
    
    func testLoginSuccess() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        controller.login("dummyUser", password: "dummyPassword") { r in
            XCTAssert(r.value != nil, "Expecting login success")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testAccessTokenUnexpectedJSONResponse() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureAccessTokenUnexpectedJSONResponse()
        controller.logOut()
        controller.login("dummyUser", password: "dummyPassword") { r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.UnexpectedDataError.rawValue, "Expecting UnexpectedDataError")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testAccessTokenInvalidJSONResponse() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureSingleInvalidJSONResponse()
        controller.logOut()
        controller.login("dummyUser", password: "dummyPassword") { r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.UnexpectedDataError.rawValue, "Expecting UnexpectedDataError")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testAccessTokenErrorResponse() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureAccessTokenErrorResponse()
        controller.logOut()
        controller.login("dummyUser", password: "dummyPassword") { r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.UnexpectedHTTPResponseError.rawValue, "Expecting UnexpectedHTTPResponseError")
            XCTAssert(r.error?.userInfo?[NSUnderlyingErrorKey] != nil, "Expecting an underlying error")
            if let underlyingError = r.error?.userInfo?[NSUnderlyingErrorKey] as? NSError {
                XCTAssert(underlyingError.code == 12345, "Expecting specific underlying error")
            }
            else {
                XCTFail("Underlying error is not of type NSError")
            }
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testReuseAccessToken() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        controller.sendServiceLocationRequest { r in
            XCTAssert(r.value != nil, "Expecting login success")
            
            self.controller.sendServiceLocationRequest { r in
                XCTAssert(r.value != nil, "Expecting a value")
                expectation.fulfill()
            }
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testReuseAccessTokenWithAccessTokenExpiredInfinitely() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        controller.sendServiceLocationRequest { r in
            XCTAssert(r.value != nil, "Expecting login success")
            
            self.configureServiceLocationAccessTokenExpiredResponse()
            self.controller.sendServiceLocationRequest { r in
                
                XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
                XCTAssert(r.error?.code == SmappeeError.InternalError.rawValue, "Expecting RequestStateMachineError")
                expectation.fulfill()
            }
            
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testReuseAccessTokenWithAccessTokenExpiredOnce() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        controller.sendServiceLocationRequest { r in
            XCTAssert(r.value != nil, "Expecting login success")
            
            self.configureSingleAccessTokenExpiredResponse()
            self.controller.sendServiceLocationRequest { r in
                XCTAssert(r.value != nil, "Expecting a value")
                expectation.fulfill()
            }
            
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testServiceLocationEndPoint() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        controller.sendServiceLocationRequest {
            r in
            XCTAssert(r.value != nil, "Expecting a ServiceLocation result")

            if let value = r.value {
                XCTAssert(value.count == 3, "Expecting three service locations to be returned")
                XCTAssert(value[2].name == "Shop", "Expecting third service location to be named 'Shop'")
                XCTAssert(value[1].id == 2, "Expecting second service location to have id '2'")
            }
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testServiceLocationEndPointUnexpectedJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureServiceLocationUnexpectedJSONResponse()
        
        controller.sendServiceLocationRequest {
            r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.JSONParseError.rawValue, "Expecting JSONParseError")
            XCTAssert(r.error?.localizedDescription == "Error parsing Service Locations JSON", "Expecting specific error description")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testServiceLocationEndPointInvalidJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        // Send a serviceLocationRequest to ensure that we are logged in first
        controller.sendServiceLocationRequest() { r in
            self.configureSingleInvalidJSONResponse()
            self.controller.sendServiceLocationRequest {
                r in
                XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
                XCTAssert(r.error?.code == SmappeeError.UnexpectedDataError.rawValue, "Expecting UnexpectedDataError")
                expectation.fulfill()
            }
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testServiceLocationEndPointErrorResponse () {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureServiceLocationErrorResponse()
        
        controller.sendServiceLocationRequest {
            r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.UnexpectedHTTPResponseError.rawValue, "Expecting UnexpectedHTTPResponseError")
            XCTAssert(r.error?.userInfo?[NSUnderlyingErrorKey] != nil, "Expecting an underlying error")
            if let underlyingError = r.error?.userInfo?[NSUnderlyingErrorKey] as? NSError {
                XCTAssert(underlyingError.code == 12345, "Expecting specific underlying error")
            }
            else {
                XCTFail("Underlying error is not of type NSError")
            }
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testServiceLocationInfoEndPoint() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        controller.sendServiceLocationInfoRequest(serviceLocation) { r in
            XCTAssert(r.value != nil, "Expecting a correct ServiceLocationInfo result")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testServiceLocationInfoEndPointUnexpectedJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureServiceLocationInfoUnexpectedJSONResponse()
        controller.sendServiceLocationInfoRequest(serviceLocation) { r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.JSONParseError.rawValue, "Expecting JSONParseError")
            XCTAssert(r.error?.localizedDescription == "Error parsing Service Location Info JSON", "Expecting specific error description")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testServiceLocationInfoEndPointInvalidJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        // Send a serviceLocationRequest to ensure that we are logged in first
        controller.sendServiceLocationRequest() { r in
            self.configureSingleInvalidJSONResponse()
            self.controller.sendServiceLocationInfoRequest(self.serviceLocation) { r in
                XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
                XCTAssert(r.error?.code == SmappeeError.UnexpectedDataError.rawValue, "Expecting UnexpectedDataError")
                expectation.fulfill()
            }
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testConsumptionEndPoint() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureConsumptionEndPoint(serviceLocation, from: from, to: to, aggregation: aggregation)
        controller.sendConsumptionRequest(serviceLocation, from: from, to: to, aggregation: aggregation) { r in
            XCTAssert(r.value != nil, "Expecting a correct Consumption result")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testConsumptionEndPointUnexpectedJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureConsumptionEndPointUnexpectedJSON(serviceLocation, from: from, to: to, aggregation: aggregation)
        controller.sendConsumptionRequest(serviceLocation, from: from, to: to, aggregation: aggregation) { r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.JSONParseError.rawValue, "Expecting JSONParseError")
            XCTAssert(r.error?.localizedDescription == "Error parsing Consumption JSON", "Expecting specific error description")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testConsumptionEndPointInvalidJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        // Send a serviceLocationRequest to ensure that we are logged in first
        controller.sendServiceLocationRequest() { r in
            self.configureSingleInvalidJSONResponse()
            self.controller.sendConsumptionRequest(self.serviceLocation, from: self.from, to: self.to, aggregation: self.aggregation) { r in
                XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
                XCTAssert(r.error?.code == SmappeeError.UnexpectedDataError.rawValue, "Expecting UnexpectedDataError")
                expectation.fulfill()
            }
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }


    func testEventsEndPoint() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureEventsEndPoint(serviceLocation, appliances: appliances, maxNumber: maxNumber, from: from, to: to)
        controller.sendEventsRequest(serviceLocation, appliances: appliances, maxNumber: maxNumber, from: from, to: to) { r in
            XCTAssert(r.value != nil, "Expecting a correct Events result")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testEventsEndPointUnexpectedJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureEventsEndPointUnexpectedJSONResponse(serviceLocation, appliances: appliances, maxNumber: maxNumber, from: from, to: to)
        controller.sendEventsRequest(serviceLocation, appliances: appliances, maxNumber: maxNumber, from: from, to: to) { r in
            XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
            XCTAssert(r.error?.code == SmappeeError.JSONParseError.rawValue, "Expecting JSONParseError")
            XCTAssert(r.error?.localizedDescription == "Error parsing Events JSON", "Expecting specific error description")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testEventsEndPointInvalidJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        // Send a serviceLocationRequest to ensure that we are logged in first
        controller.sendServiceLocationRequest() { r in
            self.configureSingleInvalidJSONResponse()
            self.controller.sendEventsRequest(self.serviceLocation, appliances: self.appliances, maxNumber: self.maxNumber, from: self.from, to: self.to) { r in
                XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
                XCTAssert(r.error?.code == SmappeeError.UnexpectedDataError.rawValue, "Expecting UnexpectedDataError")
                expectation.fulfill()
            }
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testActuatorEndPoint() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        configureActuatorEndPoint(actuator, on: true)
        controller.sendActuatorRequest(actuator, on: true, duration: .FiveMinutes) { r in
            XCTAssert(r.value != nil, "Expecting a valid actuator result")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }

    func testActuatorEndPointInvalidJSON() {
        let expectation = self.expectationWithDescription("Request completion expectation")
        // Send a serviceLocationRequest to ensure that we are logged in first
        controller.sendServiceLocationRequest() { r in
            self.configureSingleInvalidJSONResponse()
            self.controller.sendActuatorRequest(self.actuator, on: true, duration: .FiveMinutes) { r in
                XCTAssert(r.error?.domain == SmappeeErrorDomain, "Expecting error from SmappeeErrorDomain")
                XCTAssert(r.error?.code == SmappeeError.UnexpectedDataError.rawValue, "Expecting UnexpectedDataError")
                expectation.fulfill()
            }
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
}
