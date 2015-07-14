//
//  ViewController.swift
//  Example
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit
import SmappeeKit
import Result
import Future

func valueOrError<T>(optional: Optional<T>, errorDescription: String) -> Future<T, NSError> {
    if let value = optional {
        return Future(value: value)
    } else {
        return Future(error: NSError(domain: "", code: 1, userInfo: nil))
    }
}
infix operator ^^^ {
// Left associativity
associativity left

// precedence
precedence 150
}

// Operator for `valueOrError`
public func ^^^ <T> (optional: Optional<T>, errorDescription: String) -> Future<T, NSError> {
    return valueOrError(optional, errorDescription: errorDescription)
}



class ViewController: UIViewController, LoginViewControllerDelegate {

    let smappeeController: SmappeeController
    var serviceLocation: ServiceLocation?
    var serviceLocationInfo: ServiceLocationInfo?
    var actuator: Actuator?
    
    @IBOutlet var serviceLocationsButton: UIButton!
    @IBOutlet var actuatorOnButton: UIButton!
    @IBOutlet var actuatorOffButton: UIButton!
    @IBOutlet var logoutButton: UIButton!
    
    required init?(coder aDecoder: NSCoder) {
        smappeeController = SmappeeController(clientId: "MortenBek", clientSecret: "qjCFQebMwS")
        super.init(coder: aDecoder)
        
        // Reference to self must happen after super.init call
        if smappeeController.isLoggedIn() {
            getActuator()
        }
    }
    
    func presentLoginUI() {
        if !self.isViewLoaded() || self.view.window == nil {
            return
        }
        
        if let loginViewController = self.storyboard?.instantiateViewControllerWithIdentifier("loginViewController") as? LoginViewController {
            loginViewController.delegate = self
            loginViewController.smappeeController = smappeeController
            self.presentViewController(loginViewController, animated: true, completion: nil)
        }
    }
    
    // MARK: LoginViewControllerDelegate method
    
