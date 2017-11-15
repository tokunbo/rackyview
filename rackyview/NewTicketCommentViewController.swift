
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
        let postcommentCallback:( Data?, URLResponse?, Error?)->() = { returneddata, response,error in
            raxutils.setUIBusy(v: nil, isBusy: false)
            if(response != nil && (response as! HTTPURLResponse).statusCode == 201 ) {
                raxutils.alert(title: "Commented on Ticket", message: "The comment was sent successfully", vc: self,
                    onDismiss: { (action:UIAlertAction!) -> Void in
                        self.navigationController?.popViewController(animated: true)
                    })
            } else {
                var msg:String = "Something went wrong. Unexpected HTTP response code: "
                if(response != nil) {
                    msg.append((String((response as! HTTPURLResponse).statusCode)))
                } else {
                    msg.append("n/a")
                }
                raxutils.alert(title: "Ticket comment Error", message: msg, vc: self, onDismiss: nil)
            }
        }
        let submitComment:()->() = {
            if(GlobalState.instance.csrftoken == nil) {
                raxutils.alert(title: "WEBAPI error maybe?", message: "csrftoken is null, restart app and try again.", vc:self, onDismiss:nil)
                return
            }
            raxutils.setUIBusy(v: self.parent?.view, isBusy: true)
            raxAPI.submitTicketComment(t_id: self.t_id, commentText: self.textview.text, funcptr: postcommentCallback)
        }
        if(textview.text!.replacingOccurrences(of: " ", with: "").lengthOfBytes(using: String.Encoding.utf8) < 1  ) {
            raxutils.alert(title: "Empty comment?", message: "You can't post an empty comment", vc:self, onDismiss:nil)
            return
        }
        raxutils.confirmDialog(title: "About to post comment", message: "You REALLY sure you want to post this comment?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                submitComment()
            })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "POST→", style: UIBarButtonItemStyle.plain, target: self, action: #selector(NewTicketCommentViewController.postComment))
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.0, green: 0.2, blue: 0.3, alpha: 100.0)
        self.navigationController?.navigationBar.isTranslucent = false
        NotificationCenter.default.addObserver(self, selector: #selector(NewTicketCommentViewController.keyboardAppearanceEvent), name: NSNotification.Name.UIKeyboardDidShow, object: self.view.window)
        NotificationCenter.default.addObserver(self, selector: #selector(NewTicketCommentViewController.keyboardAppearanceEvent), name: NSNotification.Name.UIKeyboardDidHide, object: self.view.window)
        self.view.addGestureRecognizer( UITapGestureRecognizer(target: self, action: #selector(NewTicketCommentViewController.dismissKeyboard)))
        self.textview = self.view.viewWithTag(2) as! UITextView
    }
    
    @IBAction func keyboardAppearanceEvent(notification:NSNotification) {
        let keyboardSize:CGRect! = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
        if(textview.isFirstResponder && contentInsets == nil) {
            contentInsets = textview.contentInset
            scrollInsets = textview.scrollIndicatorInsets
            textview.contentInset.bottom += keyboardSize.height
            textview.scrollIndicatorInsets.bottom += keyboardSize.height
        } else if contentInsets != nil  && !textview.isFirstResponder {
            textview.contentInset = contentInsets
            textview.scrollIndicatorInsets = scrollInsets
            contentInsets = nil
            scrollInsets = nil
        }
    }    
}
