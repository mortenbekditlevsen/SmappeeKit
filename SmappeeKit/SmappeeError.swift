//
//  SmappeeError.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 20/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation

public let SmappeeErrorDomain = "SmappeeErrorDomain"

public func valueOrError<T>(value: T?, errorDescription: String) -> Result<T, NSError> {
    return valueOrError(value, SmappeeError.UnexpectedDataError.error(errorDescription: errorDescription))
}

enum SmappeeError : Int {
    case JSONParseError = 1
    case RequestStateMachineError
    case DelegateMissingError
    case InternalError
    case TokenResponseParseError
    case APIError
    case InvalidJSONError
    case AccessTokenExpiredError
    case UserCancelledLoginError
    case UnexpectedDataError
    case UnexpectedHTTPResponseError
    
    func description() -> String {
        switch self {
        case .JSONParseError:
            return "Error parsing JSON response"
        case .RequestStateMachineError:
            return "State machine is running in circles"
        case .DelegateMissingError:
            return "No SmappeeControllerDelegate provided"
        case .InternalError:
            return "Internal error"
        case .TokenResponseParseError:
            return "Could not parse reply"
        case .APIError:
            return "Error reported by Smappee API"
        case .InvalidJSONError:
            return "Invalid JSON"
        case .AccessTokenExpiredError:
            return "Access token expired"
        case .UserCancelledLoginError:
            return "User cancelled login"
        case .UnexpectedDataError:
            return "Unexpected data"
        case .UnexpectedHTTPResponseError:
            return "Unexpected HTTP response"
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
        return failure(error(errorDescription: errorDescription, underlyingError: underlyingError))
    }

}


