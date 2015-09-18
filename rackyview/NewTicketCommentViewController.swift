
import UIKit
import Foundation

class NewTicketCommentViewController: UIViewController {
    
    var t_id:String!
    var textview:UITextView!
    var contentInsets:UIEdgeInsets!
    var scrollInsets:UIEdgeInsets!

    @IBAction func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    @IBAction func postComment() {
        let postcommentCallback:( NSData?, NSURLResponse?, NSError?)->() = { returneddata, response,error in
            raxutils.setUIBusy(nil, isBusy: false)
            if(response != nil && (response as! NSHTTPURLResponse).statusCode == 201 ) {
                raxutils.alert("Commented on Ticket", message: "The comment was sent successfully", vc: self,
                    onDismiss: { (action:UIAlertAction!) -> Void in
                        self.navigationController?.popViewControllerAnimated(true)
                    })
            } else {
                var msg:String = "Something went wrong. Unexpected HTTP response code: "
                if(response != nil) {
                    msg.appendContentsOf((String((response as! NSHTTPURLResponse).statusCode)))
                } else {
                    msg.appendContentsOf("n/a")
                }
                raxutils.alert("Ticket comment Error", message: msg, vc: self, onDismiss: nil)
            }
        }
        let submitComment:()->() = {
            if(GlobalState.instance.csrftoken == nil) {
                raxutils.alert("WEBAPI error maybe?", message: "csrftoken is null, restart app and try again.", vc:self, onDismiss:nil)
                return
            }
            raxutils.setUIBusy(self.parentViewController?.view, isBusy: true)
            raxAPI.submitTicketComment(self.t_id, commentText: self.textview.text, funcptr: postcommentCallback)
        }
        if(textview.text.stringByReplacingOccurrencesOfString(" ", withString: "").lengthOfBytesUsingEncoding(NSUTF8StringEncoding) < 1  ) {
            raxutils.alert("Empty comment?", message: "You can't post an empty comment", vc:self, onDismiss:nil)
            return
        }
        raxutils.confirmDialog("About to post comment", message: "You REALLY sure you want to post this comment?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                submitComment()
            })
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "POST→", style: UIBarButtonItemStyle.Plain, target: self, action: "postComment")
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.0, green: 0.2, blue: 0.3, alpha: 100.0)
        self.navigationController?.navigationBar.translucent = false
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardAppearanceEvent:", name: UIKeyboardDidShowNotification, object: self.view.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardAppearanceEvent:", name: UIKeyboardDidHideNotification, object: self.view.window)
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: Selector("dismissKeyboard")))
        self.textview = self.view.viewWithTag(2) as! UITextView
    }
    
    func keyboardAppearanceEvent(notification:NSNotification) {
        let keyboardSize:CGRect! = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue()
        if(textview.isFirstResponder() && contentInsets == nil) {
            contentInsets = textview.contentInset
            scrollInsets = textview.scrollIndicatorInsets
            textview.contentInset.bottom += keyboardSize.height
            textview.scrollIndicatorInsets.bottom += keyboardSize.height
        } else if contentInsets != nil  && !textview.isFirstResponder() {
            textview.contentInset = contentInsets
            textview.scrollIndicatorInsets = scrollInsets
            contentInsets = nil
            scrollInsets = nil
        }
    }
    
}