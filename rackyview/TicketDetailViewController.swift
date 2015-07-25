

import Foundation
import UIKit

class TicketDetailViewController: UIViewController {
    var ticket:NSMutableDictionary! = nil
    var textview:UITextView! = nil
    var comments:NSMutableArray = NSMutableArray()
    var commentCounter:UILabel! = nil
    var currentComment:Int = 0
    
    @IBOutlet var leftNavButton:UIButton!
    @IBOutlet var rightNavButton:UIButton!
    
    @IBAction func handleSwipeEvent(swipeEvent: UISwipeGestureRecognizer) {
        var btn:UIButton = UIButton()
        if(swipeEvent.direction == UISwipeGestureRecognizerDirection.Left) {
            btn.titleLabel?.text = "→"
        } else {
            btn.titleLabel?.text = "←"
        }
        onCommentNavigationButtonClick(btn)
    }
    
    @IBAction func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    @IBAction func edit() {
        var beginNewTicketCommentAction:()->() = {
            var newticketview = UIStoryboard(name:"Main",bundle:nil)
                .instantiateViewControllerWithIdentifier("NewTicketCommentViewController") as! NewTicketCommentViewController
            newticketview.t_id =  self.ticket.objectForKey("ticket-id") as! NSString as String
            self.navigationController?.pushViewController(newticketview, animated: true)
        }
        var beginCloseTicket:()->() = {
            var closeticketview = UIStoryboard(name:"Main",bundle:nil)
                .instantiateViewControllerWithIdentifier("CloseTicketViewController") as! CloseTicketViewController
            closeticketview.ticket =  self.ticket
            self.navigationController?.pushViewController(closeticketview, animated: true)
        }
        var alert = UIAlertController(title: "Ticket Actions", message: "What would you like to do?", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alert.addAction(UIAlertAction(title: "New comment", style: UIAlertActionStyle.Default, handler: { (action:UIAlertAction!) -> Void in
            beginNewTicketCommentAction()
        }))
        alert.addAction(UIAlertAction(title: "Close ticket", style: UIAlertActionStyle.Default, handler: { (action:UIAlertAction!) -> Void in
            beginCloseTicket()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Destructive, handler: { (action:UIAlertAction!) -> Void in
            return
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        if((ticket.objectForKey("ticket-status") as! NSString as String) != "CLOSED") {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.Plain, target: self, action: "edit")
        }
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.0, green: 0.2, blue: 0.3, alpha: 100.0)
        self.navigationController?.navigationBar.translucent = false


        textview = self.view.viewWithTag(5) as! UITextView
        commentCounter = self.view.viewWithTag(6) as! UILabel
        (self.view.viewWithTag(1) as! UILabel).text = (ticket.objectForKey("subject") as! NSString) as String
        (self.view.viewWithTag(2) as! UILabel).text = "Updated: "
        (self.view.viewWithTag(2) as! UILabel).text?.extend(ticket.objectForKey("updated-at") as! NSString as String)
        (self.view.viewWithTag(3) as! UILabel).text = "Status: "
        (self.view.viewWithTag(3) as! UILabel).text?.extend(ticket.objectForKey("ticket-status") as! NSString as String)
        (self.view.viewWithTag(4) as! UILabel).text = "ID: "
        (self.view.viewWithTag(4) as! UILabel).text?.extend(ticket.objectForKey("ticket-id") as! NSString as String)
        self.title = ticket.objectForKey("ticket-id") as! NSString as String
        
        var swipeleft = UISwipeGestureRecognizer(target: self, action: "handleSwipeEvent:")
        swipeleft.direction = UISwipeGestureRecognizerDirection.Left
        self.view.addGestureRecognizer(swipeleft)
        var swiperight = UISwipeGestureRecognizer(target: self, action: "handleSwipeEvent:")
        swiperight.direction = UISwipeGestureRecognizerDirection.Right
        self.view.addGestureRecognizer(swiperight)
    }
    
    func viewComment(index:Int) {
        NSOperationQueue.mainQueue().addOperationWithBlock {
            raxutils.flashView(self.textview.viewForBaselineLayout()!, myDuration:0.4, myColor: UIColor(red: 0.2, green: 0, blue: 0.4, alpha: 1))
            self.textview.text = "Author: "+((self.comments[index]["author"] as! NSString) as String)+"\n"
            self.textview.text? += "Created at: "+((self.comments[index]["created-at"] as! NSString) as String)+"\n"
            self.textview.text? += "___________________\n\n"
            self.textview.text? += (self.comments[index]["text"] as! NSString) as String
            self.commentCounter.text = String(index+1)
            self.commentCounter.text? += "/"
            self.commentCounter.text? += String(self.comments.count)
            self.currentComment = index
        }
    }
    
    func initState (ticketdetails:NSDictionary) {
        comments.removeAllObjects()
        comments.addObjectsFromArray(ticketdetails.valueForKey("ticket")?
            .valueForKey("comments")?.valueForKey("comment") as! NSArray as [AnyObject])
        if(comments.count < 1) {
            return
        }
        viewComment(0)
        raxutils.setUIBusy(nil, isBusy: false)
    }
    
    @IBAction func onCommentNavigationButtonClick(btn: UIButton) {
        if(comments.count < 1) {
            return
        }
        if(btn.titleLabel?.text == "←") {
            if(currentComment == 0) {
                viewComment(comments.count - 1)
            } else {
                viewComment(currentComment - 1)
            }
        }
        if(btn.titleLabel?.text == "→") {
            if(currentComment == comments.count - 1) {
                viewComment(0)
            } else {
                viewComment(currentComment + 1)
            }
        }
    }
    
    func refresh() {
        var ticketdetails:NSData!
        raxutils.setUIBusy(self.view, isBusy: true)
        NSOperationQueue().addOperationWithBlock {
            ticketdetails = raxAPI.get_ticket_details(self.ticket.objectForKey("ticket-id") as! NSString as String)
            if(ticketdetails == nil) {
                raxutils.alert("Error", message: "sessionid has apparently expired", vc: self, onDismiss: nil)
                return
            }
            self.initState(NSJSONSerialization.JSONObjectWithData(ticketdetails, options: nil, error: nil) as! NSDictionary)
            raxutils.updateTicketCommentCount(self.ticket)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
}
