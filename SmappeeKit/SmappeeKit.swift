//
//  SmappeeKit.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 26/02/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import SwiftyJSON
import LlamaKit

/// Login State for the Smappee client
///
/// - ``LoggedIn`` - In this state the client has an access token and a refresh token. The tokens may be expired.
/// - ``AccessTokenExpired`` - In this state we know that the access token has expired, but perhaps the refresh token is still valid
/// - ``LoggedOut`` - In this state we have no valid access or refresh tokens, and we need the user to supply login credentials to log in again

enum SmappeeLoginState: Printable {
    case LoggedIn(accessToken: String, refreshToken: String)
    case AccessTokenExpired(String)
    case LoggedOut
    
    var description : String {
        switch self {
        case .LoggedIn(let tokens): return "Logged in (with access token \(tokens.accessToken) and refresh token \(tokens.refreshToken))";
        case .AccessTokenExpired(let refreshToken): return "Access token expired (refresh token \(refreshToken))";
        case .LoggedOut: return "Logged out";
        }
    }
}

enum InternalRequestResult {
    case Success(JSON)
    case AccessTokenExpired
    case Failure(String)
}

typealias SmappeeRequestResult = Result<JSON, String>
typealias TokenRequestResult = Result<(accessToken: String, refreshToken: String), String>

public typealias ServiceLocationRequestResult = Result<[ServiceLocation], String>
public typealias ServiceLocationInfoRequestResult = Result<ServiceLocationInfo, String>
public typealias SmappeeCredentialsResult = Result<(username: String, password: String), String>

public func smappeeLoginSuccess (username: String, password: String) -> SmappeeCredentialsResult {
    return .Success(Box(username: username, password: password))
}

public func smappeeLoginFailure (errorMessage: String) -> SmappeeCredentialsResult {
    return .Failure(Box(errorMessage))
}


public struct ServiceLocation {
    let id: Int
    let name: String
}

public struct ServiceLocationInfo {
    let serviceLocation: ServiceLocation
    let electricityCurrency: String
    let electricityCost: Double
    let longitude: Double
    let lattitude: Double
    let actuators: [Actuator]
    let appliances: [Appliance]
}

struct Actuator {
    let serviceLocation: ServiceLocation
    let id: Int
    let name: String
}

struct Appliance {
    let serviceLocation: ServiceLocation
    let id: Int
    let name: String
    let type: String
}


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
                completion(.Failure(error.description))
            }
            else {
                completion(.Failure("Internal error - response is not a HTTP response"))
            }
        })
    }
}

// Delegate protocol for supplying login credentials

protocol SmappeControllerDelegate: class {
    func loginWithCompletion(completion: (SmappeeCredentialsResult) -> Void)
}

enum SmappeeAggregation: Int {
    case FiveMinutePeriod = 1
    case Hourly
    case Daily
    case Monthly
    case Yearly
}

class SmappeeController {
    
    // MARK: API endpoints
    
    private let serviceLocationEndPoint = "https://app1pub.smappee.net/dev/v1/servicelocation"
    
    private func serviceLocationInfoEndPoint(serviceLocation: ServiceLocation) -> String {
        return "https://app1pub.smappee.net/dev/v1/servicelocation/\(serviceLocation.id)/info"
    }
    
    private func consumptionEndPoint(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation) -> String {
        let fromMS : Int = Int(from.timeIntervalSince1970 * 1000)
        let toMS : Int = Int(to.timeIntervalSince1970 * 1000)
        return "https://app1pub.smappee.net/dev/v1/servicelocation/\(serviceLocation.id)/consumption?aggregation=\(aggregation.rawValue)&from=\(fromMS)&to=\(toMS)"
    }
    
    private func eventsEndPoint(serviceLocation: ServiceLocation, appliances: Array<Int>, maxNumber: Int, from: NSDate, to: NSDate) -> String {
        let fromMS : Int = Int(from.timeIntervalSince1970 * 1000)
        let toMS : Int = Int(to.timeIntervalSince1970 * 1000)
        let applianceString = appliances.map({appliance in "applianceId=\(appliance)&"})
        
        return "https://app1pub.smappee.net/dev/v1/servicelocation/\(serviceLocation.id)/events?\(applianceString)maxNumber=\(maxNumber)&from=\(fromMS)&to=\(toMS)"
    }
    
