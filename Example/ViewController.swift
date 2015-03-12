//
//  ViewController.swift
//  Example
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit
import LlamaKit

class ViewController: UIViewController, SmappeControllerDelegate, LoginViewControllerDelegate {

    let smappeeController: SmappeeController
    var serviceLocation: ServiceLocation?
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
        getServiceLocations()
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

    
    func getServiceLocations() {
        smappeeController.sendServiceLocationRequest { r in
            r.flatMap({ valueOrError($0.first, "No service locations found")
            }).flatMap(self.smappeeController.sendServiceLocationInfoRequest) { r in
                switch r {
                case .Success(let box):
                    let info = box.unbox
                    self.actuator = info.actuators.first
                    println("Success")
                case .Failure(let box):
                    let errorMessage = box.unbox
                    println(errorMessage)
                }
                self.updateButtonStates()
            }
        }
    }
    
    func getEvents() {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle
        smappeeController.sendServiceLocationRequest { r in
            r.flatMap({ valueOrError($0.first, "No service locations found")
            }).flatMap(self.smappeeController.sendServiceLocationInfoRequest) { r in
                switch r {
                case .Success(let box):
                    let info = box.unbox
                    self.smappeeController.sendEventsRequest(info.serviceLocation, appliances: info.appliances.filter({$0.name == "Nespresso"}), maxNumber: 10, from: NSDate(timeIntervalSinceNow: -3600*24), to: NSDate()) { r in
                        if let events = r.value {
                            for event in events {
                                let date = formatter.stringFromDate(event.timestamp)
                                println("Event: \(event.appliance.name) - \(event.activePower) - \(date)")
                            }
                        }
                        }
                    
                    self.actuator = info.actuators.first
                    println("Success")
                case .Failure(let box):
                    let errorMessage = box.unbox
                    println(errorMessage)
                }
                self.updateButtonStates()
            }
        }
    }

    func getConsumption() {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle
        smappeeController.sendServiceLocationRequest { r in
            r.flatMap({ valueOrError($0.first, "No service locations found")
            }).flatMap(self.smappeeController.sendServiceLocationInfoRequest) { r in
                switch r {
                case .Success(let box):
                    let info = box.unbox
                    self.smappeeController.sendConsumptionRequest(info.serviceLocation, from: NSDate(timeIntervalSinceNow: -3600*24*100), to: NSDate(), aggregation: .Monthly) { r in
                        if let consumptions = r.value {
                            for consumption in consumptions {
                                let date = formatter.stringFromDate(consumption.timestamp)
                                println("Event: \(consumption.consumption) - \(consumption.alwaysOn) - \(date)")
                            }
                        }
                    }
                    
                    self.actuator = info.actuators.first
                    println("Success")
                case .Failure(let box):
                    let errorMessage = box.unbox
                    println(errorMessage)
                }
                self.updateButtonStates()
            }
        }
    }

    
    
    func actuatorOn(actuator: Actuator) {
        smappeeController.sendTurnOnRequest(actuator, duration: .FiveMinutes) { result in }
    }
    
    func actuatorOff(actuator: Actuator) {
        smappeeController.sendTurnOffRequest(actuator) { result in }
    }


}

