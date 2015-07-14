//
//  LoginViewController.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit
import SmappeeKit

protocol LoginViewControllerDelegate: class {
    func loginViewControllerDidLogin(loginViewController: LoginViewController)
    func loginViewControllerDidCancel(loginViewController: LoginViewController)
}

class LoginViewController: UIViewController {

    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var invalidUsernameLabel: UILabel!
    weak var delegate: LoginViewControllerDelegate?
    var smappeeController: SmappeeController?
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        invalidUsernameLabel.alpha = 0
    }
    
    @IBAction func cancelButtonAction(sender: AnyObject) {
        delegate?.loginViewControllerDidCancel(self)
    }
    @IBAction func loginButtonAction(sender: AnyObject) {
        guard let username = usernameTextField.text,
            password = passwordTextField.text
            else {
                return
        }
        smappeeController?.login(username, password: password).onComplete { r in
            switch r {
            case .Success:
                self.delegate?.loginViewControllerDidLogin(self)
            case .Failure(let error):
                if error.domain == SmappeeErrorDomain && error.code == SmappeeError.InvalidUsernameOrPassword.rawValue {
                    self.showError("Invalid username or password")
                }
                else {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    func showError(error: String) {
        invalidUsernameLabel.text = error
        invalidUsernameLabel.alpha = 1
        UIView.animateWithDuration(2, animations: { () -> Void in
            self.invalidUsernameLabel.alpha = 0
        })
    }
}
