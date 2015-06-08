//
//  SmappeeController.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 26/02/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import Result
import Future
import SwiftyJSON

public typealias ServiceLocationRequestResult = Future<[ServiceLocation], NSError>
public typealias ServiceLocationInfoRequestResult = Future<ServiceLocationInfo, NSError>
public typealias EventsRequestResult = Future<[ApplianceEvent], NSError>
public typealias ConsumptionRequestResult = Future<[Consumption], NSError>
public typealias LoginRequestResult = Future<SmappeeLoginState, NSError>

// Delegate protocol for supplying login credentials

public protocol SmappeeControllerLoginStateDelegate: class {
    func loginStateChangedFrom(loginState oldLoginState: SmappeeLoginState, toLoginState newLoginState: SmappeeLoginState)
}

/// Login State for the Smappee client
///
/// - ``LoggedIn`` - In this state the client has an access token and a refresh token. The tokens may be expired.
/// - ``AccessTokenExpired`` - In this state we know that the access token has expired, but perhaps the refresh token is still valid
/// - ``LoggedOut`` - In this state we have no valid access or refresh tokens, and we need the user to supply login credentials to log in again

public enum SmappeeLoginState: Printable {
    case LoggedIn(accessToken: String, refreshToken: String)
    case AccessTokenExpired(String)
    case LoggedOut
    
    public var description : String {
        switch self {
        case .LoggedIn(let tokens): return "Logged in (with access token \(tokens.accessToken) and refresh token \(tokens.refreshToken))";
        case .AccessTokenExpired(let refreshToken): return "Access token expired (refresh token \(refreshToken))";
        case .LoggedOut: return "Logged out";
        }
    }
}


public class SmappeeController {
    
    // MARK: Constants
    private static let ACCESS_TOKEN_KEY = "SMAPPEEKIT_USERDEFAULTS_ACCESS_TOKEN_KEY"
    private static let REFRESH_TOKEN_KEY = "SMAPPEEKIT_USERDEFAULTS_REFRESH_TOKEN_KEY"

    // MARK: Load and save tokens to NSUserDefaults
    private class func loadTokens() -> (accessToken: String?, refreshToken: String?) {
        let accessToken = NSUserDefaults.standardUserDefaults().stringForKey(ACCESS_TOKEN_KEY)
        let refreshToken = NSUserDefaults.standardUserDefaults().stringForKey(REFRESH_TOKEN_KEY)
        return (accessToken, refreshToken)
    }
    
    private class func saveTokens(accessToken: String? = nil, refreshToken: String? = nil) {
        for keyValue in [(accessToken, ACCESS_TOKEN_KEY), (refreshToken, REFRESH_TOKEN_KEY)] {
            if let key = keyValue.0 {
                NSUserDefaults.standardUserDefaults().setObject(key, forKey: keyValue.1)
            }
            else {
                NSUserDefaults.standardUserDefaults().removeObjectForKey(keyValue.1)
            }
        }
    }
    
    // MARK: Members
    
    let clientId, clientSecret: String
    private var saveTokens = false
    
    public weak var loginStateDelegate: SmappeeControllerLoginStateDelegate?

    var loginState : SmappeeLoginState {
        didSet {
            loginStateDelegate?.loginStateChangedFrom(loginState: oldValue, toLoginState: loginState)
            if (!saveTokens) {
                return
            }
            switch loginState {
            case .LoggedIn(let (accessToken, refreshToken)):
                SmappeeController.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
            case .AccessTokenExpired(let refreshToken):
                SmappeeController.saveTokens(refreshToken: refreshToken)
            case .LoggedOut:
                SmappeeController.saveTokens()
            }
        }
    }
    
    // MARK: Initializers
    
    public convenience init(clientId: String, clientSecret: String, saveTokens: Bool = true) {
        var state = SmappeeLoginState.LoggedOut
        if (saveTokens) {
            let (accessToken, refreshToken) = SmappeeController.loadTokens()
            if let accessToken = accessToken, refreshToken = refreshToken {
                state = .LoggedIn(accessToken: accessToken, refreshToken: refreshToken)
            }
            else if let refreshToken = refreshToken {
                state = .AccessTokenExpired(refreshToken)
            }
        }
        self.init(clientId: clientId, clientSecret: clientSecret, loginState: state)
        self.saveTokens = saveTokens
    }
    
