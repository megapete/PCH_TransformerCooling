//
//  AppDelegate.swift
//  PCH_TransformerCooling
//
//  Created by Peter Huber on 2018-09-10.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    @IBAction func RunTest(_ sender: Any)
    {
        RunThermalTest()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

