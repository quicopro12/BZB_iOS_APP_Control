//  SettingsViewController
//
//  Created by Wilson on 2021/03/31.
//  Copyright © 2021 gomax. All rights reserved.
//

import UIKit
import SwiftSocket
import CocoaAsyncSocket
import RSSelectionMenu
import CryptoKit
import CryptoSwift
import Foundation
import Toast_Swift
import SVProgressHUD
import SwiftyJSON
import RSSelectionMenu

class SettingsViewController: BaseViewController{
    
    
    @IBOutlet weak var btScanHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var btScanWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var btScan: UIButton!
    @IBOutlet weak var textFieldDeviceIP: UITextField!
    @IBOutlet weak var textFieldDeviceType: UITextField!
    @IBOutlet weak var appVerLabel: UILabel!
    @IBOutlet weak var btADD: UIButton!
    
    let preferences = UserDefaults.standard
    var queueReceiveUDP: DispatchQueue!
    var queueSendUDP: DispatchQueue!
    var udpSendSocket: UDPClient!
    var udpReceiveSocket: GCDAsyncUdpSocket!
    var deviceList: Array<Device> = []
    var menu: RSSelectionMenu<String>!
    var menuList: Array<String> = []
    let db = DBHelper()
    //device info structure (mac & ip)
    struct Device {
        let name: String
        let mac: String
        let ip: String
    }
    
    override func viewDidLoad() {
        print("SettingsViewController-viewDidLoad")
        super.viewDidLoad()
        initialUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("SettingsViewController-viewWillAppear")
        objectInitial()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("SettingsViewController-viewDidDisappear")
        self.queueReceiveUDP.async {
            
            if(self.udpSendSocket != nil){
                self.udpSendSocket.close()
            }
            if(self.udpReceiveSocket != nil){
                self.udpReceiveSocket.close()
            }
        }
    }
    
}

extension SettingsViewController{
    
    //initial UI
    func initialUI(){
        
        self.btADD.layer.cornerRadius = 5
        self.btADD.layer.borderWidth = 1
        self.btADD.layer.borderColor = UIColor.black.cgColor
        
        if(SettingsViewController.isPhone){
            //bt scan size
            let newbtScanHeightConstraint = btScanHeightConstraint.constraintWithMultiplier(0.05)
            self.view.removeConstraint(btScanHeightConstraint)
            self.view.addConstraint(newbtScanHeightConstraint)
           // self.view.layoutIfNeeded()
            let newbtScanWidthConstraint = btScanWidthConstraint.constraintWithMultiplier(0.12)
            self.view.removeConstraint(btScanWidthConstraint)
            self.view.addConstraint(newbtScanWidthConstraint)
            self.view.layoutIfNeeded()
        }else{
            //bt scan size
            let newbtScanHeightConstraint = btScanHeightConstraint.constraintWithMultiplier(0.05)
            self.view.removeConstraint(btScanHeightConstraint)
            self.view.addConstraint(newbtScanHeightConstraint)
            //self.view.layoutIfNeeded()
            let newbtScanWidthConstraint = btScanWidthConstraint.constraintWithMultiplier(0.08)
            self.view.removeConstraint(btScanWidthConstraint)
            self.view.addConstraint(newbtScanWidthConstraint)
            self.view.layoutIfNeeded()
        }

        //App version
        let dictionary = Bundle.main.infoDictionary!
        let appVersion = dictionary["CFBundleShortVersionString"] as! String
        self.appVerLabel.text = "APP Ver. " + appVersion
        
        if(!SettingsViewController.isPhone){
            //Scan button
            let widthConstraint = self.btScan.widthAnchor.constraint(equalToConstant: 30.0)
            let heightConstraint = btScan.heightAnchor.constraint(equalToConstant: 30.0)
            NSLayoutConstraint.activate([widthConstraint, heightConstraint])
            //change button size to 50x50
            widthConstraint.constant = 10
            heightConstraint.constant = 10
            
            self.textFieldDeviceIP.frame.size.height = 500
            self.textFieldDeviceType.frame.size.height = 500
        }
        
    }
    
    func objectInitial(){
        self.queueReceiveUDP = DispatchQueue(label: "com.bzb.receive.udp", qos: DispatchQoS.userInitiated)
        self.queueReceiveUDP = DispatchQueue(label: "com.bzb.send.udp", qos: DispatchQoS.userInitiated)
        self.udpReceiveSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        
        self.queueReceiveUDP.async {
            do {
                self.udpReceiveSocket.setIPv4Enabled(true)
                self.udpReceiveSocket.setIPv6Enabled(false)
                try self.udpReceiveSocket.bind(toPort: 65088)
                try self.udpReceiveSocket.beginReceiving()
                print("socket create successful")
            } catch let error {
                print(error)
            }
            self.udpSendSocket = UDPClient.init(address: "255.255.255.255", port: 5002)
            self.udpSendSocket.enableBroadcast()
        }
        
    }
    
