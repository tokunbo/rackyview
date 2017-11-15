

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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = alarm["alarm_label"] as! NSString as String
        notificationPlanLabel = self.view.viewWithTag(1) as! UILabel
        alarmCriteriaTextView = self.view.viewWithTag(2) as! UITextView
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "details", style: UIBarButtonItemStyle.plain, target: self, action: #selector(AlarmDetailViewController.details))
        raxutils.setUIBusy(v: self.parent?.view, isBusy: true)
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: #selector(AlarmDetailViewController.dismissKeyboard)))
        NotificationCenter.default.addObserver(self, selector: #selector(AlarmDetailViewController.keyboardAppearanceEvent), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AlarmDetailViewController.keyboardAppearanceEvent), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OperationQueue().addOperation {
            self.alarm = raxAPI.getAlarm(entityID: self.alarm["entity_id"] as! NSString as String, alarmID: self.alarm["alarm_id"] as! NSString as String)
            if self.alarm == nil {
                raxutils.reportGenericError(vc: self)
                return
            }
            let notificationplanDetails:NSDictionary! = raxAPI.getNotificationPlan(np_id: self.alarm["notification_plan_id"] as! NSString as String)
            if notificationplanDetails == nil {
                raxutils.reportGenericError(vc: self)
                return
            }
            OperationQueue().addOperation {
                self.notificationPlanLabel.text = "Notification Plan: "+((notificationplanDetails["label"] as! NSString) as String)
                self.alarmCriteriaTextView.text = (self.alarm["criteria"] as! NSString) as String
                raxutils.setUIBusy(v: nil, isBusy: false)
            }
        }
    }
    
    @IBAction func details() {
        var entity:NSDictionary!
        var check:NSDictionary!
        var responsedata:String = ""
        raxutils.setUIBusy(v: self.parent?.view, isBusy: true, expectingSignificantLoadTime: true)
        OperationQueue().addOperation {
            check = raxAPI.getCheck(entityid: self.alarm["entity_id"] as! NSString as String, checkid: self.alarm["check_id"] as! NSString as String)
            if check == nil {
                raxutils.reportGenericError(vc: self)
                return
            }
            entity = raxAPI.getEntity(entityID: self.alarm["entity_id"] as! NSString as String)
            if entity == nil {
                raxutils.reportGenericError(vc: self)
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
                responsedata += raxutils.dictionaryToJSONstring(dictionary: entity)
                responsedata += "\n\nCheck Details____________________\n\n"
                responsedata += raxutils.dictionaryToJSONstring(dictionary: check)
                responsedata += "\n\nAlarm Details____________________\n\n"
                responsedata += raxutils.dictionaryToJSONstring(dictionary: self.alarm)
                raxutils.confirmDialog(title: "Details of this alarm, its check and Entity.\nCopy this info to clipboard?", message: responsedata, vc: self,
                    cancelAction:{ (action:UIAlertAction!) -> Void in
                        return
                    },
                    okAction:{ (action:UIAlertAction!) -> Void in
                        UIPasteboard.general.string = responsedata
                    })
            }
            raxutils.setUIBusy(v: nil, isBusy: false)
        }
    }
    
    @IBAction func testAlarm() {
        self.view.endEditing(true)
        raxutils.setUIBusy(v: self.parent?.view, isBusy: true, expectingSignificantLoadTime: true)
        alarm["criteria"] = (self.view.viewWithTag(2) as! UITextView).text!.replacingOccurrences(of: "n", with: "").lengthOfBytes(using: String.Encoding.utf8)
        OperationQueue().addOperation {
            var nsdata:NSData!
            var postdata:String!
            if(self.testalarmpostdata != nil) {
                self.testalarmpostdata["criteria"] = self.alarm["criteria"] as! NSString
                nsdata = try? JSONSerialization.data(withJSONObject: self.testalarmpostdata, options: JSONSerialization.WritingOptions()) as NSData!
                if nsdata == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                postdata = (NSString(data: nsdata as Data, encoding: String.Encoding.utf8.rawValue) as String!)
                if postdata == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                
                postdata = postdata.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
                
                nsdata = raxAPI.test_check_or_alarm(entityid: self.alarm["entity_id"] as! NSString as String, postdata: postdata, targetType: "alarm")
                if nsdata == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
            } else {
                let check = raxAPI.getCheck(entityid: self.alarm["entity_id"] as! NSString as String, checkid: self.alarm["check_id"] as! NSString as String) as NSDictionary!
                if check == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                postdata = raxutils.dictionaryToJSONstring(dictionary: check!)
                nsdata = raxAPI.test_check_or_alarm(entityid: self.alarm["entity_id"] as! NSString as String, postdata: postdata, targetType: "check")
                if nsdata == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                self.testalarmpostdata = NSMutableDictionary()
                let checkdata:NSArray! = try? JSONSerialization.jsonObject(with: nsdata as Data, options: []) as! NSArray
                if checkdata == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                
                self.testalarmpostdata["criteria"] = (self.alarm["criteria"] as! NSString)
                self.testalarmpostdata["check_data"] = checkdata
                nsdata = try? JSONSerialization.data(withJSONObject: self.testalarmpostdata, options: JSONSerialization.WritingOptions()) as NSData!
                if nsdata == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                postdata = NSString(data: nsdata as Data, encoding: String.Encoding.utf8.rawValue) as String!
                nsdata = raxAPI.test_check_or_alarm(entityid: self.alarm["entity_id"] as! NSString as String, postdata: postdata, targetType: "alarm")
                if nsdata == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
            }
            let results:NSArray! =  try? JSONSerialization.jsonObject(with: nsdata as Data, options: []) as! NSArray
            if results == nil {
                raxutils.reportGenericError(vc: self)
                return
            }
            let mymessage:String = "state: "+(((results[0] as! NSDictionary)["state"] as! NSString) as String)+"\nstatus: "+(((results[0] as! NSDictionary)["status"] as! NSString) as String)
            raxutils.alert(title: "AlarmTest with Criteria resulted in: ", message: mymessage, vc: self, onDismiss: nil)
            raxutils.setUIBusy(v: nil, isBusy: false)
        }
    }
    
    @IBAction func keyboardAppearanceEvent(notification:NSNotification) {
        let keyboardSize:CGRect! = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
        if(alarmCriteriaTextView.isFirstResponder) {
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
