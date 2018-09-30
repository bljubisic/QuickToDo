//
//  AppDelegate.swift
//  SportsOrganizer
//
//  Created by Bratislav Ljubisic on 3/29/17.
//  Copyright © 2017 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import Contacts

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var store = CNContactStore()

    func checkAccessStatus(completionHandler: @escaping (_ accessGranted: Bool) -> Void) {
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)
        
        switch authorizationStatus {
        case .authorized:
            completionHandler(true)
        case .denied, .notDetermined:
            self.store.requestAccess(for: CNEntityType.contacts, completionHandler: { (access, accessError) -> Void in
                if access {
                    completionHandler(access)
                } else {
                    print("access denied")
                }
            })
        default:
            completionHandler(false)
        }
    }
    
    private func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        let initViewController = MainViewController()
        
        //initViewController.viewModel = ViewModel(withModel: model)
        window?.rootViewController = UINavigationController(rootViewController: initViewController)
        window?.makeKeyAndVisible()
        return true
    }
}

