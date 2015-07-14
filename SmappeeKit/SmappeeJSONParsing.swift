//
//  SmappeeJSONParsing.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import SwiftyJSON
import Result
import Future

// 'flatmap' fra før sørger for at en funktion, der selv returnerer en future bliver 'mappet'
// direkte igennem - ellers ville resultat-typen være Future<Future<noget, NSError>, NSError>
// så hvis du har en metode, der ikke returnerer en future bruger du 'map' og ellers bruger du 'flatMap'
func parseServiceLocations(json: JSON) -> Future<[ServiceLocation], NSError> {
    let serviceLocations = mapOrFail(json["serviceLocations"].arrayValue) {
        (json: JSON) -> (Result<ServiceLocation, NSError>) in
        
        if let location = ServiceLocation(json: json) {
            return Result(value: location)
        }
        else {
            return SmappeeError.JSONParseError.errorResult(NSLocalizedString("Error parsing Service Locations JSON", comment: "Error parsing Service Locations JSON"))
        }
    }
    return Future(result: serviceLocations)
}


func parseEvents(json: JSON, appliances: [Int: Appliance]) -> EventsRequestFuture {
    
    let events = mapOrFail(json.arrayValue) {
        (json: JSON) -> (Result<ApplianceEvent, NSError>) in
        
        if let
            id = json["applianceId"].int,
            appliance = appliances[id],
            event = ApplianceEvent(appliance: appliance, json: json) {
                return Result(value: event)
        }
        else {
            return SmappeeError.JSONParseError.errorResult(NSLocalizedString("Error parsing Events JSON", comment: "Error parsing Events JSON"))
        }
    }
    return Future(result: events)
}


func parseConsumptions(json: JSON) -> ConsumptionRequestFuture {
    let consumptions = mapOrFail(json["consumptions"].arrayValue) {
        (json: JSON) -> (Result<Consumption, NSError>) in
        
        if let consumption = Consumption(json: json) {
            return Result(value: consumption)
        }
        else {
            return SmappeeError.JSONParseError.errorResult("Error parsing Consumption JSON")
        }
    }
    return Future(result: consumptions)
}


func parseServiceLocationInfo(json: JSON) -> ServiceLocationInfoRequestFuture {
    let result : Result<ServiceLocationInfo, NSError>
    if let serviceLocationInfo = ServiceLocationInfo(json: json) {
        result = Result(value: serviceLocationInfo)
    }
    else {
        result = SmappeeError.JSONParseError.errorResult("Error parsing Service Location Info JSON")
    }
    return Future(result: result)
}