    @IBAction func btAdd(sender: UIButton) {
        
        DispatchQueue.main.async() {
            self.showLoadingView()
        }
        
        var type = 0;
        
        var dbSize = self.db.getDBSize()
        print("db size = \(dbSize)")
        
        if(dbSize >= 10){
            self.showToast(context: "Can only store up to 20 devices !")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.dismissLoadingView()
            }
        }else{
            var feedback = false
            var ip = self.textFieldDeviceIP.text!
            self.queueReceiveUDP.async {
                feedback = self.db.queryByIP(ip:ip)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if(!feedback){
                    if(self.getDeviceTypeNumberByName(deviceName: self.textFieldDeviceType.text!) > 0){
                        var feedback = self.db.insert(type: self.getDeviceTypeNumberByName(deviceName: self.textFieldDeviceType.text!), ip: self.textFieldDeviceIP.text!, name: self.textFieldDeviceType.text!)
                        if(feedback){
                            self.showToast(context: "Add successfull !")
                        }else{
                            self.showToast(context: "Add failed !")
                        }
                    }else{
                        self.showToast(context: "Please scan device first !")
                    }
                }else{
                    self.showToast(context: "This IP is exist !")
                }
                self.dismissLoadingView()
            }
        }
    }
}

extension SettingsViewController{
    
    @IBAction func sendUDP(sender: UIButton) {
        
        let queueUDP = DispatchQueue(label: "com.bzb.udp", qos: DispatchQoS.userInitiated)
        
        queueUDP.async {
            self.deviceList.removeAll()
            self.menuList.removeAll()
            
            self.showLoadingView()
            
            self.udpSendSocket.send(data: self.aesEncodeUDPCmd())
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { // Change `2.0` to the desired number of seconds.
                if(self.deviceList.count > 0){
                    self.dismissLoadingView()
                    
                    DispatchQueue.main.async(){
                        //  self.dismissLoadingView()
                        var selectedNames: [String] = []
                        // create menu with data source -> here [String]
                        
                        for deviceInfo in self.deviceList{
                            self.menuList.append( deviceInfo.name + "\n" + deviceInfo.mac + "\n" + deviceInfo.ip)
                        }
                        
                        self.menu = RSSelectionMenu(dataSource: self.menuList) { (cell, name, indexPath) in
                            cell.textLabel?.text = name
                            if(!SettingsViewController.isPhone){
                                cell.textLabel?.font = UIFont.systemFont(ofSize: 24)
                            }
                        }
                        // provide selected items
                        self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
                            selectedNames = selectedItems
                            
                            print(self.deviceList[index])
                            
                            let selectedDevice   = self.deviceList[index]
                            self.textFieldDeviceIP.text = selectedDevice.ip
                            self.textFieldDeviceType.text = selectedDevice.name
                            self.preferences.set(selectedDevice.ip, forKey: CmdHelper.key_server_ip)
                        }
                        self.menu.show(from: self)
                    }
                    
                }else{
                    DispatchQueue.main.async {
                        self.dismissLoadingView()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.showAlert(message: "Can't find any devices")
                    }
                }
                print("times up")
            }
            
        }
    }
    
    //encode udp cmd
    func aesEncodeUDPCmd() -> [Byte]{
        var aes = [Byte]()
        do {
            let key = "qzy159pkn333rty2"
            let key1:Array<Byte> = [0x00, 0x0b, 0x80, 0x00, 0x45, 0x54, 0x48, 0x5f, 0x52, 0x45, 0x51, 0x00, 0x00,0x00,0x00,0x00]
            //use AES-128-ECB mode
            aes = try AES(key: key.bytes, blockMode: ECB(), padding: .noPadding).encrypt(key1)
        } catch {}
        
        return aes
    }
    
    //deocode udp feedback
    func aesDecode(data: Data) -> [Byte]{
        var aes = [Byte]()
        do {
            let key = "qzy159pkn333rty2"
            //use AES-128-ECB mode
            aes = try AES(key: key.bytes, blockMode: ECB(), padding: .noPadding).decrypt(data.bytes)
        } catch {}
        
        return aes
    }
}

extension SettingsViewController: GCDAsyncUdpSocketDelegate{
    
    //****** UDP ******
    private func udpSocket(sock: GCDAsyncUdpSocket!, didConnectToAddress address: NSData!) {
        print("didConnectToAddress");
    }
    
    private func udpSocket(sock: GCDAsyncUdpSocket!, didNotConnect error: NSError!) {
        print("didNotConnect \(String(describing: error))")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        print("didSendDataWithTag")
    }
    
    private func udpSocket(sock: GCDAsyncUdpSocket!, didNotSendDataWithTag tag: Int, dueToError error: NSError!) {
        print("didNotSendDataWithTag")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        if(data != nil){
            
            var deviceInfo = aesDecode(data: data)
            
            if(deviceInfo.count > 0){
                print("receive")
                var deviceName = ""
                for index in 5...20{
                    deviceName = deviceName + String(format: "%c", deviceInfo[index])
                }
                
                let resultA = deviceName.contains("Matrix 4x4 HDR")
                let resultB = deviceName.contains("Control-Box")
                
                if(resultA || resultB){
                    self.deviceList.append(Device(name: deviceName, mac: String(format:"%02X", deviceInfo[21]) + "-" + String(format:"%02X", deviceInfo[22]) + "-" + String(format:"%02X", deviceInfo[23]) + "-" + String(format:"%02X", deviceInfo[24]) + "-" + String(format:"%02X", deviceInfo[25]) + "-" + String(format:"%02X", deviceInfo[26]),ip: String(deviceInfo[27]) + "." + String(deviceInfo[28]) + "." + String(deviceInfo[29]) + "." + String(deviceInfo[30])))
                }
            }
        }
    }
}
