

import UIKit
import Foundation

class CreateTicketViewController:UIViewController,UITextViewDelegate {
    var ticketCategoryLabel:UILabel!
    var ticketSubject:UITextField!
    var ticketMessageBody:UITextView!
    var primaryCategoryName:String!
    var primaryCategoryID:String!
    var subCategoryName:String!
    var subCategoryID:String!
    var keyboardCGRect:CGRect!

    @IBAction func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func dismiss() {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func textViewDidBeginEditing(textView: UITextView) {
        ticketMessageBody.scrollIndicatorInsets.bottom = keyboardCGRect.height
        ticketMessageBody.contentInset.bottom = keyboardCGRect.height
    }
    
    func textViewDidEndEditing(textView: UITextView) {
        ticketMessageBody.scrollIndicatorInsets.bottom = 0
        ticketMessageBody.contentInset.bottom = 0
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        ticketCategoryLabel = self.view.viewWithTag(1) as! UILabel
        ticketSubject = self.view.viewWithTag(2) as! UITextField
        ticketMessageBody = self.view.viewWithTag(3) as! UITextView
        ticketMessageBody.delegate = self
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: #selector(CreateTicketViewController.dismissKeyboard)))
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(CreateTicketViewController.keyboardAppearanceEvent(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 100.0)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        raxutils.setUIBusy(self.view, isBusy: true)
        NSOperationQueue().addOperationWithBlock {
            self.selectTicketCategory(raxAPI.get_ticket_categories())
        }
    }
    
    func submitButtonTapped() {
        let actuallyCreateTicket:()->() = {
            raxutils.setUIBusy(self.view, isBusy: true)
            NSOperationQueue.mainQueue().addOperationWithBlock {
                let t_id:String! = raxAPI.createTicket(self.primaryCategoryName, primaryCategoryID: self.primaryCategoryID, subCategoryName: self.subCategoryName, subCategoryID: self.subCategoryID, ticketSubject: self.ticketSubject.text!, ticketMessageBody: self.ticketMessageBody.text)
                raxutils.setUIBusy(nil, isBusy: false)
                if t_id == nil {
                    raxutils.alert("Error", message: "Either the network is gone or your websession expired", vc: self, onDismiss: nil)
                } else {
                    raxutils.confirmDialog("New Ticket created! Copy Ticket-ID to clipboard?", message: t_id, vc: self,
                        cancelAction:{ (action:UIAlertAction!) -> Void in
                            self.dismiss()
                        },
                        okAction:{ (action:UIAlertAction!) -> Void in
                            UIPasteboard.generalPasteboard().string = t_id
                            self.dismiss()
                        })
                }
            }
        }
        if ticketSubject.text!.stringByReplacingOccurrencesOfString(" ", withString: "").lengthOfBytesUsingEncoding(NSUTF8StringEncoding) < 1 || ticketMessageBody.text.stringByReplacingOccurrencesOfString(" ", withString: "").lengthOfBytesUsingEncoding(NSUTF8StringEncoding) < 1 {
            raxutils.alert("Blank values", message: "Subject & Message body can't be blank", vc: self, onDismiss: nil)
            return
        }
        raxutils.confirmDialog("About to create ticket", message: "You REALLY sure you want to create this ticket?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                actuallyCreateTicket()
            })
    }
    
    func selectTicketCategory(data:NSData!) {
        var subcategories:NSArray!
        var ticketCategories:NSDictionary!
        var showPrimaryCategories:(()->())!
        var showSubCategories:(()->())!
        let updateUI:()->() = {
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.ticketCategoryLabel.text = self.primaryCategoryName + " → " + self.subCategoryName
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit→", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(CreateTicketViewController.submitButtonTapped))
            }
        }
        showPrimaryCategories = {
            let alert = UIAlertController(title: "New Ticket", message: "Select Category(Step 1 of 2)", preferredStyle: UIAlertControllerStyle.ActionSheet)
            for tc in (ticketCategories["categories"] as! NSDictionary)["category"] as! NSArray {
                alert.addAction(UIAlertAction(title: (tc as! NSDictionary)["name"] as? String, style: UIAlertActionStyle.Default, handler: {
                    (action:UIAlertAction) -> Void in
                    self.primaryCategoryName = (tc as! NSDictionary)["name"] as! String
                    self.primaryCategoryID = (tc as! NSDictionary)["id"] as! String
                    subcategories = ((tc as! NSDictionary)["sub-categories"] as! NSDictionary)["sub-category"] as! NSArray
                    showSubCategories()
                }))
            }
            alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.Destructive, handler: {
                (action:UIAlertAction) -> Void in
                self.dismiss()
            }))
            raxutils.setUIBusy(nil, isBusy: false)
            self.presentViewController(alert, animated: true, completion: nil)
        }
        showSubCategories = {
            let alert = UIAlertController(title: "New Ticket", message: "Select SUBCategory(Step 2 of 2)", preferredStyle: UIAlertControllerStyle.ActionSheet)
            for sc in subcategories {
                alert.addAction(UIAlertAction(title: (sc as! NSDictionary)["name"] as? String, style: UIAlertActionStyle.Default, handler: {
                    (action:UIAlertAction) -> Void in
                    self.subCategoryName = (sc as! NSDictionary)["name"] as! String
                    self.subCategoryID = (sc as! NSDictionary)["id"] as! String
                    updateUI()
                }))
            }
            alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.Destructive, handler: {
                (action:UIAlertAction) -> Void in
                self.dismiss()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        if(data == nil) {
            raxutils.setUIBusy(nil, isBusy: false)
            raxutils.alert("Error", message: "For some reason I couldn't load the data needed. Maybe the session has expired or the network is down?", vc: self, onDismiss: { (action:UIAlertAction!) -> Void in
                self.dismiss()
            })
            return
        }
        ticketCategories = (try! NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary
        if(ticketCategories == nil) {
            raxutils.setUIBusy(nil, isBusy: false)
            raxutils.alert("Parse Error", message: "error parsing data from server, sorry", vc: self, onDismiss: { (action:UIAlertAction!) -> Void in
                self.dismiss()
            })
            return
        }
        if data == nil {
            raxutils.reportGenericError(self)
            return
        }
        NSOperationQueue.mainQueue().addOperationWithBlock {
            showPrimaryCategories()
        }
    }
    
    func keyboardAppearanceEvent(notification:NSNotification) {
        keyboardCGRect = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue()
    }
}