    private func actuatorEndPoint (actuator: Actuator, on: Bool) -> String {
        let action = on ? "on" : "off"
        return "https://app1pub.smappee.net/dev/v1/servicelocation/\(actuator.serviceLocation.id)/actuator/\(actuator.id)/\(action)"
    }
    
    // MARK: Constants
    
    private static let ACCESS_TOKEN_KEY = "SMAPPEEKIT_USERDEFAULTS_ACCESS_TOKEN_KEY"
    private static let REFRESH_TOKEN_KEY = "SMAPPEEKIT_USERDEFAULTS_REFRESH_TOKEN_KEY"
    
    // MARK: Members
    
    private let clientId, clientSecret: String
    private var saveTokens = false
    
    weak var delegate: SmappeControllerDelegate?
    
    var loginState : SmappeeLoginState {
        didSet {
            if (!saveTokens) {
                return
            }
            switch loginState {
            case .LoggedIn(let tokens):
                NSUserDefaults.standardUserDefaults().setObject(tokens.accessToken, forKey: SmappeeController.ACCESS_TOKEN_KEY)
                NSUserDefaults.standardUserDefaults().setObject(tokens.refreshToken, forKey: SmappeeController.REFRESH_TOKEN_KEY)
            case .AccessTokenExpired(let refreshToken):
                NSUserDefaults.standardUserDefaults().removeObjectForKey(SmappeeController.ACCESS_TOKEN_KEY)
                NSUserDefaults.standardUserDefaults().setObject(refreshToken, forKey: SmappeeController.REFRESH_TOKEN_KEY)
            case .LoggedOut:
                NSUserDefaults.standardUserDefaults().removeObjectForKey(SmappeeController.ACCESS_TOKEN_KEY)
                NSUserDefaults.standardUserDefaults().removeObjectForKey(SmappeeController.REFRESH_TOKEN_KEY)
            }
        }
    }
    
    // MARK: Initializers
    
    convenience init(clientId: String, clientSecret: String) {
        self.init(clientId: clientId, clientSecret: clientSecret, saveTokens: true)
    }
    
    convenience init(clientId: String, clientSecret: String, saveTokens: Bool) {
        var state = SmappeeLoginState.LoggedOut
        if (saveTokens) {
            let accessToken = NSUserDefaults.standardUserDefaults().stringForKey(SmappeeController.ACCESS_TOKEN_KEY)
            let refreshToken = NSUserDefaults.standardUserDefaults().stringForKey(SmappeeController.REFRESH_TOKEN_KEY)
            if let refreshToken = refreshToken {
                if let accessToken = accessToken {
                    state = .LoggedIn(accessToken: accessToken, refreshToken: refreshToken)
                }
                else {
                    state = .AccessTokenExpired(refreshToken)
                }
            }
        }
        self.init(clientId: clientId, clientSecret: clientSecret, loginState: state)
        self.saveTokens = saveTokens
    }
    