    public init(clientId: String, clientSecret: String, loginState: SmappeeLoginState) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.loginState = loginState
    }

    /// :returns: *true* if ``loginState`` is ``.LoggedIn`` or ``.AccessTokenExpired``. In both cases we assume that we have, or can get a valid access token
    
    public func isLoggedIn() -> Bool {
        switch loginState {
        case .LoggedOut:
            return false
        default:
            return true
        }
    }
    
    /// This implicitly clears access and refresh tokens
    public func logOut() {
        loginState = .LoggedOut
    }

    public func login(username: String, password: String) -> LoginRequestResult {
        return SmappeeRequest.sendLoginRequest(username, password: password, controller: self).andThen { result in
            if let loginState = result.value {
                self.loginState = loginState
            }
        }
    }
        
    private func createSmappeeRequest(urlRequest: NSURLRequest) -> SmappeeRequestResult {
        
        return Future { completion in
            
            SmappeeRequest(urlRequest: urlRequest, controller: self) { r in
                completion(r)
            }

            // WTF?!?!?!
            let a = 1
        }
    }

    // MARK: API Methods
    
    public func sendServiceLocationRequest() -> Future<[ServiceLocation], NSError> {
        let request = NSURLRequest.init(URL: NSURL.init(string: serviceLocationEndPoint)!)
        // brug af 'flatmap' til 'chaining'. parseServiceLocations er ikke asynkron, men resultatet
        // af at 'mappe' er en ny Future
        return createSmappeeRequest(request).flatMap(parseServiceLocations)
    }
    
    public func sendServiceLocationInfoRequest(serviceLocation: ServiceLocation) -> ServiceLocationInfoRequestResult {
        let endPoint = serviceLocationInfoEndPoint(serviceLocation)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        return createSmappeeRequest(request).flatMap(parseServiceLocationInfo)
    }
    
    public func sendConsumptionRequest(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation) -> ConsumptionRequestResult {
        let endPoint = consumptionEndPoint(serviceLocation, from, to, aggregation)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        return createSmappeeRequest(request).flatMap(parseConsumptions)
    }
    
    public func sendEventsRequest(serviceLocation: ServiceLocation, appliances: [Appliance], maxNumber: Int, from: NSDate, to: NSDate) -> EventsRequestResult {
        // Convert appliances array to a dictionary from the id to the appliance
        let applianceDict : [Int: Appliance] = appliances.reduce([:]) { (var dict, appliance) in
            dict[appliance.id] = appliance
            return dict
        }

        let endPoint = eventsEndPoint(serviceLocation, appliances, maxNumber, from, to)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        return createSmappeeRequest(request).flatMap({parseEvents($0, applianceDict)})
    }
    
    public func 💡(actuator: Actuator) {
        sendTurnOnRequest(actuator)
    }
    
    // The reason I am overloading here - instead of just supplying default values to 'duration' parameter is that
    // the Result 'flatMap' takes a function with two parameters, input and completion. It does not know how to handle default values of functions
    // Overloading does the trick!
    public func sendTurnOnRequest(actuator: Actuator) -> Future<Void, NSError> {
        return sendActuatorRequest(actuator, on: true, duration: .Indefinitely)
    }
    
    public func sendTurnOnRequest(actuator: Actuator, duration: SmappeeActuatorDuration) ->  Future<Void, NSError> {
        return sendActuatorRequest(actuator, on: true, duration: duration)
    }

    public func sendTurnOffRequest(actuator: Actuator) -> Future<Void, NSError> {
        return sendActuatorRequest(actuator, on: false, duration: .Indefinitely)
    }

    public func sendTurnOffRequest(actuator: Actuator, duration: SmappeeActuatorDuration) -> Future<Void, NSError> {
        return sendActuatorRequest(actuator, on: false, duration: duration)
    }
    
    public func sendActuatorRequest(actuator: Actuator, on: Bool, duration: SmappeeActuatorDuration) -> Future<Void, NSError> {
        let endPoint = actuatorEndPoint(actuator, on)
        let request = NSMutableURLRequest.init(URL: NSURL.init(string: endPoint)!)
        let durationString: String

        switch duration {
        case .Indefinitely:
            durationString = ""
        default:
            durationString = "\"duration\": \(duration.rawValue)"
        }
        
        request.HTTPMethod = "POST"
        request.HTTPBody = "{\(durationString)}".dataUsingEncoding(NSUTF8StringEncoding)
        
        // Map from a JSON Result (which is always empty) to a Void Result
        // The map transform function takes two parameters. The first is of type JSON, and is always empty
        // according to the docs. The second is the completion. Simply use 'map' with a transform that calls the completion with 'Void' argument
        return createSmappeeRequest(request).map({f in})
    }
}





