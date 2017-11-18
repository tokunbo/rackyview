
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
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.ratingLabel = self.view.viewWithTag(5) as! UILabel
        self.slider = self.view.viewWithTag(6) as! UISlider
        self.reasonText = self.view.viewWithTag(7) as! UITextView
        self.slider.isContinuous = false
        (self.view.viewWithTag(1) as! UILabel).text = (ticket["subject"] as! NSString) as String
        (self.view.viewWithTag(2) as! UILabel).text = "Updated: "
        (self.view.viewWithTag(2) as! UILabel).text?.append(ticket["updated-at"] as! NSString as String)
        (self.view.viewWithTag(3) as! UILabel).text = "Status: "
        (self.view.viewWithTag(3) as! UILabel).text?.append(ticket["ticket-status"] as! NSString as String)
        (self.view.viewWithTag(4) as! UILabel).text = "ID: "
        (self.view.viewWithTag(4) as! UILabel).text?.append(ticket["ticket-id"] as! NSString as String)
        self.title = ticket["ticket-id"] as! NSString as String
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: #selector(CloseTicketViewController.dismissKeyboard)))
        NotificationCenter.default.addObserver(self, selector: #selector(CloseTicketViewController.keyboardDidAppear), name: NSNotification.Name.UIKeyboardDidShow, object: self.view.window)
        NotificationCenter.default.addObserver(self, selector: #selector(CloseTicketViewController.keyboardDidDisappear), name: NSNotification.Name.UIKeyboardDidHide, object: self.view.window)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "CLOSE→", style: UIBarButtonItemStyle.plain, target: self, action: #selector(CloseTicketViewController.closeTicket))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewDefaultFrame = self.view.frame
    }
    
    @IBAction func sliderMoved(_ sender: UISlider) {
        let roundedValue = (Int)(sender.value)
        OperationQueue.main.addOperation {
            sender.setValue((Float)(roundedValue), animated: true)
            self.ratingLabel.text = "Rating: "+String(roundedValue)
        }
    }
    
    @IBAction func closeTicket() {
        let actuallyCloseTicket:()->() = {
            raxutils.setUIBusy(v: self.view, isBusy: true)
            OperationQueue.main.addOperation {
                let responseCode:Int! = raxAPI.closeTicket(t_id: (self.ticket["ticket-id"] as! NSString) as String, rating: (Int)(self.slider.value), comment: self.reasonText.text)
                if responseCode == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                raxutils.setUIBusy(v: nil, isBusy: false)
                if responseCode != 200 {
                    raxutils.alert(title: "Problem closing ticket", message: "Unexpected HTTP responseCode:\n"+String(responseCode), vc: self, onDismiss: nil)
                } else {
                    raxutils.alert(title: "Ticket Closed", message: "The ticket has been closed!", vc: self,
                    onDismiss: { (action:UIAlertAction!) -> Void in
                        self.dismiss()
                    })
                }
            }
            
        }
        let askAgain:()->() = {
            raxutils.confirmDialog(title: "Really Close ticket?", message: "REALLY REALLY SURE? You can't reopen it or comment on it ever again.", vc: self,
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    actuallyCloseTicket()
            })
        }
        raxutils.confirmDialog(title: "Close ticket?", message: "You really want to close this ticket?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                askAgain()
            })
        reasonText.resignFirstResponder()//stops all the jumping up & down when you tap close.
    }

    @IBAction func keyboardDidAppear(notification:NSNotification) {
        let keyboardSize:CGRect! = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
        if !viewMoved {
            raxutils.verticallyMoveView(uiview: self.view, moveUp: true, distance: Int(keyboardSize.height))
            viewMoved = true
        }
    }
    @IBAction func keyboardDidDisappear(notification:NSNotification) {
        self.view.frame = viewDefaultFrame
        viewMoved = false
    }
}