    init(clientId: String, clientSecret: String, loginState: SmappeeLoginState) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.loginState = loginState
    }
    
    /// :returns: *true* if ``loginState`` is ``.LoggedIn`` or ``.AccessTokenExpired``. In both cases we assume that we have, or can get a valid access token
    
    func loggedIn() -> Bool {
        switch loginState {
        case .LoggedOut:
            return false
        default:
            return true
        }
    }
    
    /// This implicitly clears access and refresh tokens
    func logOut() {
        loginState = .LoggedOut
    }
    
    // MARK: API Methods
    
    func parseServiceLocations(json: JSON, completion: (Result<[ServiceLocation], String>) -> Void) {
        var serviceLocations: [ServiceLocation] = []
        var parseError = false
        for (index, location) in json["serviceLocations"] {
            if let id = location["serviceLocationId"].int,
                name = location["name"].string {
                    serviceLocations.append(ServiceLocation(id: id, name: name))
            }
            else {
                parseError = true
                break
            }
        }
        
        if parseError {
            completion(failure("Error parsing service locations from JSON response"))
        }
        else {
            completion(success(serviceLocations))
        }
    }
    
    func parseServiceLocationInfo(json: JSON, completion: ServiceLocationInfoRequestResult -> Void) {
        var parseError = false
        var serviceLocationInfo : ServiceLocationInfo?
        
        if let id = json["serviceLocationId"].int,
            name = json["name"].string,
            electricityCurrency = json["electricityCurrency"].string,
            electricityCost = json["electricityCost"].double,
            longitude = json["lon"].double,
            lattitude = json["lat"].double
        {
            
            var actuators: [Actuator] = []
            var appliances: [Appliance] = []
            
            let serviceLocation = ServiceLocation(id: id, name: name)
            
            
            
            for (index, appliance) in json["appliances"] {
                if let id = appliance["id"].int,
                    name = appliance["name"].string,
                    type = appliance["type"].string {
                        appliances.append(Appliance(serviceLocation: serviceLocation, id: id, name: name, type: type))
                }
                else {
                    parseError = true
                    break
                }
            }
            
            for (index, actuator) in json["actuators"] {
                if let id = actuator["id"].int,
                    name = actuator["name"].string {
                        actuators.append(Actuator(serviceLocation: serviceLocation, id: id, name: name))
                }
                else {
                    parseError = true
                    break
                }
            }
            serviceLocationInfo = ServiceLocationInfo(serviceLocation: serviceLocation,
                electricityCurrency: "",
                electricityCost: 1,
                longitude: 1,
                lattitude: 1,
                actuators: actuators,
                appliances: appliances)
        }
        
        if let serviceLocationInfo = serviceLocationInfo where !parseError {
            completion(success(serviceLocationInfo))
        }
        else {
            completion(failure("Error parsing service locations from JSON response"))
        }
        
    }
    
    
    func sendServiceLocationRequest(completion: (Result<[ServiceLocation], String>) -> Void) {
        let request = NSURLRequest.init(URL: NSURL.init(string: serviceLocationEndPoint)!)
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.flatMap(self.parseServiceLocations, completion: completion)
        }
    }
    
    func sendServiceLocationInfoRequest(serviceLocation: ServiceLocation, completion: ServiceLocationInfoRequestResult -> Void) {
        let endPoint = serviceLocationInfoEndPoint(serviceLocation)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.flatMap(self.parseServiceLocationInfo, completion: completion)
        }
    }
    
    func sendConsumptionRequest(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation, completion: (SmappeeRequestResult) -> Void) {
        let endPoint = consumptionEndPoint(serviceLocation, from: from, to: to, aggregation: aggregation)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        SmappeeRequest(urlRequest: request, controller: self, completion: completion)
    }
    
    func sendEventsRequest(serviceLocation: ServiceLocation, appliances: Array<Int>, maxNumber: Int, from: NSDate, to: NSDate, completion: (SmappeeRequestResult) -> Void) {
        let endPoint = eventsEndPoint(serviceLocation, appliances: appliances, maxNumber: maxNumber, from: from, to: to)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        SmappeeRequest(urlRequest: request, controller: self, completion: completion)
    }
    
    
    func sendTurnOnRequest(actuator: Actuator, completion: (SmappeeRequestResult) -> Void) {
        let endPoint = actuatorEndPoint(actuator, on: true)
        let request = NSMutableURLRequest.init(URL: NSURL.init(string: endPoint)!)
        request.HTTPMethod = "POST"
        request.HTTPBody = "{}".dataUsingEncoding(NSUTF8StringEncoding)
        SmappeeRequest(urlRequest: request, controller: self, completion: completion)
    }
    
    func sendTurnOffRequest(actuator: Actuator, completion: (SmappeeRequestResult) -> Void) {
        let endPoint = actuatorEndPoint(actuator, on: false)
        let request = NSMutableURLRequest.init(URL: NSURL.init(string: endPoint)!)
        request.HTTPMethod = "POST"
        request.HTTPBody = "{}".dataUsingEncoding(NSUTF8StringEncoding)
        
        SmappeeRequest(urlRequest: request, controller: self, completion: completion)
    }
    
    
    
}
