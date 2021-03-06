//
//  SmappeeTypes.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct ServiceLocation {
    public let id: Int
    public let name: String

    public init?(json: JSON) {
        if let
            id = json["serviceLocationId"].int,
            name = json["name"].string {
                self.id = id
                self.name = name
                
        }
        else {
            return nil
        }
    }
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

extension ServiceLocation : Equatable {}
public func ==(lhs: ServiceLocation, rhs: ServiceLocation) -> Bool {
    return lhs.id == rhs.id
}

public struct ServiceLocationInfo {
    public let serviceLocation: ServiceLocation
    public let electricityCurrency: String
    public let electricityCost: Double
    public let longitude: Double
    public let latitude: Double
    public let actuators: [Actuator]
    public let appliances: [Appliance]
    
    public init(serviceLocation: ServiceLocation, electricityCurrency: String, electricityCost: Double, longitude: Double, latitude: Double, actuators: [Actuator], appliances: [Appliance]) {
        self.serviceLocation = serviceLocation
        self.electricityCurrency = electricityCurrency
        self.electricityCost = electricityCost
        self.longitude = longitude
        self.latitude = latitude
        self.actuators = actuators
        self.appliances = appliances
    }
    
    public init?(json: JSON) {
        if let id = json["serviceLocationId"].int,
            name = json["name"].string,
            electricityCurrency = json["electricityCurrency"].string,
            electricityCost = json["electricityCost"].double,
            longitude = json["lon"].double,
            latitude = json["lat"].double
        {
            
            var actuators: [Actuator] = []
            var appliances: [Appliance] = []
            
            serviceLocation = ServiceLocation(id: id, name: name)
            self.electricityCost = electricityCost
            self.electricityCurrency = electricityCurrency
            self.longitude = longitude
            self.latitude = latitude
            
            for (_, applianceJSON) in json["appliances"] {
                if let appliance = Appliance(serviceLocation: serviceLocation, json: applianceJSON) {
                    appliances.append(appliance)
                }
                else {
                    return nil
                }
            }
            
            for (_, actuatorJSON) in json["actuators"] {
                if let actuator = Actuator(serviceLocation: serviceLocation, json: actuatorJSON) {
                    actuators.append(actuator)
                }
                else {
                    return nil
                }
            }
            
            self.appliances = appliances
            self.actuators = actuators
        }
        else {
            return nil
        }
    }
}

public struct Actuator {
    public let serviceLocation: ServiceLocation
    public let id: Int
    public let name: String
    
    public init(serviceLocation: ServiceLocation, id: Int, name: String) {
        self.serviceLocation = serviceLocation
        self.id = id
        self.name = name
    }
    
    public init?(serviceLocation: ServiceLocation, json: JSON) {
        if let
            id = json["id"].int,
            name = json["name"].string {
                self.serviceLocation = serviceLocation
                self.id = id
                self.name = name                
        }
        else {
            return nil
        }
    }
}

extension Actuator : Equatable {}
public func ==(lhs: Actuator, rhs: Actuator) -> Bool {
    return lhs.id == rhs.id
}

public struct Appliance {
    public let serviceLocation: ServiceLocation
    public let id: Int
    public let name: String
    public let type: String
    
    public init(serviceLocation: ServiceLocation, id: Int, name: String, type: String) {
        self.serviceLocation = serviceLocation
        self.id = id
        self.name = name
        self.type = type
    }
    
    public init?(serviceLocation: ServiceLocation, json: JSON) {
        if let
            id = json["id"].int,
            name = json["name"].string,
            type = json["type"].string {
                self.serviceLocation = serviceLocation
                self.id = id
                self.name = name
                self.type = type
        }
        else {
            return nil
        }
    }
}

extension Appliance : Equatable {}
public func ==(lhs: Appliance, rhs: Appliance) -> Bool {
    return lhs.id == rhs.id
}

public struct ApplianceEvent {
    public let appliance: Appliance
    public let activePower: Double
    public let timestamp: NSDate
    
    public init(appliance: Appliance, activePower: Double, timestamp: NSDate) {
        self.appliance = appliance
        self.activePower = activePower
        self.timestamp = timestamp
    }
    
    public init?(appliance: Appliance, json: JSON) {
        if let activePower = json["activePower"].double,
            timestamp = json["timestamp"].double {
                self.appliance = appliance
                self.activePower = activePower
                self.timestamp = NSDate(timeIntervalSince1970: timestamp/1000.0)
        }
        else {
            return nil
        }
    }
}

extension ApplianceEvent : Equatable {}
public func ==(lhs: ApplianceEvent, rhs: ApplianceEvent) -> Bool {
    return lhs.appliance == rhs.appliance && lhs.activePower == rhs.activePower && lhs.timestamp.isEqualToDate(rhs.timestamp)
}

public struct Consumption {
    public let consumption: Double
    public let alwaysOn: Double
    public let timestamp: NSDate
    public let solar: Double
    
    public init(consumption: Double, alwaysOn: Double, timestamp: NSDate, solar: Double) {
        self.consumption = consumption
        self.alwaysOn = alwaysOn
        self.timestamp = timestamp
        self.solar = solar
    }
    
    public init?(json: JSON) {
        if let
            consumption = json["consumption"].double,
            alwaysOn = json["alwaysOn"].double,
            timestamp = json["timestamp"].double,
            solar = json["solar"].double
        {
            self.timestamp = NSDate(timeIntervalSince1970: timestamp/1000.0)
            self.consumption = consumption
            self.alwaysOn = alwaysOn
            self.solar = solar
        }
        else {
            return nil
        }
    }
}

extension Consumption : Equatable {}
public func ==(lhs: Consumption, rhs: Consumption) -> Bool {
    return lhs.alwaysOn == rhs.alwaysOn && lhs.consumption == rhs.consumption && lhs.timestamp.isEqualToDate(rhs.timestamp) && lhs.solar == rhs.solar
}

extension Consumption : Hashable {
    public var hashValue : Int { get {
        return alwaysOn.hashValue ^ consumption.hashValue ^ solar.hashValue ^ timestamp.hashValue
        }
    }
    
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
