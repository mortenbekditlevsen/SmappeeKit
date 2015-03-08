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
}

class LoginViewController: UIViewController {

    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    weak var delegate: LoginViewControllerDelegate?
    
    @IBAction func loginButtonAction(sender: AnyObject) {
        delegate?.loginViewController(self, didReturnUsername: usernameTextField.text, password: passwordTextField.text)
    }
}
