//
//  SmappeeAPIEndpoints.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation

// MARK: API endpoints

let serviceLocationEndPoint = "https://app1pub.smappee.net/dev/v1/servicelocation"

func serviceLocationInfoEndPoint(serviceLocation: ServiceLocation) -> String {
    return "https://app1pub.smappee.net/dev/v1/servicelocation/\(serviceLocation.id)/info"
}

// TODO: Move number formatter out of this
func consumptionEndPoint(serviceLocation: ServiceLocation, from: NSDate, to: NSDate, aggregation: SmappeeAggregation) -> String {
    let formatter = NSNumberFormatter()
    formatter.numberStyle = .DecimalStyle
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 0
    let fromMS =  formatter.stringFromNumber(NSNumber(double: from.timeIntervalSince1970 * 1000))!
    let toMS =  formatter.stringFromNumber(NSNumber(double: to.timeIntervalSince1970 * 1000))!
    return "https://app1pub.smappee.net/dev/v1/servicelocation/\(serviceLocation.id)/consumption?aggregation=\(aggregation.rawValue)&from=\(fromMS)&to=\(toMS)"
}

func eventsEndPoint(serviceLocation: ServiceLocation, appliances: Array<Appliance>, maxNumber: Int, from: NSDate, to: NSDate) -> String {
    let formatter = NSNumberFormatter()
    formatter.numberStyle = .DecimalStyle
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 0
    let fromMS =  formatter.stringFromNumber(NSNumber(double: from.timeIntervalSince1970 * 1000))!
    let toMS =  formatter.stringFromNumber(NSNumber(double: to.timeIntervalSince1970 * 1000))!
    let applianceString = appliances.reduce("", combine: {$0 + "applianceId=\($1.id)&"})
    
    return "https://app1pub.smappee.net/dev/v1/servicelocation/\(serviceLocation.id)/events?\(applianceString)maxNumber=\(maxNumber)&from=\(fromMS)&to=\(toMS)"
}

func actuatorEndPoint (actuator: Actuator, on: Bool) -> String {
    let action = on ? "on" : "off"
    return "https://app1pub.smappee.net/dev/v1/servicelocation/\(actuator.serviceLocation.id)/actuator/\(actuator.id)/\(action)"
}
