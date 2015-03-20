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
        
        if let
            id = json["serviceLocationId"].int,
            name = json["name"].string {
                return success(ServiceLocation(id: id, name: name))
        }
        else {
            return SmappeeError.JSONParseError.errorResult(errorDescription: "Error parsing Service Locations JSON")
        }
    }
    completion(serviceLocations)
}


func parseEvents(json: JSON, appliances: [Int: Appliance], completion: EventsRequestResult -> Void) {
    
    let events = mapOrFail(json.arrayValue) {
        (json: JSON) -> (Result<ApplianceEvent, NSError>) in
        
        if let
            id = json["applianceId"].int,
            activePower = json["activePower"].double,
            timestamp = json["timestamp"].double,
            appliance = appliances[id] {
                let date = NSDate(timeIntervalSince1970: timestamp/1000.0)
                return success(ApplianceEvent(appliance: appliance, activePower: activePower, timestamp: date))
        }
        else {
            return SmappeeError.JSONParseError.errorResult(errorDescription: "Error parsing Events JSON")
        }
    }
    completion(events)
}


func parseConsumptions(json: JSON, completion: ConsumptionRequestResult -> Void) {
    
    let consumptions = mapOrFail(json["consumptions"].arrayValue) {
        (json: JSON) -> (Result<Consumption, NSError>) in
        
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
            return SmappeeError.JSONParseError.errorResult(errorDescription: "Error parsing Consumption JSON")
        }
    }
    completion(consumptions)
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
        completion(SmappeeError.JSONParseError.errorResult(errorDescription: "Error parsing Service Location Info JSON"))
    }
}

