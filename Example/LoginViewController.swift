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
    func loginViewControllerDidLogin()
    func loginViewControllerDidCancel()
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
        delegate?.loginViewControllerDidCancel()
    }
    @IBAction func loginButtonAction(sender: AnyObject) {
        smappeeController?.login(usernameTextField.text, password: passwordTextField.text) { r in
            switch r {
            case .Success:
                self.delegate?.loginViewControllerDidLogin()
            case .Failure(let box):
                let error = box.unbox
                if error.domain == SmappeeErrorDomain && error.code == SmappeeError.InvalidUsernameOrPassword.rawValue {
                    self.invalidUsernameOrPassword()
                }
            }
        }
    }
    
    func invalidUsernameOrPassword() {
        invalidUsernameLabel.alpha = 1
        UIView.animateWithDuration(2, animations: { () -> Void in
            self.invalidUsernameLabel.alpha = 0
        })
    }
}
