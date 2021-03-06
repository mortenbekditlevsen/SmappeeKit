//
//  SmappeeRequest.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import SwiftyJSON
import Result
import Future

typealias TokenRequestFuture = Future<(accessToken: String, refreshToken: String), NSError>
typealias SmappeeRequestFuture = Future<JSON, NSError>

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
    let completion: Result<JSON, NSError> -> Void
    
    var attempts: Int
    
    init (urlRequest: NSURLRequest, controller: SmappeeController, completion: Result<JSON, NSError> -> Void) {
        attempts = 0
        self.controller = controller
        self.urlRequest = urlRequest
        self.completion = completion
        loginState = controller.loginState
        changeState()
    }
    
    func setAccessToken(tokens: (accessToken: String, refreshToken: String), completion: SmappeeRequestFuture -> Void) {
        self.loginState = .LoggedIn(tokens)
    }
    
    func changeState() {
        attempts++;
        if (attempts >= 10) {
            completion(SmappeeError.InternalError.errorResult("State machine is running in circles"))
            return
        }
        
        // Any branch in this switch must either result in calling the completion handler or changing the loginState
        switch loginState {
        case .LoggedIn(let tokens):
//            weak var weakSelf = self
            sendRequest(urlRequest, accessToken: tokens.accessToken).onComplete { result in
                switch result {
                case .Success(let json):
                    self.completion(Result(value: json))
                    
                case .Failure(let error):
                    // Special handling of AccessTokenExpired, since this should just change state -
                    // and not result in calling the completion with an error
                    if error.domain == SmappeeErrorDomain &&
                        error.code == SmappeeError.AccessTokenExpired.rawValue {
                            self.loginState = .AccessTokenExpired(tokens.refreshToken)
                    }
                    else {
                        self.completion(Result(error: error))
                    }
                }
            }
            
        case .LoggedOut:
            completion(SmappeeError.NotLoggedIn.errorResult())
            
        case .AccessTokenExpired(let refreshToken):
            self.refreshAccessToken(refreshToken).onComplete { result in
                switch result {
                case .Success(let tokens):
                    self.loginState = .LoggedIn(tokens)
                    
                case .Failure:
                    // If refreshToken is expired too, then we attempt to log in all from the beginning
                    self.loginState = .LoggedOut
                }
            }
        }
    }
    
    func refreshAccessToken(refreshToken: String) -> TokenRequestFuture {
        let clientId = controller.clientId
        let clientSecret = controller.clientSecret
        let tokenRequest = NSMutableURLRequest.init(URL: NSURL.init(string: SmappeeRequest.tokenEndPoint)!)
        tokenRequest.HTTPBody = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientId)&client_secret=\(clientSecret)".dataUsingEncoding(NSUTF8StringEncoding)
        tokenRequest.HTTPMethod = "POST"
        return sendTokenRequest(tokenRequest)
    }

    
    class func sendLoginRequest (username: String, password: String, controller: SmappeeController) -> LoginRequestFuture {
        
        let clientId = controller.clientId
        let clientSecret = controller.clientSecret
        
        let tokenRequest = NSMutableURLRequest.init(URL: NSURL.init(string: SmappeeRequest.tokenEndPoint)!)
        tokenRequest.HTTPBody = "grant_type=password&client_id=\(clientId)&client_secret=\(clientSecret)&username=\(username)&password=\(password)".dataUsingEncoding(NSUTF8StringEncoding)
        tokenRequest.HTTPMethod = "POST"
        return sendTokenRequest(tokenRequest).map({ tokens in .LoggedIn(tokens) })
    }
}


// MARK: Stateless functions

