

import UIKit
import Foundation

class OverviewViewController: UIViewController {
    
    @IBOutlet var topTitleLabel:UILabel!
    
    @IBOutlet var bignumberbutton:UIButton!
    @IBOutlet var criticalbutton:UIButton!
    @IBOutlet var warningbutton:UIButton!
    @IBOutlet var okbutton:UIButton!
    @IBOutlet var attentionstate:UILabel!
    @IBOutlet var bigviewbutton:UIButton!
    
    @IBOutlet var totalalarmsnumber:UILabel!
    @IBOutlet var totalalarmsdesc:UILabel!
    @IBOutlet var bellButton:UIButton!
    @IBOutlet var bellIcon:UIImageView!
    
    @IBOutlet var timelastchangehrsmins:UILabel!
    @IBOutlet var timelastchangedesc:UILabel!
    
    @IBOutlet var newestAlarmMessageStatus:UILabel!
    @IBOutlet var newestAlarmMessageDesc:UILabel!
    
    @IBOutlet var criticalTriangle:UIImageView!
    @IBOutlet var warningTriangle:UIImageView!
    @IBOutlet var okTriangle:UIImageView!
    
    var unknownEntities:NSMutableArray!
    var criticalEntities:NSMutableArray!
    var warningEntities:NSMutableArray!
    var okEntities:NSMutableArray!
    
