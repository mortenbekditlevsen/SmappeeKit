//
//  SmappeeController.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 26/02/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation

public typealias ServiceLocationRequestResult = Result<[ServiceLocation], String>
public typealias ServiceLocationInfoRequestResult = Result<ServiceLocationInfo, String>
public typealias EventsRequestResult = Result<[ApplianceEvent], String>
public typealias ConsumptionRequestResult = Result<[Consumption], String>
public typealias SmappeeCredentialsResult = Result<(username: String, password: String), String>

// Delegate protocol for supplying login credentials

public protocol SmappeeControllerDelegate: class {
    func loginWithCompletion(completion: (SmappeeCredentialsResult) -> Void)
}

public func smappeeLoginSuccess (username: String, password: String) -> SmappeeCredentialsResult {
    return .Success(Box(username: username, password: password))
}

public func smappeeLoginFailure (errorMessage: String) -> SmappeeCredentialsResult {
    return .Failure(Box(errorMessage))
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
    
    public weak var delegate: SmappeeControllerDelegate?
    
    var loginState : SmappeeLoginState {
        didSet {
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
    
    public func loggedIn() -> Bool {
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
    
    
    // MARK: API Methods
    
    public func sendServiceLocationRequest(completion: (Result<[ServiceLocation], String>) -> Void) {
        let request = NSURLRequest.init(URL: NSURL.init(string: serviceLocationEndPoint)!)
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.flatMap(parseServiceLocations, completion: completion)
        }
    }
    
    public func sendServiceLocationInfoRequest(serviceLocation: ServiceLocation, completion: ServiceLocationInfoRequestResult -> Void) {
        let endPoint = serviceLocationInfoEndPoint(serviceLocation)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.flatMap(parseServiceLocationInfo, completion: completion)
        }
    }
    
    public func sendConsumptionRequest(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation, completion: ConsumptionRequestResult -> Void) {
        let endPoint = consumptionEndPoint(serviceLocation, from, to, aggregation)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.flatMap(parseConsumptions, completion: completion)
        }
    }
    
    public func sendEventsRequest(serviceLocation: ServiceLocation, appliances: [Appliance], maxNumber: Int, from: NSDate, to: NSDate, completion: EventsRequestResult -> Void) {
        // Convert appliances array to a dictionary from the id to the appliance
        let applianceDict : [Int: Appliance] = appliances.reduce([:]) { (var dict, appliance) in
            dict[appliance.id] = appliance
            return dict
        }

        let endPoint = eventsEndPoint(serviceLocation, appliances, maxNumber, from, to)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.flatMap({parseEvents($0, applianceDict, $1)}, completion: completion)
        }
    }
    
    public func 💡(actuator: Actuator) {
        sendTurnOnRequest(actuator, completion: {r in })
    }
    
    public func sendTurnOnRequest(actuator: Actuator, duration: SmappeeActuatorDuration = .Indefinitely, completion: (Result<Void, String>) -> Void = { result in }) {
        sendActuatorRequest(actuator, on: true, duration: duration, completion: completion)
    }
    
    public func sendTurnOffRequest(actuator: Actuator, duration: SmappeeActuatorDuration = .Indefinitely, completion: (Result<Void, String>) -> Void = { result in }) {
        sendActuatorRequest(actuator, on: false, duration: duration, completion: completion)
    }
    
    public func sendActuatorRequest(actuator: Actuator, on: Bool, duration: SmappeeActuatorDuration, completion: (Result<Void, String>) -> Void = { result in }) {
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
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.map({$1()}, completion: completion)
        }
    }
}





