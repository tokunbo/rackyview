
import UIKit
import Foundation

class CloseTicketViewController:UIViewController{
    var ticket:NSDictionary!
    var ratingLabel:UILabel!
    var slider:UISlider!
    var reasonText:UITextView!
    var viewMoved:Bool = false
    var viewDefaultFrame:CGRect!
    
    @IBAction func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func dismiss() {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.ratingLabel = self.view.viewWithTag(5) as! UILabel
        self.slider = self.view.viewWithTag(6) as! UISlider
        self.reasonText = self.view.viewWithTag(7) as! UITextView
        self.slider.continuous = false
        (self.view.viewWithTag(1) as! UILabel).text = (ticket.objectForKey("subject") as! NSString) as String
        (self.view.viewWithTag(2) as! UILabel).text = "Updated: "
        (self.view.viewWithTag(2) as! UILabel).text?.extend(ticket.objectForKey("updated-at") as! NSString as String)
        (self.view.viewWithTag(3) as! UILabel).text = "Status: "
        (self.view.viewWithTag(3) as! UILabel).text?.extend(ticket.objectForKey("ticket-status") as! NSString as String)
        (self.view.viewWithTag(4) as! UILabel).text = "ID: "
        (self.view.viewWithTag(4) as! UILabel).text?.extend(ticket.objectForKey("ticket-id") as! NSString as String)
        self.title = ticket.objectForKey("ticket-id") as! NSString as String
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: Selector("dismissKeyboard")))
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidAppear:", name: UIKeyboardDidShowNotification, object: self.view.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidDisappear:", name: UIKeyboardDidHideNotification, object: self.view.window)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "CLOSE→", style: UIBarButtonItemStyle.Plain, target: self, action: "closeTicket")
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        viewDefaultFrame = self.view.frame
    }
    
    @IBAction func sliderMoved(sender: UISlider) {
        var roundedValue = (Int)(sender.value)
        NSOperationQueue.mainQueue().addOperationWithBlock {
            sender.setValue((Float)(roundedValue), animated: true)
            self.ratingLabel.text = "Rating: "+String(roundedValue)
        }
    }
    
    @IBAction func closeTicket() {
        var actuallyCloseTicket:()->() = {
            raxutils.setUIBusy(self.view, isBusy: true)
            NSOperationQueue().addOperationWithBlock {
                var responseCode:Int! = raxAPI.closeTicket((self.ticket.objectForKey("ticket-id") as! NSString) as String, rating: (Int)(self.slider.value), comment: self.reasonText.text)
                if responseCode == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                raxutils.setUIBusy(nil, isBusy: false)
                if responseCode != 200 {
                    raxutils.alert("Problem closing ticket", message: "Unexpected HTTP responseCode:\n"+String(responseCode), vc: self, onDismiss: nil)
                } else {
                    raxutils.alert("Ticket Closed", message: "The ticket has been closed!", vc: self,
                    onDismiss: { (action:UIAlertAction!) -> Void in
                        self.dismiss()
                    })
                }
            }
            
        }
        var askAgain:()->() = {
            raxutils.confirmDialog("Really Close ticket?", message: "REALLY REALLY SURE? You can't reopen it or comment on it ever again.", vc: self,
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    actuallyCloseTicket()
            })
        }
        raxutils.confirmDialog("Close ticket?", message: "You really want to close this ticket?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                askAgain()
            })
        reasonText.resignFirstResponder()//stops all the jumping up & down when you tap close.
    }

    func keyboardDidAppear(notification:NSNotification) {
        var keyboardSize:CGRect! = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue()
        if !viewMoved {
            raxutils.verticallyMoveView(self.view, moveUp: true, distance: Int(keyboardSize.height))
            viewMoved = true
        }
    }
    func keyboardDidDisappear(notification:NSNotification) {
        self.view.frame = viewDefaultFrame
        viewMoved = false
    }
}