//
//  SmappeeTypes.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation

public struct ServiceLocation {
    public let id: Int
    public let name: String
}

public struct ServiceLocationInfo {
    public let serviceLocation: ServiceLocation
    public let electricityCurrency: String
    public let electricityCost: Double
    public let longitude: Double
    public let lattitude: Double
    public let actuators: [Actuator]
    public let appliances: [Appliance]
}

public struct Actuator {
    public let serviceLocation: ServiceLocation
    public let id: Int
    public let name: String
}

public struct Appliance {
    public let serviceLocation: ServiceLocation
    public let id: Int
    public let name: String
    public let type: String
}

public struct ApplianceEvent {
    public let appliance: Appliance
    public let activePower: Double
    public let timestamp: NSDate
}

public struct Consumption {
    public let consumption: Double
    public let alwaysOn: Double
    public let timestamp: NSDate
    public let solar: Double
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