    func loginViewControllerDidLogin(loginViewController: LoginViewController) {
        loginViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func loginViewControllerDidCancel(loginViewController: LoginViewController) {
        loginViewController.dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: ViewController life-cycle methods

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateButtonStates()
    }
    
    func updateButtonStates() {
        serviceLocationsButton.enabled = serviceLocation == nil
        actuatorOffButton.enabled = actuator != nil
        actuatorOnButton.enabled = actuator != nil
        logoutButton.enabled = smappeeController.isLoggedIn()
    }
    
    // Unused code - just to show how 'flatMap' can be used to chain together requests
    // Just an example - it's probably better if you choose to store intermediate values somehow
    func complexMappingExample() {
        let locations = smappeeController.sendServiceLocationRequest()
        let firstLocation = locations.flatMap(  { $0.first ^^^ "No service locations found" })
        let locationInfo = firstLocation.flatMap(self.smappeeController.sendServiceLocationInfoRequest)
        let firstActuator = locationInfo.flatMap({ $0.actuators.first ^^^ "No actuators found"})
        firstActuator.flatMap(self.smappeeController.sendTurnOnRequest).andThen {
            r in print(r)
        }
    }
    
    // omskrevet til ikke at have midlertidige variable
    
    func complexMappingExample2() {
        smappeeController.sendServiceLocationRequest()
          .flatMap({ $0.first ^^^ "No service locations found"})
          .flatMap(self.smappeeController.sendServiceLocationInfoRequest)
          .flatMap({ $0.actuators.first ^^^ "No actuators found"})
          .flatMap(self.smappeeController.sendTurnOnRequest).andThen {
            r in
            print(r)
        }
    }
    
    // Omskrevet til at bruge >>- istedet for flatMap

    func complexMappingExample3() {
        let request = smappeeController.sendServiceLocationRequest() >>-
            { $0.first ^^^ "No service locations found" } >>-
            self.smappeeController.sendServiceLocationInfoRequest >>-
            { $0.actuators.first ^^^ "No actuators found" } >>-
            self.smappeeController.sendTurnOnRequest
        
        request.andThen {
            r in print(r)
        }
    }
    
    
    // Som one-liner
    
    // måske lidt svært at læse - men måske skal man bare vænne sig til det
    func complexMappingExample4() {
        (smappeeController.sendServiceLocationRequest() >>-
            { valueOrError($0.first, errorDescription: "No service locations found")} >>-
            self.smappeeController.sendServiceLocationInfoRequest >>-
            { valueOrError($0.actuators.first, errorDescription: "No actuators found")} >>-
            self.smappeeController.sendTurnOnRequest).andThen {
            r in print(r)
        }
    }


    
    // MARK: IB Actions
    @IBAction func serviceLocationsAction(sender: AnyObject) {
        if !smappeeController.isLoggedIn() {
            presentLoginUI()
        }
        else {
            getActuator()
        }
    }
    
    @IBAction func actuatorOneOn(sender: AnyObject) {
        if let actuator = actuator {
            actuatorOn(actuator)
        }
    }

    @IBAction func actuatorOneOff(sender: AnyObject) {
        if let actuator = actuator {
            actuatorOff(actuator)
        }
    }
    
    @IBAction func logoutAction(sender: AnyObject) {
        smappeeController.logOut()
        serviceLocation = nil
        serviceLocationInfo = nil
        actuator = nil
        updateButtonStates()
    }
    
    // MARK: SmappeeKit calls

    
    func getFirstServiceLocation() -> Future<ServiceLocation, NSError> {
        if let location = self.serviceLocation {
            return Future(value: location)
        }
        else {
            let locations = smappeeController.sendServiceLocationRequest()
            let location = locations.flatMap({ valueOrError($0.first, errorDescription: "No service locations found")})
            return location.andThen { r in
                self.serviceLocation = r.value
                self.updateButtonStates()
            }
        }
    }

    func getServiceLocationInfo() -> ServiceLocationInfoRequestFuture {
        if let locationInfo = self.serviceLocationInfo {
            return Future(value: locationInfo)
        }
        else {
            let location = getFirstServiceLocation()
            let locationInfo = location.flatMap(self.smappeeController.sendServiceLocationInfoRequest)
            return locationInfo.andThen { r in
                
                // Use Result 'dematerialize' to convert a result it's value - throwing if it contains an error
                do {
                    self.serviceLocationInfo = try r.dematerialize()
                } catch let error {
                    print(error)
                }
            }
        }
    }


    func getActuator() {
        getServiceLocationInfo().onComplete { r in
            do {
                self.actuator = try r.dematerialize().actuators.first
            } catch let error {
                print(error)
            }

            self.updateButtonStates()
        }
    }
    
    func getEventsFromInfo(info: ServiceLocationInfo) -> EventsRequestFuture {
        return self.smappeeController.sendEventsRequest(info.serviceLocation, appliances: info.appliances.filter({$0.name == "Nespresso"}), maxNumber: 10, from: NSDate(timeIntervalSinceNow: -3600*24*10), to: NSDate())
    }
    
    func getEvents() {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle
        getServiceLocationInfo().flatMap(self.getEventsFromInfo).onComplete { r in
            
            do {
                
                let events = try r.dematerialize()
                for event in events {
                    let date = formatter.stringFromDate(event.timestamp)
                    print("Event: \(event.appliance.name) - \(event.activePower) - \(date)")
                }
                
            } catch let error {
                print(error)
            }

        }
    }
    
    func getConsumptionFromInfo(info: ServiceLocationInfo) -> ConsumptionRequestFuture {
        return self.smappeeController.sendConsumptionRequest(info.serviceLocation, from: NSDate(timeIntervalSinceNow: -3600*24*100), to: NSDate(), aggregation: .Monthly)
    }

    func getConsumption() {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle
        getServiceLocationInfo().flatMap(self.getConsumptionFromInfo).onComplete { r in
            
            do {
                let consumptions = try r.dematerialize()
                
                for consumption in consumptions {
                    let date = formatter.stringFromDate(consumption.timestamp)
                    print("Consumption: \(consumption.consumption) - \(consumption.alwaysOn) - \(date)")
                }
            } catch let error {
                print(error)
            }
        }
    }
    
    func actuatorOn(actuator: Actuator) {
        smappeeController.sendTurnOnRequest(actuator)
        getConsumption()
    }
    
    func actuatorOff(actuator: Actuator) {
        smappeeController.sendTurnOffRequest(actuator)
        getEvents()
    }


}