private func sendTokenRequest(tokenRequest: NSURLRequest) -> TokenRequestFuture {
    return Future { completion in
        let session = NSURLSession.sharedSession()
        session.dataTaskWithRequest(tokenRequest) {
            (data, response, error) -> Void in
            if let data = data {
                let json = JSON(data: data)
                if let accessToken: String = json["access_token"].string,
                    let refreshToken: String = json["refresh_token"].string {
                        completion(Result(value:(accessToken: accessToken, refreshToken: refreshToken)))
                }
                else if let error: String = json["error"].string {
                    var errorMessage = error
                    let errorDescription = json["error_description"].stringValue
                    if errorDescription.characters.count > 0 {
                        errorMessage += ": \(errorDescription)"
                    }
                    
                    // Recognize responses that we know are due to invalid username/password combinations
                    if error == "invalid_request" && errorDescription.rangeOfString("Missing parameters:") != nil {
                        completion(SmappeeError.InvalidUsernameOrPassword.errorResult(errorDescription))
                    }
                    else if error == "invalid username or password" {
                        completion(SmappeeError.InvalidUsernameOrPassword.errorResult())
                    }
                    else {
                        // And catch all other possible errors as more 'generic' API errors
                        completion(SmappeeError.UnexpectedDataError.errorResult(errorMessage))
                    }
                }
                else {
                    completion(SmappeeError.UnexpectedDataError.errorResult("Could not parse token response"))
                }
            }
            else if let error = error {
                completion(Result(error:error))
            }
            else {
                completion(SmappeeError.InternalError.errorResult())
            }
        }.resume()
    }
//    return Future { completion in
//
//        let session = NSURLSession.sharedSession()
//        let task = session.dataTaskWithRequest(tokenRequest) {
//            (data, response, error) -> Void in
//            if let data = data {
//                let json = JSON(data: data)
//                if let accessToken: String = json["access_token"].string,
//                    let refreshToken: String = json["refresh_token"].string {
//                        completion(Result(value:(accessToken: accessToken, refreshToken: refreshToken)))
//                }
//                else if let error: String = json["error"].string {
//                    var errorMessage = error
//                    let errorDescription = json["error_description"].stringValue
//                    if errorDescription.characters.count > 0 {
//                        errorMessage += ": \(errorDescription)"
//                    }
//                    
//                    // Recognize responses that we know are due to invalid username/password combinations
//                    if error == "invalid_request" && errorDescription.rangeOfString("Missing parameters:") != nil {
//                        completion(SmappeeError.InvalidUsernameOrPassword.errorResult(errorDescription))
//                    }
//                    else if error == "invalid username or password" {
//                        completion(SmappeeError.InvalidUsernameOrPassword.errorResult())
//                    }
//                    else {
//                        // And catch all other possible errors as more 'generic' API errors
//                        completion(SmappeeError.UnexpectedDataError.errorResult(errorMessage))
//                    }
//                }
//                else {
//                    completion(SmappeeError.UnexpectedDataError.errorResult("Could not parse token response"))
//                }
//            }
//            else if let error = error {
//                completion(Result(error:error))
//            }
//            else {
//                completion(SmappeeError.InternalError.errorResult())
//            }
//        }
//        task.resume()
//    }
}

private func sendRequest(request: NSURLRequest, accessToken: String) -> SmappeeRequestFuture {
    return Future { completion in
        let mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        mutableRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        // print("Request: \(request)")
        
        let session = NSURLSession.sharedSession()
        session.dataTaskWithRequest(mutableRequest) {
            (data, response, error) -> Void in

//        NSURLConnection.sendAsynchronousRequest(mutableRequest, queue: NSOperationQueue.mainQueue(), completionHandler: {
//            (response: NSURLResponse?, data: NSData?, error:NSError?) in
            if let httpResponse = response as? NSHTTPURLResponse, data = data {
                
                switch httpResponse.statusCode {
                case 200:
                    let json = JSON(data: data)
                    
                    // You _could_ argue that this is an API error, but some Smappee request return a 0-byte response instead of
                    // an empty JSON structure. We interpret 0 bytes as being an empty JSON value
                    if data.length == 0 {
                        completion(Result(value:json))
                    }
                    else if json.null != nil {
                        // In case SwiftyJSON supplies us with a parse error in the .error value, then we pass it on to the error result
                        completion(SmappeeError.UnexpectedDataError.errorResult("Invalid JSON", underlyingError: json.error))
                    }
                    else {
                        completion(Result(value: json))
                    }
                    
                case 401:
                    completion(SmappeeError.AccessTokenExpired.errorResult())
                    
                default:
                    completion(SmappeeError.UnexpectedHTTPResponseError.errorResult("Unexpected HTTP status response \(httpResponse.statusCode)", underlyingError: error))
                }
            }
            else if let error = error {
                // 'User cancelled authentication'. It appears that this can be the case when
                // the reason is actually an expired access token.
                if error.code == NSURLErrorUserCancelledAuthentication && error.domain == NSURLErrorDomain {
                    completion(SmappeeError.AccessTokenExpired.errorResult())
                }
                else {
                    completion(Result(error: error))
                }
            }
            else {
                completion(SmappeeError.InternalError.errorResult("Internal error - response is not a HTTP response"))
            }
        }.resume()
    }
}


