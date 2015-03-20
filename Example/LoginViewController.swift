//
//  LoginViewController.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 08/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import UIKit

protocol LoginViewControllerDelegate: class {
    func loginViewController(loginViewController: LoginViewController, didReturnUsername: String, password: String)
    func loginViewControllerDidCancel()
}

class LoginViewController: UIViewController {

    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var invalidUsernameLabel: UILabel!
    weak var delegate: LoginViewControllerDelegate?
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        invalidUsernameLabel.alpha = 0
    }
    
    @IBAction func cancelButtonAction(sender: AnyObject) {
        delegate?.loginViewControllerDidCancel()
    }
    @IBAction func loginButtonAction(sender: AnyObject) {
        delegate?.loginViewController(self, didReturnUsername: usernameTextField.text, password: passwordTextField.text)
    }
    
    func invalidUsernameOrPassword() {
        invalidUsernameLabel.alpha = 1
        UIView.animateWithDuration(2, animations: { () -> Void in
            self.invalidUsernameLabel.alpha = 0
        })
    }
}
