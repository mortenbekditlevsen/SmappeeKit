//
//  SmappeeJSONParsing.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import SwiftyJSON

func parseServiceLocations(json: JSON, completion: (Result<[ServiceLocation], NSError>) -> Void) {
    let serviceLocations = mapOrFail(json["serviceLocations"].arrayValue) {
        (json: JSON) -> (Result<ServiceLocation, NSError>) in
        
        if let location = ServiceLocation(json: json) {
            return success(location)
        }
        else {
            return SmappeeError.JSONParseError.errorResult(errorDescription: NSLocalizedString("Error parsing Service Locations JSON", comment: "Error parsing Service Locations JSON"))
        }
    }
    completion(serviceLocations)
}


func parseEvents(json: JSON, appliances: [Int: Appliance], completion: EventsRequestResult -> Void) {
    
    let events = mapOrFail(json.arrayValue) {
        (json: JSON) -> (Result<ApplianceEvent, NSError>) in
        
        if let
            id = json["applianceId"].int,
            appliance = appliances[id],
            event = ApplianceEvent(appliance: appliance, json: json) {
                return success(event)
        }
        else {
            return SmappeeError.JSONParseError.errorResult(errorDescription: NSLocalizedString("Error parsing Events JSON", comment: "Error parsing Events JSON"))
        }
    }
    completion(events)
}


func parseConsumptions(json: JSON, completion: ConsumptionRequestResult -> Void) {
    let consumptions = mapOrFail(json["consumptions"].arrayValue) {
        (json: JSON) -> (Result<Consumption, NSError>) in
        
        if let consumption = Consumption(json: json) {
            return success(consumption)
        }
        else {
            return SmappeeError.JSONParseError.errorResult(errorDescription: NSLocalizedString("Error parsing Consumption JSON", comment: "Error parsing Consumption JSON"))
        }
    }
    completion(consumptions)
}


func parseServiceLocationInfo(json: JSON, completion: ServiceLocationInfoRequestResult -> Void) {
    var serviceLocationInfo : ServiceLocationInfo?
    
    if let serviceLocationInfo = ServiceLocationInfo(json: json) {
        completion(success(serviceLocationInfo))
    }
    else {
        completion(SmappeeError.JSONParseError.errorResult(errorDescription: NSLocalizedString("Error parsing Service Location Info JSON", comment: "Error parsing Service Location Info JSON")))
    }
}

