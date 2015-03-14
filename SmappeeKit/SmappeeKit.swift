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

public func mapOrFail<T,U,E> (array: [T], transform: (T) -> Result<U,E>) -> Result<[U],E> {
    var result = [U]()
    for element in array {
        switch transform(element) {
        case .Success(let box):
            result.append(box.unbox)
        case .Failure(let box):
            return failure(box.unbox)
        }
    }
    return success(result)
}


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

public typealias SmappeeRequestResult = Result<JSON, String>
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

public struct Actuator {
    let serviceLocation: ServiceLocation
    let id: Int
    let name: String
}

public struct Appliance {
    let serviceLocation: ServiceLocation
    let id: Int
    let name: String
    let type: String
}

public struct ApplianceEvent {
    let appliance: Appliance
    let activePower: Double
    let timestamp: NSDate
}

public struct Consumption {
    let consumption: Double
    let alwaysOn: Double
    let timestamp: NSDate
    let solar: Double
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

// Delegate protocol for supplying login credentials

public protocol SmappeControllerDelegate: class {
    func loginWithCompletion(completion: (SmappeeCredentialsResult) -> Void)
}

public enum SmappeeAggregation: Int {
    case FiveMinutePeriod = 1
    case Hourly
    case Daily
    case Monthly
    case Yearly
}

public enum SmappeeActuatorDuration: Int {
    case Indefinitely = 0
    case FiveMinutes = 300
    case QuarterOfAnHour = 900
    case HalfAnHour = 1800
    case Hour = 3600
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
    
    private let clientId, clientSecret: String
    private var saveTokens = false
    
    weak var delegate: SmappeControllerDelegate?
    
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
    
    convenience init(clientId: String, clientSecret: String, saveTokens: Bool = true) {
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
    
    init(clientId: String, clientSecret: String, loginState: SmappeeLoginState) {
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
    
    public func sendConsumptionRequest(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation, completion: Result<[Consumption], String> -> Void) {
        let endPoint = consumptionEndPoint(serviceLocation, from, to, aggregation)
        let request = NSURLRequest.init(URL: NSURL.init(string: endPoint)!)
        SmappeeRequest(urlRequest: request, controller: self) { r in
            r.flatMap(parseConsumptions, completion: completion)
        }
    }
    
    public func sendEventsRequest(serviceLocation: ServiceLocation, appliances: [Appliance], maxNumber: Int, from: NSDate, to: NSDate, completion: Result<[ApplianceEvent], String> -> Void) {
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
    
    public func sendTurnOnRequest(actuator: Actuator, duration: SmappeeActuatorDuration = .Indefinitely, completion: (Result<Void, String>) -> Void) {
        sendActuatorRequest(actuator, on: true, duration: duration, completion: completion)
    }
    
    public func sendTurnOffRequest(actuator: Actuator, duration: SmappeeActuatorDuration = .Indefinitely, completion: (Result<Void, String>) -> Void) {
        sendActuatorRequest(actuator, on: false, duration: duration, completion: completion)
    }
    
    public func sendActuatorRequest(actuator: Actuator, on: Bool, duration: SmappeeActuatorDuration, completion: (Result<Void, String>) -> Void) {
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

private func eventsEndPoint(serviceLocation: ServiceLocation, appliances: Array<Appliance>, maxNumber: Int, from: NSDate, to: NSDate) -> String {
    let fromMS : Int = Int(from.timeIntervalSince1970 * 1000)
    let toMS : Int = Int(to.timeIntervalSince1970 * 1000)
    let applianceString = appliances.reduce("", combine: {$0 + "applianceId=\($1.id)&"})
    
    return "https://app1pub.smappee.net/dev/v1/servicelocation/\(serviceLocation.id)/events?\(applianceString)maxNumber=\(maxNumber)&from=\(fromMS)&to=\(toMS)"
}

private func actuatorEndPoint (actuator: Actuator, on: Bool) -> String {
    let action = on ? "on" : "off"
    return "https://app1pub.smappee.net/dev/v1/servicelocation/\(actuator.serviceLocation.id)/actuator/\(actuator.id)/\(action)"
}



// MARK: JSON Parsing

private func parseServiceLocations(json: JSON, completion: (Result<[ServiceLocation], String>) -> Void) {
    let serviceLocations = mapOrFail(json["serviceLocations"].arrayValue) {
        (json: JSON) -> (Result<ServiceLocation, String>) in
        
        if let
            id = json["serviceLocationId"].int,
            name = json["name"].string {
                return success(ServiceLocation(id: id, name: name))
        }
        else {
            return failure("Error parsing service locations from JSON response")
        }
    }
    completion(serviceLocations)
}


private func parseEvents(json: JSON, appliances: [Int: Appliance], completion: Result<[ApplianceEvent], String> -> Void) {
    
    let events = mapOrFail(json.arrayValue) {
        (json: JSON) -> (Result<ApplianceEvent, String>) in
        
        if let
            id = json["applianceId"].int,
            activePower = json["activePower"].double,
            timestamp = json["timestamp"].double,
            appliance = appliances[id] {
                let date = NSDate(timeIntervalSince1970: timestamp/1000.0)
                return success(ApplianceEvent(appliance: appliance, activePower: activePower, timestamp: date))
        }
        else {
            return failure("Error parsing events from JSON response")
        }
    }
    completion(events)
}


private func parseConsumptions(json: JSON, completion: Result<[Consumption], String> -> Void) {
    
    let consumptions = mapOrFail(json["consumptions"].arrayValue) {
        (json: JSON) -> (Result<Consumption, String>) in
        
        if let
            consumption = json["consumption"].double,
            alwaysOn = json["alwaysOn"].double,
            timestamp = json["timestamp"].double,
            solar = json["solar"].double
        {
            let date = NSDate(timeIntervalSince1970: timestamp/1000.0)
            return success(Consumption(consumption: consumption, alwaysOn: alwaysOn, timestamp: date, solar: solar))
        }
        else {
            return failure("Error parsing consumption entries from JSON response")
        }
    }
    completion(consumptions)
}


private func parseServiceLocationInfo(json: JSON, completion: ServiceLocationInfoRequestResult -> Void) {
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
            electricityCurrency: electricityCurrency,
            electricityCost: electricityCost,
            longitude: longitude,
            lattitude: lattitude,
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


