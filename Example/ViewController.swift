//
//  ViewController.swift
//  Example
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit
import SmappeeKit

class ViewController: UIViewController, SmappeeControllerDelegate, LoginViewControllerDelegate {

    let smappeeController: SmappeeController
    var serviceLocation: ServiceLocation?
    var serviceLocationInfo: ServiceLocationInfo?
    var actuator: Actuator?
    
    var loginCompletion: ((SmappeeCredentialsResult) -> Void)?
    
    @IBOutlet var serviceLocationsButton: UIButton!
    @IBOutlet var actuatorOnButton: UIButton!
    @IBOutlet var actuatorOffButton: UIButton!
    @IBOutlet var logoutButton: UIButton!
    
    required init(coder aDecoder: NSCoder) {
        smappeeController = SmappeeController(clientId: "XXX", clientSecret: "YYY")
        super.init(coder: aDecoder)
        
        // Reference to self must happen after super.init call
        smappeeController.delegate = self
    }
    
    // MARK: SmappeeControllerDelegate method
    func loginWithCompletion(completion: (SmappeeCredentialsResult) -> Void) {
        loginCompletion = completion
        
        let loginViewController = self.storyboard?.instantiateViewControllerWithIdentifier("loginViewController") as? LoginViewController
        
        if let loginViewController = loginViewController {
            loginViewController.delegate = self
            self.presentViewController(loginViewController, animated: true, completion: nil)
        }
        else {
            loginCompletion?(smappeeLoginFailure("Could not present login UI"))
            loginCompletion = nil
        }
    }
    
    // MARK: LoginViewControllerDelegate method
    
    func loginViewController(loginViewController: LoginViewController, didReturnUsername username: String, password: String) {

        self.dismissViewControllerAnimated(true, completion: nil)

        loginCompletion?(smappeeLoginSuccess(username, password))
        loginCompletion = nil
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
        logoutButton.enabled = smappeeController.loggedIn()
    }
    
    // MARK: IB Actions
    @IBAction func serviceLocationsAction(sender: AnyObject) {
        getActuator()
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
        actuator = nil
        updateButtonStates()
    }
    
    // MARK: SmappeeKit calls

    func getFirstServiceLocation(completion: (Result<ServiceLocation, String>) -> Void) {
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
                        println("Event: \(consumption.consumption) - \(consumption.alwaysOn) - \(date)")
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

