//
//  SmappeeError.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 20/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import Result

public let SmappeeErrorDomain = "SmappeeErrorDomain"

public enum SmappeeError : Int {
    case NotLoggedIn = 1000
    case InvalidUsernameOrPassword
    case AccessTokenExpired
    case JSONParseError
    case InternalError
    case UnexpectedDataError
    case UnexpectedHTTPResponseError
    
    func description() -> String {
        switch self {
        case .JSONParseError:
            return NSLocalizedString("Error parsing JSON response", comment: "Default error description for JSON parse errors")
        case .InternalError:
            return NSLocalizedString("Internal error", comment: "Default error description for internal errors")
        case .AccessTokenExpired:
            return NSLocalizedString("Access token expired", comment: "Default error description for access token expired error")
        case .UnexpectedDataError:
            return NSLocalizedString("Unexpected data", comment: "Default error description for unexpected data errors")
        case .UnexpectedHTTPResponseError:
            return NSLocalizedString("Unexpected HTTP response", comment: "Default error description for unexpected HTTP Response errors")
        case .InvalidUsernameOrPassword:
            return NSLocalizedString("Invalid username or password", comment: "Default error description for invalid username or password errors")
        case .NotLoggedIn:
            return NSLocalizedString("User is not logged in", comment: "Default error description for not logged in error")
        }
    }
    
    func error(errorDescription: String? = nil, underlyingError: NSError? = nil) -> NSError {
        let code = self.rawValue
        let description : String
        if let errorDescription = errorDescription {
            description = errorDescription
        }
        else {
            description = self.description()
        }
        var userInfo : [NSObject : AnyObject] = [NSLocalizedDescriptionKey: description]
        if let underlyingError = underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }
        return NSError(domain: SmappeeErrorDomain, code: code, userInfo: userInfo)
    }
    
    func errorResult<T>(errorDescription: String? = nil, underlyingError: NSError? = nil) -> Result<T,NSError> {
        return Result(error: error(errorDescription: errorDescription, underlyingError: underlyingError))
    }

}


