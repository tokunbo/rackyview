

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
        self.navigationController?.popViewController(animated: true)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        ticketMessageBody.scrollIndicatorInsets.bottom = keyboardCGRect.height
        ticketMessageBody.contentInset.bottom = keyboardCGRect.height
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        ticketMessageBody.scrollIndicatorInsets.bottom = 0
        ticketMessageBody.contentInset.bottom = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ticketCategoryLabel = self.view.viewWithTag(1) as! UILabel
        ticketSubject = self.view.viewWithTag(2) as! UITextField
        ticketMessageBody = self.view.viewWithTag(3) as! UITextView
        ticketMessageBody.delegate = self
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: #selector(CreateTicketViewController.dismissKeyboard)))
        NotificationCenter.default.addObserver(self, selector: #selector(CreateTicketViewController.keyboardAppearanceEvent), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 100.0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        raxutils.setUIBusy(v: self.view, isBusy: true)
        OperationQueue().addOperation {
            self.selectTicketCategory(data: raxAPI.get_ticket_categories())
        }
    }
    
    @objc func submitButtonTapped() {
        let actuallyCreateTicket:()->() = {
            raxutils.setUIBusy(v: self.view, isBusy: true)
            OperationQueue.main.addOperation {
                let t_id:String! = raxAPI.createTicket(primaryCategoryName: self.primaryCategoryName,
                                                       primaryCategoryID: self.primaryCategoryID,
                                                       subCategoryName: self.subCategoryName,
                                                       subCategoryID: self.subCategoryID,
                                                       ticketSubject: self.ticketSubject.text!,
                                                       ticketMessageBody: self.ticketMessageBody.text)
                raxutils.setUIBusy(v: nil, isBusy: false)
                if t_id == nil {
                    raxutils.alert(title: "Error", message: "Either the network is gone or your websession expired", vc: self, onDismiss: nil)
                } else {
                    raxutils.confirmDialog(title: "New Ticket created! Copy Ticket-ID to clipboard?", message: t_id, vc: self,
                        cancelAction:{ (action:UIAlertAction!) -> Void in
                            self.dismiss()
                        },
                        okAction:{ (action:UIAlertAction!) -> Void in
                            UIPasteboard.general.string = t_id
                            self.dismiss()
                        })
                }
            }
        }
        let cleaned_ticketsubject_length = ticketSubject.text!.replacingOccurrences(of: " ", with: "").lengthOfBytes(using: String.Encoding.utf8)
        let cleaned_ticketmessagebody_length = ticketMessageBody.text!.replacingOccurrences(of: " ", with: "").lengthOfBytes(using: String.Encoding.utf8)
        if cleaned_ticketsubject_length < 1 || cleaned_ticketmessagebody_length < 1 {
            raxutils.alert(title: "Blank values", message: "Subject & Message body can't be blank", vc: self, onDismiss: nil)
            return
        }
        raxutils.confirmDialog(title: "About to create ticket", message: "You REALLY sure you want to create this ticket?", vc: self,
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
            OperationQueue.main.addOperation {
                self.ticketCategoryLabel.text = self.primaryCategoryName + " → " + self.subCategoryName
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit→", style: UIBarButtonItemStyle.plain, target: self, action: #selector(CreateTicketViewController.submitButtonTapped))
            }
        }
        showPrimaryCategories = {
            let alert = UIAlertController(title: "New Ticket", message: "Select Category(Step 1 of 2)", preferredStyle: UIAlertControllerStyle.actionSheet)
            for tc in (ticketCategories["categories"] as! NSDictionary)["category"] as! NSArray {
                alert.addAction(UIAlertAction(title: (tc as! NSDictionary)["name"] as? String, style: UIAlertActionStyle.default, handler: {
                    (action:UIAlertAction) -> Void in
                    self.primaryCategoryName = (tc as! NSDictionary)["name"] as! String
                    self.primaryCategoryID = (tc as! NSDictionary)["id"] as! String
                    subcategories = ((tc as! NSDictionary)["sub-categories"] as! NSDictionary)["sub-category"] as! NSArray
                    showSubCategories()
                }))
            }
            alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.destructive, handler: {
                (action:UIAlertAction) -> Void in
                self.dismiss()
            }))
            raxutils.setUIBusy(v: nil, isBusy: false)
            self.present(alert, animated: true, completion: nil)
        }
        showSubCategories = {
            let alert = UIAlertController(title: "New Ticket", message: "Select SUBCategory(Step 2 of 2)", preferredStyle: UIAlertControllerStyle.actionSheet)
            for sc in subcategories {
                alert.addAction(UIAlertAction(title: (sc as! NSDictionary)["name"] as? String, style: UIAlertActionStyle.default, handler: {
                    (action:UIAlertAction) -> Void in
                    self.subCategoryName = (sc as! NSDictionary)["name"] as! String
                    self.subCategoryID = (sc as! NSDictionary)["id"] as! String
                    updateUI()
                }))
            }
            alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.destructive, handler: {
                (action:UIAlertAction) -> Void in
                self.dismiss()
            }))
            self.present(alert, animated: true, completion: nil)
        }
        if(data == nil) {
            raxutils.setUIBusy(v: nil, isBusy: false)
            raxutils.alert(title: "Error", message: "For some reason I couldn't load the data needed. Maybe the session has expired or the network is down?", vc: self, onDismiss: { (action:UIAlertAction!) -> Void in
                self.dismiss()
            })
            return
        }
        ticketCategories = (try! JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions.mutableContainers)) as! NSDictionary
        if(ticketCategories == nil) {
            raxutils.setUIBusy(v: nil, isBusy: false)
            raxutils.alert(title: "Parse Error", message: "error parsing data from server, sorry", vc: self, onDismiss: { (action:UIAlertAction!) -> Void in
                self.dismiss()
            })
            return
        }
        if data == nil {
            raxutils.reportGenericError(vc: self)
            return
        }
        OperationQueue.main.addOperation {
            showPrimaryCategories()
        }
    }
    
    @objc func keyboardAppearanceEvent(notification:NSNotification) {
        keyboardCGRect = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
    }
}
