//
//  ViewController.swift
//  Example
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit
import SmappeeKit

class ViewController: UIViewController, LoginViewControllerDelegate {

    let smappeeController: SmappeeController
    var serviceLocation: ServiceLocation?
    var serviceLocationInfo: ServiceLocationInfo?
    var actuator: Actuator?
    
    @IBOutlet var serviceLocationsButton: UIButton!
    @IBOutlet var actuatorOnButton: UIButton!
    @IBOutlet var actuatorOffButton: UIButton!
    @IBOutlet var logoutButton: UIButton!
    
    required init(coder aDecoder: NSCoder) {
        smappeeController = SmappeeController(clientId: "XXX", clientSecret: "YYY")
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
        smappeeController.sendServiceLocationRequest { locations in
            let firstLocation = locations.flatMap({ valueOrError($0.first, "No service locations found")})
            firstLocation.flatMap(self.smappeeController.sendServiceLocationInfoRequest) { locationInfo in
                let firstActuator = locationInfo.flatMap({ valueOrError($0.actuators.first, "No actuators found")})
                firstActuator.flatMap(self.smappeeController.sendTurnOnRequest) { r in
                    // r is now a Success or a Failure propagated along from where it first went wrong
                    println(r)
                }
            }
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

    func getFirstServiceLocation(completion: (Result<ServiceLocation, NSError>) -> Void) {
        if let location = self.serviceLocation {
            completion(success(location))
        }
        else {
            smappeeController.sendServiceLocationRequest { r in
                let first = r.flatMap({ valueOrError($0.first, "No service locations found")})
                self.serviceLocation = first.value
                completion(first)
                self.updateButtonStates()
            }
        }
    }

    func getServiceLocationInfo(completion: ServiceLocationInfoRequestResult -> Void) {
        if let locationInfo = self.serviceLocationInfo {
            completion(success(locationInfo))
        }
        else {
            getFirstServiceLocation { r in
                r.flatMap(self.smappeeController.sendServiceLocationInfoRequest) { r in
                    self.serviceLocationInfo = r.value
                    completion(r)
                }
            }
        }
    }


    func getActuator() {
        getServiceLocationInfo { r in
            self.actuator = r.value?.actuators.first
            self.updateButtonStates()
        }
    }
    
    func getEventsFromInfo(info: ServiceLocationInfo, completion: EventsRequestResult -> Void) {
        self.smappeeController.sendEventsRequest(info.serviceLocation, appliances: info.appliances.filter({$0.name == "Nespresso"}), maxNumber: 10, from: NSDate(timeIntervalSinceNow: -3600*24), to: NSDate()) { r in
            completion(r)
        }
    }
    
    func getEvents() {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle
        getServiceLocationInfo { r in
            r.flatMap(self.getEventsFromInfo) { r in
                if let events = r.value {
                    for event in events {
                        let date = formatter.stringFromDate(event.timestamp)
                        println("Event: \(event.appliance.name) - \(event.activePower) - \(date)")
                    }
                }
            }
        }
    }
    
    func getConsumptionFromInfo(info: ServiceLocationInfo, completion: ConsumptionRequestResult -> Void) {
        self.smappeeController.sendConsumptionRequest(info.serviceLocation, from: NSDate(timeIntervalSinceNow: -3600*24*100), to: NSDate(), aggregation: .Monthly) {
            r in
            completion(r)
        }
    }

    func getConsumption() {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle
        getServiceLocationInfo { r in
            r.flatMap(self.getConsumptionFromInfo) { r in
                if let consumptions = r.value {
                    for consumption in consumptions {
                        let date = formatter.stringFromDate(consumption.timestamp)
                        println("Consumption: \(consumption.consumption) - \(consumption.alwaysOn) - \(date)")
                    }
                }
            }
        }
    }
    
    func actuatorOn(actuator: Actuator) {
        smappeeController.💡(actuator)
    }
    
    func actuatorOff(actuator: Actuator) {
        
        smappeeController.sendTurnOffRequest(actuator)
    }


}

