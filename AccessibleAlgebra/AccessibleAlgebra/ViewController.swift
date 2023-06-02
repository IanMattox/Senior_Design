//
//  ViewController.swift
//  ESP32Connection
//
//  Created by Loaner on 4/26/23.
//

import UIKit
import CoreBluetooth
import WebKit

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let espServ = "b0c43b43-7026-4d99-be83-4945b2e33b6f"
    let espChar = "79f8a643-66bb-430b-ab16-41d1a23999e3"
    let teachServ = "03f528d0-c011-432d-8bd0-45347e3ef095"
    let teachChar = "9dcb19b7-bcfd-492a-9128-9b25b4293c97"
    
    @IBOutlet weak var stepsView: WKWebView!
    @IBOutlet weak var ConnectStatus: UILabel!
    @IBOutlet weak var TeachStatus: UILabel!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var equationView: WKWebView!
    
    var centralManager: CBCentralManager!
    var ESP32Peripheral: CBPeripheral!
    var ESP32Characteristic: CBCharacteristic!
    var TeacherPeripheral: CBPeripheral!
    var TeacherCharacteristic: CBCharacteristic!
    var solutionSteps :[String] = []
    
    var teacherConnected = false
    var displayConnected = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let servs = [CBUUID(string: "b0c43b43-7026-4d99-be83-4945b2e33b6f"),CBUUID(string: "03f528d0-c011-432d-8bd0-45347e3ef095")]
        
        switch central.state {
        case .poweredOn:
            print("Bluetooth is on")
            print("Scanning for Peripherals...")
            central.scanForPeripherals(withServices: servs, options: nil)
        default:
            print("Bluetooth is not available")
        }
        
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Found peripheral: \(peripheral)")
        let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        print(peripheralName as Any)
        
        //TODO CHECK number of connections ==2
        if peripheral.name?.starts(with: "BIT_ESP32") == true {
            self.centralManager.stopScan()
            self.ESP32Peripheral = peripheral
            self.ESP32Peripheral.delegate = self
            self.centralManager.connect(self.ESP32Peripheral)
        } else if (peripheralName == "Teacher"){
            self.centralManager.stopScan()
            self.TeacherPeripheral = peripheral
            self.TeacherPeripheral.delegate = self
            self.centralManager.connect(self.TeacherPeripheral)
        }
    }

    //Discover Service after Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //print("Connected to peripheral: \(peripheral)")
        //self.ESP32Peripheral.discoverServices([CBUUID(string: "b0c43b43-7026-4d99-be83-4945b2e33b6f")])
        
        if peripheral == ESP32Peripheral {
            print("Connected to ESP32Peripheral: \(peripheral)")
            peripheral.discoverServices([CBUUID(string: "b0c43b43-7026-4d99-be83-4945b2e33b6f")])
            //Updates UI label when connected to peripheral
            DispatchQueue.main.async { [weak self] in
                self?.ConnectStatus!.text = "Connected"
                self?.ConnectStatus.textColor = UIColor.systemGreen
            }
        } else if peripheral == TeacherPeripheral {
            print("Connected to TeacherPeripheral: \(peripheral)")
            peripheral.discoverServices([CBUUID(string: "03f528d0-c011-432d-8bd0-45347e3ef095")])
            //TODO indicator that it is connected
            DispatchQueue.main.async { [weak self] in
                self?.TeachStatus!.text = "Ready"
                self?.TeachStatus.textColor = UIColor.systemGreen
            }
        }
    }

    //Discover Characteristic after discovering service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        for service in services {
            print("Service found: \(service)")
            
            if service.uuid == CBUUID(string: "b0c43b43-7026-4d99-be83-4945b2e33b6f") {
                print("ESP32 service found")
                // Perform actions specific to the ESP32 service
                peripheral.discoverCharacteristics([CBUUID(string: "79f8a643-66bb-430b-ab16-41d1a23999e3")], for: service)
            } else if service.uuid == CBUUID(string: "03f528d0-c011-432d-8bd0-45347e3ef095") {
                print("Teacher service found")
                // Perform actions specific to the Teacher service
                peripheral.discoverCharacteristics([CBUUID(string: "9dcb19b7-bcfd-492a-9128-9b25b4293c97")], for: service)
            }
        }
    }

    //When characteristic is discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        for characteristic in characteristics {
            print("Characteristic found: \(characteristic)")
            if characteristic.uuid == CBUUID(string: "79f8a643-66bb-430b-ab16-41d1a23999e3") {
                self.ESP32Characteristic = characteristic
                ESP32Peripheral.setNotifyValue(true, for: characteristic)
                displayConnected = true
                
            } else if characteristic.uuid == CBUUID(string: "9dcb19b7-bcfd-492a-9128-9b25b4293c97") {
                self.TeacherCharacteristic = characteristic
                TeacherPeripheral.setNotifyValue(true, for: characteristic)
                teacherConnected = true
            }
        }
        
        if(!teacherConnected || !displayConnected){
            scanAfterDC()
        }
    }

    //****** Send Equation Function *****//
    @IBAction func sendMessage(_ sender: Any) {
        
        guard let message = self.messageTextView.text else {
            return
        }
        guard let data = message.data(using: .utf8) else {
            return
        }
        
        if ConnectStatus.text == "Connected" {
            print("Message Sending...")
            self.ESP32Peripheral.writeValue(data, for: self.ESP32Characteristic, type: .withResponse)
            print("Message Sent: ",message)
            messageTextView.resignFirstResponder() //Closes Keypad after send
            
            displayNewStep(msg: message)
            let htmlStr = formatHTML(msg: message)
            DispatchQueue.main.async { [weak self] in
                self?.equationView.loadHTMLString(htmlStr, baseURL:nil)}
            
            UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: self.equationView)
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: self.equationView)
            
        } else{
            print("No connected Peripheral\n")
            let htmlStr = formatHTML(msg: message)
            displayNewStep(msg: message)
            
            DispatchQueue.main.async { [weak self] in
                self?.equationView.loadHTMLString(htmlStr, baseURL:nil)
                print("Displayed\n")
            }
            messageTextView.resignFirstResponder() //Closes Keypad after send
            alertWhenInvalid()

            scanAfterDC()
        }
    }
    
    //***** Send Reset Function *****//
    @IBAction func sendRST(_ sender: Any) {
        let msg = "RESET"
        guard let data = msg.data(using: .utf8) else{
            return
        }
        if ConnectStatus.text == "Connected"{
            print("RESET Request Sent")
            self.ESP32Peripheral.writeValue(data, for: self.ESP32Characteristic, type: .withResponse)
        } else{
            alertWhenInvalid()
            print("Can only RESET when connected")
        }

    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            return
        }
        guard let message = String(data: data, encoding: .utf8) else {
            return
        }
        
        if peripheral == ESP32Peripheral {
            print("Received message from ESP: \(message) ")
        } else if peripheral == TeacherPeripheral {
            print("Received message from Teacher: \(message)")
            let htmlStr = formatHTML(msg: message)
            DispatchQueue.main.async { [weak self] in
                self?.equationView.loadHTMLString(htmlStr, baseURL:nil)}
            DispatchQueue.main.async { [weak self] in
                self?.messageTextView.text = message }
        }
    }
    
    //Disconnection Handler
    //Update Connection Indication Label
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        if peripheral == ESP32Peripheral {
              print("ESP32Peripheral disconnected")
            DispatchQueue.main.async { [weak self] in
                self?.ConnectStatus!.text = "Disconnected"
                self?.ConnectStatus.textColor = UIColor.systemRed
                self?.displayConnected = false
            }
        } else if peripheral == TeacherPeripheral {
              print("TeacherPeripheral disconnected")
              DispatchQueue.main.async { [weak self] in
                  self?.TeachStatus!.text = "Disconnected"
                  self?.TeachStatus.textColor = UIColor.systemRed
                  self?.teacherConnected = false
              }
        } else {
              print("Unknown peripheral disconnected")
        }
          
        if let error = error {
              print("Peripheral disconnected with error: \(error.localizedDescription)")
        } else {
              print("Peripheral disconnected")
        }
          
        scanAfterDC()
    }
    
    func scanAfterDC(){
        
        if(!teacherConnected){
            print("Scanning for Teacher...")
            centralManager.scanForPeripherals(withServices: [CBUUID(string:"03f528d0-c011-432d-8bd0-45347e3ef095")], options: nil)
        } else if(!displayConnected){
            print("Scanning for Device...")
            centralManager.scanForPeripherals(withServices: [CBUUID(string:"b0c43b43-7026-4d99-be83-4945b2e33b6f")], options: nil)
        }
        
        //print("Scanning for Peripherals...")
        //centralManager.scanForPeripherals(withServices: [CBUUID(string:"b0c43b43-7026-4d99-be83-4945b2e33b6f")], options: nil)
        //TODO: remove characterisitc and service
    }
     
    @IBAction func powerDown(_ sender: Any) {
        let msg = "OFF"
        guard let data = msg.data(using: .utf8) else{
            return
        }
        if ConnectStatus.text == "Connected"{
            print("Power Done Request Sent")
            print(data)
            self.ESP32Peripheral.writeValue(data, for: self.ESP32Characteristic, type: .withResponse)
        } else{
            alertWhenInvalid()
            print("Can only Power Off when Connected")
        }
    }
    //HTML and LaTeX format strings
    func formatHTML(msg: String) -> String {
        let htmlStart = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <title>HTML Shenanigans</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.1/css/bootstrap.min.css">
      <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.4/jquery.min.js"></script>
      <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.1/js/bootstrap.min.js"></script>
      <script type="text/x-mathjax-config">
        MathJax.Hub.Config({tex2jax: {inlineMath: [['$','$'], ['\\(','\\)']]}});</script>
      <script type="text/javascript"
        src="http://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
      </script>
    </head>
    <body>
    <div class="jumbotron text-center">
"""
        
        let equation = "<p>$"+msg+"$</p>"
        let htmlEnd = """
    </div>
    </body>
    </html>
"""
        let formattedString = htmlStart+equation+htmlEnd
        return formattedString
    }
    
    func alertWhenInvalid(){
        let alertController = UIAlertController(title: "No Device Found", message: "Turn on/Reset Device", preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    //********** Display New Steps **********//
    func displayNewStep(msg: String){
        solutionSteps.insert(msg, at: 0)
        
        let htmlStart = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <title>HTML Shenanigans</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.1/css/bootstrap.min.css">
      <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.4/jquery.min.js"></script>
      <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.1/js/bootstrap.min.js"></script>
      <script type="text/x-mathjax-config">
        MathJax.Hub.Config({tex2jax: {inlineMath: [['$','$'], ['\\(','\\)']]}});</script>
      <script type="text/javascript"
        src="http://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
      </script>
    </head>
    <body>
    <div class="jumbotron text-center">
    """
     
        let htmlEnd = """
    </div>
    </body>
    </html>
    """
        var steps = ""
        
        for i in 0...2{
            if(i < solutionSteps.count){
                steps = steps+"<p>$"+solutionSteps[i]+"$<p>"
            } else{
                steps = steps+"<p>$ $<p>"
            }
        }
        let stepsToDisplay = htmlStart+steps+htmlEnd
        DispatchQueue.main.async { [weak self] in
            self?.stepsView.loadHTMLString(stepsToDisplay, baseURL:nil)}
    }
    @IBAction func submitFinalAnswer(_ sender: Any) {
        guard let message = self.messageTextView.text else {
            return
        }
        guard let data = message.data(using: .utf8) else {
            return
        }
        
        if teacherConnected {
            print("Message Sending...")
            self.TeacherPeripheral.writeValue(data, for: self.TeacherCharacteristic, type: .withResponse)
            self.TeacherPeripheral.writeValue(data, for: self.TeacherCharacteristic, type: .withoutResponse)
            print("Message Sent: ",message)
            messageTextView.resignFirstResponder() //Closes Keypad after send
            
        }
        
    }
    
    
}




