

import Foundation
import UIKit

class TicketDetailsViewController: UIViewController {
    var ticket:NSMutableDictionary! = nil
    var textview:UITextView! = nil
    var comments:NSMutableArray = NSMutableArray()
    var commentCounter:UILabel! = nil
    var currentComment:Int = 0
    
    @IBAction func handleSwipeEvent(swipeEvent: UISwipeGestureRecognizer) {
        let btn:UIButton = UIButton()
        if(swipeEvent.direction == UISwipeGestureRecognizerDirection.left) {
            btn.titleLabel?.text = "→"
        } else {
            btn.titleLabel?.text = "←"
        }
        onCommentNavigationButtonClick(btn: btn)
    }
    
    @IBAction func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    @IBAction func edit() {
        let beginNewTicketCommentAction:()->() = {
            let newticketview = UIStoryboard(name:"Main",bundle:nil)
                .instantiateViewController(withIdentifier: "NewTicketCommentViewController") as! NewTicketCommentViewController
            newticketview.t_id =  self.ticket["ticket-id"] as! NSString as String
            self.navigationController?.pushViewController(newticketview, animated: true)
        }
        let beginCloseTicket:()->() = {
            let closeticketview = UIStoryboard(name:"Main",bundle:nil)
                .instantiateViewController(withIdentifier: "CloseTicketViewController") as! CloseTicketViewController
            closeticketview.ticket =  self.ticket
            self.navigationController?.pushViewController(closeticketview, animated: true)
        }
        let alert = UIAlertController(title: "Ticket Actions", message: "What would you like to do?", preferredStyle: UIAlertControllerStyle.actionSheet)
        alert.addAction(UIAlertAction(title: "New comment", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            beginNewTicketCommentAction()
        }))
        alert.addAction(UIAlertAction(title: "Close ticket", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            beginCloseTicket()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.destructive, handler: { (action:UIAlertAction) -> Void in
            return
        }))
        self.present(alert, animated: true, completion: nil)
    }
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

            
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        if((ticket["ticket-status"] as! NSString as String) != "CLOSED") {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.plain, target: self, action: #selector(TicketDetailsViewController.edit))
        }
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.0, green: 0.2, blue: 0.3, alpha: 100.0)
        self.navigationController?.navigationBar.isTranslucent = false

        textview = self.view.viewWithTag(5) as! UITextView
        commentCounter = self.view.viewWithTag(6) as! UILabel
        (self.view.viewWithTag(1) as! UILabel).text = (ticket["subject"] as! NSString) as String
        (self.view.viewWithTag(2) as! UILabel).text = "Updated: "
        (self.view.viewWithTag(2) as! UILabel).text?.append(ticket["updated-at"] as! NSString as String)
        (self.view.viewWithTag(3) as! UILabel).text = "Status: "
        (self.view.viewWithTag(3) as! UILabel).text?.append(ticket["ticket-status"] as! NSString as String)
        (self.view.viewWithTag(4) as! UILabel).text = "ID: "
        (self.view.viewWithTag(4) as! UILabel).text?.append(ticket["ticket-id"] as! NSString as String)
        self.title = ticket["ticket-id"] as! NSString as String
        
        let swipeleft = UISwipeGestureRecognizer(target: self, action: #selector(TicketDetailsViewController.handleSwipeEvent))
        swipeleft.direction = UISwipeGestureRecognizerDirection.left
        self.view.addGestureRecognizer(swipeleft)
        let swiperight = UISwipeGestureRecognizer(target: self, action: #selector(TicketDetailsViewController.handleSwipeEvent))
        swiperight.direction = UISwipeGestureRecognizerDirection.right
        self.view.addGestureRecognizer(swiperight)
        
    }
    
    func initState (ticketdetails:NSDictionary) {
        comments.removeAllObjects()
        comments.addObjects(from: ((ticketdetails["ticket"] as AnyObject).object(forKey: "comments") as AnyObject).object(forKey: "comment") as! NSArray as [AnyObject])
        if(comments.count < 1) {
            return
        }
        viewComment(index: 0)
        raxutils.setUIBusy(v: nil, isBusy: false)
    }

    
    func refresh() {
        var ticketdetails:NSData!
        raxutils.setUIBusy(v: self.view, isBusy: true)
        OperationQueue().addOperation {
            ticketdetails = raxAPI.get_ticket_details(t_id: self.ticket["ticket-id"] as! NSString as String)
            if(ticketdetails == nil) {
                raxutils.alert(title: "Error", message: "sessionid has apparently expired", vc: self, onDismiss: nil)
                return
            }
            self.initState(ticketdetails: (try! JSONSerialization.jsonObject(with: ticketdetails as Data) as! NSDictionary))
            raxutils.updateTicketCommentCount(ticket: self.ticket)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }

    func viewComment(index:Int) {
        OperationQueue.main.addOperation {
            raxutils.flashView(v: self.textview.forLastBaselineLayout, myDuration:0.4, myColor: UIColor(red: 0.2, green: 0, blue: 0.4, alpha: 1))
            self.textview.text = "Author: "+(((self.comments[index] as AnyObject).object(forKey: "author") as! NSString) as String)+"\n"
            self.textview.text? += "Created at: "+(((self.comments[index] as AnyObject).object(forKey: "created-at") as! NSString) as String)+"\n"
            self.textview.text? += "___________________\n\n"
            self.textview.text? += ((self.comments[index] as AnyObject).object(forKey: "text") as! NSString) as String
            self.commentCounter.text = String(index+1)
            self.commentCounter.text? += "/"
            self.commentCounter.text? += String(self.comments.count)
            self.currentComment = index
        }
    }
    
    @IBAction func onCommentNavigationButtonClick(btn: UIButton) {
        if(comments.count < 1) {
            return
        }
        if(btn.titleLabel?.text == "←") {
            if(currentComment == 0) {
                viewComment(index: comments.count - 1)
            } else {
                viewComment(index: currentComment - 1)
            }
        }
        if(btn.titleLabel?.text == "→") {
            if(currentComment == comments.count - 1) {
                viewComment(index: 0)
            } else {
                viewComment(index: currentComment + 1)
            }
        }
    }
}
