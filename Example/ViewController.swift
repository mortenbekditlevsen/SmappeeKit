//
//  ViewController.swift
//  Example
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit

class ViewController: UIViewController, SmappeControllerDelegate, LoginViewControllerDelegate {

    let smappeeController: SmappeeController
    var serviceLocation: Int?
    var actuator: Int?
    
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
            loginCompletion?(.Failure("Could not present login UI"))
            loginCompletion = nil
        }
    }
    
    // MARK: LoginViewControllerDelegate method
    
    func loginViewController(loginViewController: LoginViewController, didReturnUsername username: String, password: String) {

        self.dismissViewControllerAnimated(true, completion: nil)

        loginCompletion?(.Success(
                username: username,
                password: password
                ))
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
        if let serviceLocation = serviceLocation, actuator = actuator {
            actuatorOn(serviceLocation, actuator: actuator)
        }
    }

    @IBAction func actuatorOneOff(sender: AnyObject) {
        if let serviceLocation = serviceLocation, actuator = actuator {
            actuatorOff(serviceLocation, actuator: actuator)
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
        smappeeController.sendServiceLocationRequest { result in
            switch (result) {
            case .Success(let json):
                self.serviceLocation = json["serviceLocations"][0]["serviceLocationId"].int
                if let serviceLocation = self.serviceLocation {
                    self.getActuators(serviceLocation)
                }
                println(self.serviceLocation)
            case .Failure(let errorMessage):
                println(errorMessage)
            }
            self.updateButtonStates()
        }
    }
    
    func getActuators (serviceLocation: Int) {
        smappeeController.sendServiceLocationInfoRequest(serviceLocation) {
            result in
            switch result {
            case .Success(let json):
                println(json)
                self.actuator = json["actuators"][0]["id"].int
            case .Failure(let errorMessage):
                println(errorMessage)
            }
            self.updateButtonStates()
        }
    }
    
    func actuatorOn(serviceLocation: Int, actuator: Int) {
        smappeeController.sendTurnOnRequest(serviceLocation, actuator: actuator) { result in
        }
    }
    
    func actuatorOff(serviceLocation: Int, actuator: Int) {
        smappeeController.sendTurnOffRequest(serviceLocation, actuator: actuator) { result in
            
        }
    }


}

