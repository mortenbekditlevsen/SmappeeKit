//
//  SmappeeRequest.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import SwiftyJSON
import LlamaKit

enum InternalRequestResult {
    case Success(JSON)
    case AccessTokenExpired
    case Failure(String)
}


typealias TokenRequestResult = Result<(accessToken: String, refreshToken: String), String>
typealias SmappeeRequestResult = Result<JSON, String>

class SmappeeRequest {
    
    let tokenEndPoint = "https://app1pub.smappee.net/dev/v1/oauth2/token"
    
    var loginState : SmappeeLoginState {
        willSet {
            println("Old value: \(loginState)")
        }
        didSet {
            println("New value: \(loginState)")
            changeState()
        }
    }
    
    let controller: SmappeeController
    let urlRequest: NSURLRequest
    let completion: (SmappeeRequestResult) -> Void
    
    var attempts: Int
    
    init (urlRequest: NSURLRequest, controller: SmappeeController, completion: (SmappeeRequestResult) -> Void) {
        attempts = 10
        self.controller = controller
        self.urlRequest = urlRequest
        self.completion = completion
        loginState = controller.loginState
        changeState()
    }
    
    func setAccessToken(tokens: (accessToken: String, refreshToken: String), completion: SmappeeRequestResult -> Void) {
        self.loginState = .LoggedIn(tokens)
    }
    
    func changeState() {
        controller.loginState = loginState
        attempts--;
        if (attempts <= 0) {
            completion(failure("State machine is running in circles"))
            return
        }
        
        // Any branch in this switch must either result in calling the completion handler or changing the loginState
        switch loginState {
        case .LoggedIn(let tokens):
            weak var weakSelf = self
            self.dynamicType.sendRequest(urlRequest, accessToken: tokens.accessToken, completion: { result in
                switch result {
                case .Success(let json):
                    self.completion(success(json))
                    
                case .AccessTokenExpired:
                    self.loginState = .AccessTokenExpired(tokens.refreshToken)
                    
                case .Failure(let errorMessage):
                    self.completion(failure(errorMessage))
                }
            })
        case .LoggedOut:
            self.getAccessToken { r in
                r.flatMap(self.setAccessToken, completion: self.completion)
            }
            
        case .AccessTokenExpired(let refreshToken):
            self.refreshAccessToken(refreshToken) { result in
                switch result {
                case .Success(let box):
                    let tokens = box.unbox
                    self.loginState = .LoggedIn(tokens)
                    
                case .Failure:
                    // If refreshToken is expired too, then we attempt to log in all from the beginning
                    self.loginState = .LoggedOut
                }
            }
        }
    }
    
    
    
    func getAccessToken(completion: TokenRequestResult -> Void) {
        if let delegate = self.controller.delegate {
            delegate.loginWithCompletion({ r in
                r.flatMap(self.sendAccessTokenRequest, completion: completion)
            })
        }
        else {
            completion(failure("No SmappeeControllerDelegate provided"))
        }
    }
    
    func sendAccessTokenRequest (credentials: (username: String, password: String), completion: TokenRequestResult -> Void) {
        let clientId = controller.clientId
        let clientSecret = controller.clientSecret
        
        let tokenRequest = NSMutableURLRequest.init(URL: NSURL.init(string: tokenEndPoint)!)
        tokenRequest.HTTPBody = "grant_type=password&client_id=\(clientId)&client_secret=\(clientSecret)&username=\(credentials.username)&password=\(credentials.password)".dataUsingEncoding(NSUTF8StringEncoding)
        tokenRequest.HTTPMethod = "POST"
        self.dynamicType.sendTokenRequest(tokenRequest, completion: completion)
    }
    
    func refreshAccessToken(refreshToken: String, completion: (result: TokenRequestResult) -> Void) {
        let clientId = controller.clientId
        let clientSecret = controller.clientSecret
        let tokenRequest = NSMutableURLRequest.init(URL: NSURL.init(string: tokenEndPoint)!)
        tokenRequest.HTTPBody = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientId)&client_secret=\(clientSecret)".dataUsingEncoding(NSUTF8StringEncoding)
        tokenRequest.HTTPMethod = "POST"
        self.dynamicType.sendTokenRequest(tokenRequest, completion: completion)
    }
    
    // MARK: Stateless methods
    
    class func sendTokenRequest(tokenRequest: NSURLRequest, completion: (result: TokenRequestResult) -> Void) {
        NSURLConnection.sendAsynchronousRequest(tokenRequest, queue: NSOperationQueue.mainQueue()) {
            
            (response: NSURLResponse!, data: NSData?, error: NSError?) in
            if let data = data {
                let json = JSON(data: data)
                if let accessToken: String = json["access_token"].string,
                    let refreshToken: String = json["refresh_token"].string {
                        completion(result: success(accessToken: accessToken, refreshToken: refreshToken))
                }
                else if let error: String = json["error"].string {
                    var errorMessage = error
                    if let errorDescription: String = json["error_description"].string {
                        errorMessage += ": \(errorDescription)"
                    }
                    completion(result: failure(errorMessage))
                }
                else {
                    completion(result: failure("Could not parse reply"))
                }
            }
            else if let error = error {
                completion(result: failure(error.description))
            }
            else {
                completion(result: failure("Internal error"))
            }
        }
    }
    
    class func sendRequest(request: NSURLRequest, accessToken: String, completion: (InternalRequestResult) -> Void) {
        
        let mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        mutableRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        NSURLConnection.sendAsynchronousRequest(mutableRequest, queue: NSOperationQueue.mainQueue(), completionHandler: {
            (response: NSURLResponse?, data: NSData?, error:NSError?) in
            if let httpResponse = response as? NSHTTPURLResponse, data = data {
                
                switch httpResponse.statusCode {
                case 200:
                    let json = JSON(data: data)
                    completion(.Success(json))
                    
                case 401:
                    completion(.AccessTokenExpired)
                    
                default:
                    completion(.Failure("Unexpected HTTP status response \(httpResponse.statusCode)"))
                }
            }
            else if let error = error {
                /// TODO: Verify error message
                // Error code -1012 means 'User cancelled authentication'. It appears that this can be the case when
                // the reason is actually an expired access token.
                if error.code == -1012 && error.domain == NSURLErrorDomain {
                    completion(.AccessTokenExpired)
                }
                else {
                    completion(.Failure(error.description))
                }
            }
            else {
                completion(.Failure("Internal error - response is not a HTTP response"))
            }
        })
    }
}

