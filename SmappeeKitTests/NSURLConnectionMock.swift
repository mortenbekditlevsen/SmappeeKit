//
//  NSURLConnectionMock.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation


private let _NSURLConnectionMockSharedInstance = NSURLConnectionMock()

class NSURLConnectionMock {
    var urlMapping: [String: (response: NSURLResponse?, data: NSData?, error: NSError?)] = [:]
    var overrideSingleResponse: (response: NSURLResponse?, data: NSData?, error: NSError?)?
    class var sharedInstance: NSURLConnectionMock {
        return _NSURLConnectionMockSharedInstance
    }
    init() {
        
    }
    
}

extension NSURLConnection {
    
    // MARK: - Method Swizzling
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        // make sure this isn't a subclass
        if self !== NSURLConnection.self {
            return
        }
        
        dispatch_once(&Static.token) {
            let originalSelector = Selector("sendAsynchronousRequest:queue:completionHandler:")
            let swizzledSelector = Selector("mockedSendAsynchronousRequest:queue:completionHandler:")
            
            let originalMethod = class_getClassMethod(self, originalSelector)
            let swizzledMethod = class_getClassMethod(self, swizzledSelector)
            
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
    
    class func mockedSendAsynchronousRequest(request: NSURLRequest,
        queue: NSOperationQueue!,
        completionHandler handler: (NSURLResponse!,
        NSData!,
        NSError!) -> Void) {
            if let parameters = NSURLConnectionMock.sharedInstance.overrideSingleResponse {
                // Only do this ONCE, so clear the value
                NSURLConnectionMock.sharedInstance.overrideSingleResponse = nil
                var response = parameters.response
                if response == nil {
                    response = NSHTTPURLResponse(URL: request.URL!, statusCode: 200, HTTPVersion: "1.1", headerFields: nil)
                }
                // Add a small delay to simulate asynchronicity.
                NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.05))
                handler(response, parameters.data, parameters.error)
            }
            else if let parameters = NSURLConnectionMock.sharedInstance.urlMapping[request.URL!.absoluteString] {
                
                var response = parameters.response
                if response == nil {
                    response = NSHTTPURLResponse(URL: request.URL!, statusCode: 200, HTTPVersion: "1.1", headerFields: nil)
                }
                // Add a small delay to simulate asynchronicity.
                NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.05))
                handler(response, parameters.data, parameters.error)
            }
            else {
                handler(nil, nil, nil)
            }
    }
}
