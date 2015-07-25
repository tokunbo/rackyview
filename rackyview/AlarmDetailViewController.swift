

import Foundation
import UIKit

class AlarmDetailViewController: UIViewController {
    var alarm:NSMutableDictionary! = nil
    var testalarmpostdata:NSMutableDictionary! = nil
    var notificationPlanLabel:UILabel!
    var alarmCriteriaTextView:UITextView!
    var insetsChanged:Bool = false
    
    @IBAction func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.title = alarm["alarm_label"] as! NSString as String
        notificationPlanLabel = self.view.viewWithTag(1) as! UILabel
        alarmCriteriaTextView = self.view.viewWithTag(2) as! UITextView
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "details", style: UIBarButtonItemStyle.Plain, target: self, action: "details")
        raxutils.setUIBusy(self.parentViewController?.view, isBusy: true)
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: Selector("dismissKeyboard")))
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardAppearanceEvent:", name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardAppearanceEvent:", name: UIKeyboardDidHideNotification, object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        NSOperationQueue().addOperationWithBlock {
            self.alarm = raxAPI.getAlarm(self.alarm["entity_id"] as! NSString as String, alarmID: self.alarm["alarm_id"] as! NSString as String)
            if self.alarm == nil {
                raxutils.reportGenericError(self)
                return
            }
            var notificationplanDetails:NSDictionary! = raxAPI.getNotificationPlan(self.alarm["notification_plan_id"] as! NSString as String)
            if notificationplanDetails == nil {
                raxutils.reportGenericError(self)
                return
            }
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.notificationPlanLabel.text = "Notification Plan: "+((notificationplanDetails["label"] as! NSString) as String)
                self.alarmCriteriaTextView.text = (self.alarm["criteria"] as! NSString) as String
                raxutils.setUIBusy(nil, isBusy: false)
            }
        }
    }
    
    func details() {
        var entity:NSDictionary!
        var check:NSDictionary!
        var responsedata:String = ""
        raxutils.setUIBusy(self.parentViewController?.view, isBusy: true, expectingSignificantLoadTime: true)
        NSOperationQueue().addOperationWithBlock {
            check = raxAPI.getCheck(self.alarm["entity_id"] as! NSString as String, checkid: self.alarm["check_id"] as! NSString as String)
            if check == nil {
                raxutils.reportGenericError(self)
                return
            }
            entity = raxAPI.getEntity(self.alarm["entity_id"] as! NSString as String)
            if entity == nil {
                raxutils.reportGenericError(self)
                return
            }
            if (check != nil && entity != nil) {
                responsedata = "Entity Label: "
                responsedata += entity["label"] as! NSString as String
                responsedata += "\nCheck Label: "
                responsedata += check["label"] as! NSString as String
                responsedata += "\nAlarm Label: "
                responsedata += self.title as NSString! as String!
                responsedata += "\n---------------------------------\n"
                responsedata += "\n\nEntity Details___________________\n\n"
                responsedata += raxutils.dictionaryToJSONstring(entity)
                responsedata += "\n\nCheck Details____________________\n\n"
                responsedata += raxutils.dictionaryToJSONstring(check)
                responsedata += "\n\nAlarm Details____________________\n\n"
                responsedata += raxutils.dictionaryToJSONstring(self.alarm)
                raxutils.confirmDialog("Details of this alarm, its check and Entity.\nCopy this info to clipboard?", message: responsedata, vc: self,
                    cancelAction:{ (action:UIAlertAction!) -> Void in
                        return
                    },
                    okAction:{ (action:UIAlertAction!) -> Void in
                        UIPasteboard.generalPasteboard().string = responsedata
                    })
            }
            raxutils.setUIBusy(nil, isBusy: false)
        }
    }
    
    @IBAction func testAlarm() {
        self.view.endEditing(true)
        raxutils.setUIBusy(self.parentViewController?.view, isBusy: true, expectingSignificantLoadTime: true)
        alarm["criteria"] = (self.view.viewWithTag(2) as! UITextView).text.stringByReplacingOccurrencesOfString("\n", withString: " ")
        NSOperationQueue().addOperationWithBlock {
            var nsdata:NSData!
            var postdata:String!
            if(self.testalarmpostdata != nil) {
                self.testalarmpostdata["criteria"] = self.alarm["criteria"] as! NSString
                nsdata = NSJSONSerialization.dataWithJSONObject(self.testalarmpostdata, options: NSJSONWritingOptions.allZeros, error: nil)
                if nsdata == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                postdata = NSString(data: nsdata, encoding: NSUTF8StringEncoding) as String!
                if postdata == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                nsdata = raxAPI.test_check_or_alarm(self.alarm["entity_id"] as! NSString as String, postdata: postdata, targetType: "alarm")
                if nsdata == nil {
                    raxutils.reportGenericError(self)
                    return
                }
            } else {
                var check = raxAPI.getCheck(self.alarm["entity_id"] as! NSString as String, checkid: self.alarm["check_id"] as! NSString as String)
                if check == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                postdata = raxutils.dictionaryToJSONstring(check)
                nsdata = raxAPI.test_check_or_alarm(self.alarm["entity_id"] as! NSString as String, postdata: postdata, targetType: "check")
                if nsdata == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                self.testalarmpostdata = NSMutableDictionary()
                var checkdata:NSArray! = NSJSONSerialization.JSONObjectWithData(nsdata, options: nil, error: nil) as! NSArray!
                if checkdata == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                self.testalarmpostdata["criteria"] = (self.alarm["criteria"] as! NSString)
                self.testalarmpostdata["check_data"] = checkdata
                nsdata = NSJSONSerialization.dataWithJSONObject(self.testalarmpostdata, options: NSJSONWritingOptions.allZeros, error: nil)
                if nsdata == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                postdata = NSString(data: nsdata, encoding: NSUTF8StringEncoding) as String!
                nsdata = raxAPI.test_check_or_alarm(self.alarm["entity_id"] as! NSString as String, postdata: postdata, targetType: "alarm")
                if nsdata == nil {
                    raxutils.reportGenericError(self)
                    return
                }
            }
            var results:NSArray! = NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSArray!
            if results == nil {
                raxutils.reportGenericError(self)
                return
            }
            var mymessage:String = "state: "+((results[0]["state"] as! NSString) as String)+"\nstatus: "+((results[0]["status"] as! NSString) as String)
            raxutils.alert("AlarmTest with Criteria resulted in: ", message: mymessage, vc: self, onDismiss: nil)
            raxutils.setUIBusy(nil, isBusy: false)
        }
    }
    
    func keyboardAppearanceEvent(notification:NSNotification) {
        var keyboardSize:CGRect! = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue()
        if(alarmCriteriaTextView.isFirstResponder()) {
            alarmCriteriaTextView.contentInset.bottom += keyboardSize.height
            alarmCriteriaTextView.scrollIndicatorInsets.bottom += keyboardSize.height
            insetsChanged = true
        } else if insetsChanged {
            alarmCriteriaTextView.contentInset.bottom -= keyboardSize.height
            alarmCriteriaTextView.scrollIndicatorInsets.bottom -= keyboardSize.height
            insetsChanged = false
        }
    }
    
}