    var allUnknownAlarms:NSMutableArray!
    var allCriticalAlarms:NSMutableArray!
    var allWarningAlarms:NSMutableArray!
    var allOkAlarms:NSMutableArray!
    var viewingState:String = ""
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        raxutils.swingView(v: self.bellIcon, myRotationDegrees: CGFloat(0.4))
    }
    
    override var preferredStatusBarStyle:UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        raxutils.addBorderAndShadowToView(v: bigviewbutton)
        if GlobalState.instance.latestAlarmStates != nil {
            initData(results: GlobalState.instance.latestAlarmStates)
        } else {
            self.refresh()
        }
    }
    
    func updateUI(viewingstate:String, entities:NSMutableArray, viewButtonColor:UIColor, alarmCount:Int) {
        self.viewingState = viewingstate
        self.criticalbutton.setTitle("Critical ("+String(self.criticalEntities.count)+")", for: UIControlState.normal)
        self.warningbutton.setTitle("Warning ("+String(self.warningEntities.count)+")", for: UIControlState.normal)
        self.okbutton.setTitle("OK ("+String(self.okEntities.count)+")", for: UIControlState.normal)
        
        self.bignumberbutton.setTitle(String(entities.count), for: UIControlState.normal)
        self.attentionstate.text = "in "+self.viewingState+" state"
        self.bigviewbutton.setTitle("View "+self.viewingState+" Entities", for: UIControlState.normal)
        self.bigviewbutton.backgroundColor = viewButtonColor
        raxutils.flashView(v: self.bigviewbutton)
        raxutils.imageHueFlash(myImageView: self.bellIcon, myDuration: 1.0, myColor: viewButtonColor)
    
        self.timelastchangehrsmins.text = raxutils.epochToHumanReadableTimeAgo(
            epochTime: (((entities[0] as! NSDictionary)["latest_alarm_states"] as! NSArray)[0] as! NSDictionary)["timestamp"] as! Double)
        self.timelastchangedesc.text = "Newest "+self.viewingState+" event"
        
        self.totalalarmsnumber.text = String(alarmCount)
        self.totalalarmsdesc.text = self.viewingState+" alarms"
        
        self.newestAlarmMessageDesc.text = "Newest "+self.viewingState+" alarm message"
        self.newestAlarmMessageStatus.text = "\"" + ((((entities[0] as! NSDictionary)["latest_alarm_states"] as! NSArray)[0] as! NSDictionary)["status"] as! String) + "\""
        
        if (viewingstate == "Critical") {
            self.criticalTriangle.isHidden = false
            self.warningTriangle.isHidden = true
            self.okTriangle.isHidden = true
        } else if(viewingstate == "Warning") {
            self.criticalTriangle.isHidden = true
            self.warningTriangle.isHidden = false
            self.okTriangle.isHidden = true
        } else if(viewingstate == "OK") {
            self.criticalTriangle.isHidden = true
            self.warningTriangle.isHidden = true
            self.okTriangle.isHidden = false
        }
    }
    
    func initData(results:NSMutableDictionary!) {
        raxutils.setUIBusy(v: nil, isBusy: false)
        if results == nil {
            raxutils.reportGenericError(vc: self)
            return
        }
        unknownEntities = results["unknownEntities"] as! NSMutableArray
        criticalEntities = results["criticalEntities"] as! NSMutableArray
        warningEntities = results["warningEntities"] as! NSMutableArray
        okEntities = results["okEntities"] as! NSMutableArray
        allUnknownAlarms = results["allUnknownAlarms"] as! NSMutableArray
        allCriticalAlarms = results["allCriticalAlarms"] as! NSMutableArray
        allWarningAlarms = results["allWarningAlarms"] as! NSMutableArray
        allOkAlarms = results["allOkAlarms"] as! NSMutableArray
        
        if criticalEntities.count == 0 && self.viewingState == "Critical" {
            self.viewingState = ""
        }
        if warningEntities.count == 0 && self.viewingState == "Warning" {
            self.viewingState = ""
        }
        if okEntities.count == 0 && self.viewingState == "OK" {
            self.viewingState = ""
        }
        if criticalEntities.count > 0 && (self.viewingState == "" || self.viewingState == "Critical") {
            updateUI(viewingstate: "Critical",entities:criticalEntities, viewButtonColor:UIColor.red,alarmCount:allCriticalAlarms.count)
        } else if warningEntities.count > 0 && (self.viewingState == "" || self.viewingState == "Warning") {
            updateUI(viewingstate: "Warning",entities:warningEntities, viewButtonColor:UIColor.orange,alarmCount:allWarningAlarms.count)
        } else if okEntities.count > 0 && (self.viewingState == "" || self.viewingState == "OK"){
            updateUI(viewingstate: "OK",entities:okEntities, viewButtonColor:UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),alarmCount:allOkAlarms.count)
        } else {
            raxutils.alert(title: "No ok/warn/crit alarms",message:"No alarms ok/warn/crit found on this account so going to the bare minimal homescreen",vc:self,
                onDismiss: { (action:UIAlertAction!) -> Void in
                    let noalarmviewcontroller = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "NoAlarmsViewController") as! NoAlarmsViewController
                    noalarmviewcontroller.unknownEntities = self.unknownEntities.copy() as! NSArray
                    self.present(UINavigationController(rootViewController: noalarmviewcontroller), animated: true, completion: nil)
            })
            return
        }
    }
    
    @IBAction func refresh() {
        OperationQueue.main.addOperation {
            raxutils.setUIBusy(v: self.view, isBusy: true)
            self.viewingState = ""
            GlobalState.instance.latestAlarmStates = raxAPI.latestAlarmStates(isStreaming: false)
            self.initData(results: GlobalState.instance.latestAlarmStates)
        }
    }
    
    @IBAction func bigviewbuttonTapped() {
        let entitylistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "EntityListView") as! EntityListViewController
        
        entitylistview.viewingstate = self.viewingState
        
        if(viewingState == "Critical") {
            entitylistview.highestSeverityFoundColor = raxutils.getColorForState(state: "CRIT")
            entitylistview.entities = self.criticalEntities
            entitylistview.keyForArrayInResultDictionary = "criticalEntities"
        }
        if(viewingState == "Warning") {
            entitylistview.highestSeverityFoundColor = raxutils.getColorForState(state: "WARN")
            entitylistview.entities = self.warningEntities
            entitylistview.keyForArrayInResultDictionary = "warningEntities"
        }
        if(viewingState == "OK") {
            entitylistview.highestSeverityFoundColor = raxutils.getColorForState(state: "OK")
            entitylistview.entities = self.okEntities
            entitylistview.keyForArrayInResultDictionary = "okEntities"
        }
        if(entitylistview.entities.count == 0) {
            raxutils.alert(title: "",message:"No Entities are currently "+self.viewingState, vc:self, onDismiss: nil)
            return
        }
        self.present( UINavigationController(rootViewController: entitylistview), animated: true, completion: nil)
    }
    
    @IBAction func onViewSelect(_ button:UIButton) {
        if(button.tag == 1 && criticalEntities.count > 0) {
            updateUI(viewingstate: "Critical",entities:criticalEntities, viewButtonColor:UIColor.red,alarmCount:allCriticalAlarms.count)
        } else if(button.tag == 2 && warningEntities.count > 0) {
            updateUI(viewingstate: "Warning",entities:warningEntities, viewButtonColor:UIColor.orange,alarmCount:allWarningAlarms.count)
        } else if(button.tag == 3 && okEntities.count > 0) {
            updateUI(viewingstate: "OK",entities:okEntities, viewButtonColor:UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),alarmCount:allOkAlarms.count)
        }
    }
    
    @IBAction func MiscButtonTapped()
    {
        let miscviewcontroller = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "MiscViewController") as! MiscViewController
        if unknownEntities != nil {
            miscviewcontroller.unknownEntities = unknownEntities.copy() as! NSArray
        }
        self.present(UINavigationController(rootViewController: miscviewcontroller), animated: true, completion: nil)
    }
    
    @IBAction func bellbuttonTapped() {
        let alarmlistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "AlarmListView") as! AlarmListViewController
        
        alarmlistview.viewingstate = viewingState
        
        if(viewingState == "Critical") {
            alarmlistview.alarms = allCriticalAlarms
            alarmlistview.keyForArrayInResultDictionary = "allCriticalAlarms"
            alarmlistview.highestSeverityFoundColor = UIColor.red
        }
        if(viewingState == "Warning") {
            alarmlistview.alarms = allWarningAlarms
            alarmlistview.keyForArrayInResultDictionary = "allWarningAlarms"
            alarmlistview.highestSeverityFoundColor = UIColor.orange
        }
        if(viewingState == "OK") {
            alarmlistview.alarms = allOkAlarms
            alarmlistview.keyForArrayInResultDictionary = "allOkAlarms"
            alarmlistview.highestSeverityFoundColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        }
        
        if(alarmlistview.alarms.count == 0) {
            raxutils.alert(title: "",message:"No Alarms are "+self.viewingState+" state", vc:self, onDismiss: nil)
            return
        }
    
        
        alarmlistview.title = "All "+self.viewingState+" alarms"
        
        self.present(UINavigationController(rootViewController: alarmlistview),
            animated: true, completion: {
                (self.presentedViewController as! UINavigationController).interactivePopGestureRecognizer!.isEnabled = false
            })
    }
    
    @IBAction func serverButtonTapped() {
        if(GlobalState.instance.serverlistview == nil) {
            GlobalState.instance.serverlistview = UIStoryboard(name:"Main",bundle:nil)
                .instantiateViewController(withIdentifier: "ServerListView") as! ServerListViewController
        }
        self.present(UINavigationController(rootViewController: GlobalState.instance.serverlistview), animated: true, completion: nil)
    }
}
