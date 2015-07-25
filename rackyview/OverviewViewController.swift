

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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.sharedApplication().setStatusBarStyle(UIStatusBarStyle.LightContent, animated: true)
        raxutils.swingView(self.bellIcon, myRotationDegrees: CGFloat(0.4))
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        raxutils.addBorderAndShadowToView(bigviewbutton)
        if GlobalState.instance.latestAlarmStates != nil {
            initData(GlobalState.instance.latestAlarmStates)
        } else {
            self.refresh()
        }
    }
    
    func updateUI(viewingstate:String, entities:NSMutableArray, viewButtonColor:UIColor, alarmCount:Int) {
        self.viewingState = viewingstate
        self.criticalbutton.setTitle("Critical ("+String(self.criticalEntities.count)+")", forState: UIControlState.Normal)
        self.warningbutton.setTitle("Warning ("+String(self.warningEntities.count)+")", forState: UIControlState.Normal)
        self.okbutton.setTitle("OK ("+String(self.okEntities.count)+")", forState: UIControlState.Normal)
        
        self.bignumberbutton.setTitle(String(entities.count), forState: UIControlState.Normal)
        self.attentionstate.text = "in "+self.viewingState+" state"
        self.bigviewbutton.setTitle("View "+self.viewingState+" Entities", forState: UIControlState.Normal)
        self.bigviewbutton.backgroundColor = viewButtonColor
        raxutils.flashView(self.bigviewbutton)
        raxutils.imageHueFlash(self.bellIcon, myDuration: 1.0, myColor: viewButtonColor)
    
        self.timelastchangehrsmins.text = raxutils.epochToHumanReadableTimeAgo(
            ((entities[0].objectForKey("latest_alarm_states") as! NSArray)[0] as! NSDictionary).objectForKey("timestamp") as! Double)
        self.timelastchangedesc.text = "Newest "+self.viewingState+" event"
        
        self.totalalarmsnumber.text = String(alarmCount)
        self.totalalarmsdesc.text = self.viewingState+" alarms"
        
        self.newestAlarmMessageDesc.text = "Newest "+self.viewingState+" alarm message"
        self.newestAlarmMessageStatus.text = "\"" + (((entities[0].objectForKey("latest_alarm_states") as! NSArray)[0] as! NSDictionary).objectForKey("status") as! String) + "\""
        
        if (viewingstate == "Critical") {
            self.criticalTriangle.hidden = false
            self.warningTriangle.hidden = true
            self.okTriangle.hidden = true
        } else if(viewingstate == "Warning") {
            self.criticalTriangle.hidden = true
            self.warningTriangle.hidden = false
            self.okTriangle.hidden = true
        } else if(viewingstate == "OK") {
            self.criticalTriangle.hidden = true
            self.warningTriangle.hidden = true
            self.okTriangle.hidden = false
        }
    }
    
    func initData(results:NSMutableDictionary!) {
        raxutils.setUIBusy(nil, isBusy: false)
        if results == nil {
            raxutils.reportGenericError(self)
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
            updateUI("Critical",entities:criticalEntities, viewButtonColor:UIColor.redColor(),alarmCount:allCriticalAlarms.count)
        } else if warningEntities.count > 0 && (self.viewingState == "" || self.viewingState == "Warning") {
            updateUI("Warning",entities:warningEntities, viewButtonColor:UIColor.orangeColor(),alarmCount:allWarningAlarms.count)
        } else if okEntities.count > 0 && (self.viewingState == "" || self.viewingState == "OK"){
            updateUI("OK",entities:okEntities, viewButtonColor:UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),alarmCount:allOkAlarms.count)
        } else {
            raxutils.alert("No ok/warn/crit alarms",message:"No alarms ok/warn/crit found on this account so going to the bare minimal homescreen",vc:self,
                onDismiss: { (action:UIAlertAction!) -> Void in
                    var noalarmviewcontroller = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("NoAlarmsViewController") as! NoAlarmsViewController
                    noalarmviewcontroller.unknownEntities = self.unknownEntities.copy() as! NSArray
                    self.presentViewController( UINavigationController(rootViewController: noalarmviewcontroller),
                    animated: true, completion: nil)
            })
            return
        }
    }
    
    @IBAction func refresh() {
        NSOperationQueue.mainQueue().addOperationWithBlock {
            raxutils.setUIBusy(self.view, isBusy: true)
            self.viewingState = ""
            GlobalState.instance.latestAlarmStates = raxAPI.latestAlarmStates(isStreaming: false)
            self.initData(GlobalState.instance.latestAlarmStates)
        }
    }
    
    @IBAction func bigviewbuttonTapped() {
        var entitylistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("EntityListView") as! EntityListViewController
        
        entitylistview.viewingstate = self.viewingState
        
        if(viewingState == "Critical") {
            entitylistview.highestSeverityFoundColor = raxutils.getColorForState("CRIT")
            entitylistview.entities = self.criticalEntities
            entitylistview.keyForArrayInResultDictionary = "criticalEntities"
        }
        if(viewingState == "Warning") {
            entitylistview.highestSeverityFoundColor = raxutils.getColorForState("WARN")
            entitylistview.entities = self.warningEntities
            entitylistview.keyForArrayInResultDictionary = "warningEntities"
        }
        if(viewingState == "OK") {
            entitylistview.highestSeverityFoundColor = raxutils.getColorForState("OK")
            entitylistview.entities = self.okEntities
            entitylistview.keyForArrayInResultDictionary = "okEntities"
        }
        if(entitylistview.entities.count == 0) {
            raxutils.alert("",message:"No Entities are currently "+self.viewingState, vc:self, onDismiss: nil)
            return
        }
        self.presentViewController( UINavigationController(rootViewController: entitylistview),
            animated: true, completion: nil)
    }
    
    @IBAction func onViewSelect(button:UIButton) {
        if(button.tag == 1 && criticalEntities.count > 0) {
            updateUI("Critical",entities:criticalEntities, viewButtonColor:UIColor.redColor(),alarmCount:allCriticalAlarms.count)
        } else if(button.tag == 2 && warningEntities.count > 0) {
            updateUI("Warning",entities:warningEntities, viewButtonColor:UIColor.orangeColor(),alarmCount:allWarningAlarms.count)
        } else if(button.tag == 3 && okEntities.count > 0) {
            updateUI("OK",entities:okEntities, viewButtonColor:UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),alarmCount:allOkAlarms.count)
        }
    }
    
    @IBAction func MiscButtonTapped()
    {
        var miscviewcontroller = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("MiscViewController") as! MiscViewController
        if unknownEntities != nil {
            miscviewcontroller.unknownEntities = unknownEntities.copy() as! NSArray
        }
        self.presentViewController( UINavigationController(rootViewController: miscviewcontroller),
            animated: true, completion: nil)
    }
    
    @IBAction func bellbuttonTapped() {
        var alarmlistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("AlarmListView") as! AlarmListViewController
        
        alarmlistview.viewingstate = viewingState
        
        if(viewingState == "Critical") {
            alarmlistview.alarms = allCriticalAlarms
            alarmlistview.keyForArrayInResultDictionary = "allCriticalAlarms"
            alarmlistview.highestSeverityFoundColor = UIColor.redColor()
        }
        if(viewingState == "Warning") {
            alarmlistview.alarms = allWarningAlarms
            alarmlistview.keyForArrayInResultDictionary = "allWarningAlarms"
            alarmlistview.highestSeverityFoundColor = UIColor.orangeColor()
        }
        if(viewingState == "OK") {
            alarmlistview.alarms = allOkAlarms
            alarmlistview.keyForArrayInResultDictionary = "allOkAlarms"
            alarmlistview.highestSeverityFoundColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        }
        
        if(alarmlistview.alarms.count == 0) {
            raxutils.alert("",message:"No Alarms are "+self.viewingState+" state", vc:self, onDismiss: nil)
            return
        }
    
        
        alarmlistview.title = "All "+self.viewingState+" alarms"
        
        self.presentViewController(UINavigationController(rootViewController: alarmlistview),
            animated: true, completion: {
                    (self.presentedViewController as! UINavigationController).interactivePopGestureRecognizer.enabled = false
            })
    }
    
    @IBAction func serverButtonTapped() {
        if(GlobalState.instance.serverlistview == nil) {
            GlobalState.instance.serverlistview = UIStoryboard(name:"Main",bundle:nil)
                .instantiateViewControllerWithIdentifier("ServerListView") as! ServerListViewController
        }
        self.presentViewController(UINavigationController(rootViewController: GlobalState.instance.serverlistview), animated: true, completion: nil)
    }
}
