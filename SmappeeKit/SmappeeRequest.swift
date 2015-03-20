//
//  SmappeeRequest.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import SwiftyJSON

typealias TokenRequestResult = Result<(accessToken: String, refreshToken: String), NSError>
typealias SmappeeRequestResult = Result<JSON, NSError>

class SmappeeRequest {
    
    static let tokenEndPoint = "https://app1pub.smappee.net/dev/v1/oauth2/token"
    
    var loginState : SmappeeLoginState {
        didSet {
            controller.loginState = loginState
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
        attempts--;
        if (attempts <= 0) {
            completion(SmappeeError.RequestStateMachineError.errorResult())
            return
        }
        
        // Any branch in this switch must either result in calling the completion handler or changing the loginState
        switch loginState {
        case .LoggedIn(let tokens):
            weak var weakSelf = self
            sendRequest(urlRequest, tokens.accessToken) { result in
                switch result {
                case .Success(let box):
                    let json = box.unbox
                    self.completion(success(json))
                    
                case .Failure(let box):
                    let error = box.unbox
                    // Special handling of AccessTokenExpiredError, since this should just change state - 
                    // and not result in calling the completion with an error
                    if error.domain == SmappeeErrorDomain &&
                        error.code == SmappeeError.AccessTokenExpiredError.rawValue {
                        self.loginState = .AccessTokenExpired(tokens.refreshToken)
                    }
                    else {
                        self.completion(failure(error))
                    }
                }
            }
        case .LoggedOut:
            self.getAccessToken { result in
                switch result {
                case .Success(let box):
                    let tokens = box.unbox
                    self.loginState = .LoggedIn(tokens)
                    
                case .Failure(let box):
                    let error = box.unbox
                    if error.domain == SmappeeErrorDomain && error.code == SmappeeError.InvalidUsernameOrPassword.rawValue {
                        // Retry immediately when the error is username/password errors
                        self.loginState = .LoggedOut
                    }
                    else {
                        self.completion(failure(error))
                    }
                }
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
            completion(SmappeeError.DelegateMissingError.errorResult())
        }
    }
    
    
    func sendAccessTokenRequest (credentials: (username: String, password: String), completion: TokenRequestResult -> Void) {
        let clientId = controller.clientId
        let clientSecret = controller.clientSecret
        
        let tokenRequest = NSMutableURLRequest.init(URL: NSURL.init(string: SmappeeRequest.tokenEndPoint)!)
        tokenRequest.HTTPBody = "grant_type=password&client_id=\(clientId)&client_secret=\(clientSecret)&username=\(credentials.username)&password=\(credentials.password)".dataUsingEncoding(NSUTF8StringEncoding)
        tokenRequest.HTTPMethod = "POST"
        sendTokenRequest(tokenRequest, completion)
    }
    
    
    func refreshAccessToken(refreshToken: String, completion: (result: TokenRequestResult) -> Void) {
        let clientId = controller.clientId
        let clientSecret = controller.clientSecret
        let tokenRequest = NSMutableURLRequest.init(URL: NSURL.init(string: SmappeeRequest.tokenEndPoint)!)
        tokenRequest.HTTPBody = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientId)&client_secret=\(clientSecret)".dataUsingEncoding(NSUTF8StringEncoding)
        tokenRequest.HTTPMethod = "POST"
        sendTokenRequest(tokenRequest, completion)
    }
}


// MARK: Stateless functions


private func sendTokenRequest(tokenRequest: NSURLRequest, completion: (TokenRequestResult) -> Void) {
    NSURLConnection.sendAsynchronousRequest(tokenRequest, queue: NSOperationQueue.mainQueue()) {
        
        (response: NSURLResponse!, data: NSData?, error: NSError?) in
        if let data = data {
            let json = JSON(data: data)
            if let accessToken: String = json["access_token"].string,
                let refreshToken: String = json["refresh_token"].string {
                    completion(success(accessToken: accessToken, refreshToken: refreshToken))
            }
            else if let error: String = json["error"].string {
                var errorMessage = error
                let errorDescription = json["error_description"].stringValue
                if count(errorDescription) > 0 {
                    errorMessage += ": \(errorDescription)"
                }
                
                // Recognize responses that we know are due to invalid username/password combinations
                if error == "invalid_request" && errorDescription.rangeOfString("Missing parameters:") != nil {
                    completion(SmappeeError.InvalidUsernameOrPassword.errorResult(errorDescription: errorDescription))
                }
                else if error == "invalid username or password" {
                    completion(SmappeeError.InvalidUsernameOrPassword.errorResult())
                }
                else {
                    // And catch all other possible errors as more 'generic' API errors
                    completion(SmappeeError.APIError.errorResult(errorDescription: errorMessage))
                }
            }
            else {
                completion(SmappeeError.TokenResponseParseError.errorResult())
            }
        }
        else if let error = error {
            completion(SmappeeError.UnexpectedHTTPResponseError.errorResult(underlyingError: error))
        }
        else {
            completion(SmappeeError.InternalError.errorResult())
        }
    }
}

private func sendRequest(request: NSURLRequest, accessToken: String, completion: (SmappeeRequestResult) -> Void) {
    
    let mutableRequest = request.mutableCopy() as! NSMutableURLRequest
    mutableRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
    NSURLConnection.sendAsynchronousRequest(mutableRequest, queue: NSOperationQueue.mainQueue(), completionHandler: {
        (response: NSURLResponse?, data: NSData?, error:NSError?) in
        if let httpResponse = response as? NSHTTPURLResponse, data = data {
            
            switch httpResponse.statusCode {
            case 200:
                let json = JSON(data: data)

                // You _could_ argue that this is an error, but some Smappee request return a 0-byte response instead of
                // an empty JSON structure. We interpret 0 bytes as being an empty JSON value
                if data.length == 0 {
                    completion(success(json))
                }
                else if json.null != nil {
                    // In case SwiftyJSON supplies us with a parse error in the .error value, then we pass it on to the error result
                    completion(SmappeeError.InvalidJSONError.errorResult(underlyingError: json.error))
                }
                else {
                    completion(success(json))
                }
                
            case 401:
                completion(SmappeeError.AccessTokenExpiredError.errorResult())
                
            default:
                completion(SmappeeError.UnexpectedHTTPResponseError.errorResult(errorDescription: "Unexpected HTTP status response \(httpResponse.statusCode)", underlyingError: error))
            }
        }
        else if let error = error {
            /// TODO: Verify error message
            // Error code -1012 means 'User cancelled authentication'. It appears that this can be the case when
            // the reason is actually an expired access token.
            if error.code == -1012 && error.domain == NSURLErrorDomain {
                completion(SmappeeError.AccessTokenExpiredError.errorResult())
            }
            else {
                completion(SmappeeError.UnexpectedHTTPResponseError.errorResult(underlyingError: error))
            }
        }
        else {
            completion(SmappeeError.InternalError.errorResult(errorDescription: "Internal error - response is not a HTTP response"))
        }
    })
}


