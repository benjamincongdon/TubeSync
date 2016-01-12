//
//  PreferencesViewController.swift
//  Playlist Sync
//
//  Created by Benjamin Congdon on 1/11/16.
//  Copyright © 2016 Benjamin Congdon. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var syncFrequency: NSPopUpButtonCell!
    @IBOutlet weak var syncEnabledButton: NSButton!
    @IBOutlet weak var usernameField: NSTextFieldCell!
    @IBOutlet weak var passwordField: NSSecureTextField!
    @IBOutlet weak var outputDirTextField: NSTextField!
    @IBOutlet weak var twoFAField: NSTextField!
    @IBOutlet weak var submitDisconnectButton: NSButton!
    @IBOutlet weak var usernameLabel: NSTextField!
    @IBOutlet weak var passwordLabel: NSTextField!
    @IBOutlet weak var twoFALabel: NSTextField!
    
    var outputDir:NSURL
    
    override init(nibName: String?, bundle: NSBundle?){
        outputDir = NSURL()
        super.init(nibName: nibName, bundle: bundle)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func onChangeEnabled(sender: NSButton) {
        let state = (sender.state == NSOnState)
        NSUserDefaults.standardUserDefaults().setValue(state, forKey: "syncEnabled")
        NSUserDefaults.standardUserDefaults().synchronize()
        //TODO: Probably need to call something to tell it to enable/disable
        
    }
    
    func getURL() -> NSURL{
        let panel:NSOpenPanel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() != NSModalResponseOK {return NSURL()}
        return(panel.URLs.last)!
    }
    
    @IBAction func promptNewOutputDir(sender: AnyObject) {
        outputDir = getURL()
        outputDirTextField.stringValue = outputDir.path!
        NSUserDefaults.standardUserDefaults().setURL(outputDir, forKey: "OutputDirectory")
    }
        
    @IBAction func onSubmitCredentials(sender: NSButton) {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let client = delegate.youtubeClient
        //Submit credentials
        if sender.title == "Submit" {
            if client.authenticated {
                lockInAccount()
            }
            let response = client.authenticate(usernameField.stringValue, password: passwordField.stringValue, twoFA: twoFAField.stringValue)
            NSUserDefaults.standardUserDefaults().setObject(usernameField.stringValue, forKey: "accountName")
            print(response)
            if response == YoutubeResponse.Success{
                statusLabel.stringValue = "Success"
                lockInAccount()
            }
            else{
                statusLabel.stringValue = "Failure"
            }
        }
        //Disconnect account
        else{
            NSUserDefaults.standardUserDefaults().removeObjectForKey("accountName")
            client.deauthenticate()
            unlockAccount()
        }
    }
    
    func lockInAccount(){
        resetPasswordField()
        passwordField.enabled = false
        usernameField.enabled = false
        twoFAField.enabled = false
        twoFAField.stringValue = ""
        submitDisconnectButton.title = "Disconnect"
        usernameLabel.textColor = NSColor.disabledControlTextColor()
        passwordLabel.textColor = NSColor.disabledControlTextColor()
        twoFALabel.textColor = NSColor.disabledControlTextColor()
    }
    
    func unlockAccount(){
        passwordField.enabled = true
        passwordField.stringValue = ""
        usernameField.enabled = true
        usernameField.stringValue = ""
        twoFAField.enabled = true
        twoFAField.stringValue = ""
        submitDisconnectButton.title = "Submit"
        usernameLabel.textColor = NSColor.controlTextColor()
        passwordLabel.textColor = NSColor.controlTextColor()
        twoFALabel.textColor = NSColor.controlTextColor()
    }
    
    func resetPasswordField(){
        passwordField.stringValue = "********"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let client = delegate.youtubeClient
        print(client.authenticated)
        print(client)
        if client.authenticated{
            lockInAccount()
            resetPasswordField()
            if let username = NSUserDefaults.standardUserDefaults().valueForKey("accountName"){
                usernameField.stringValue = username as! String
            }
        }
        
        if let outputDir = NSUserDefaults.standardUserDefaults().URLForKey("OutputDirectory") {
            outputDirTextField.stringValue = outputDir.path!
        }
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        return nil
        //TODO: Display list of playlists
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return 0
        //TODO: Return number of playlists
    }
    
}
