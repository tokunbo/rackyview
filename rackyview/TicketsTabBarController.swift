

import UIKit
import Foundation

class TicketsTabBarController: UITabBarController {
    func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "<<wait...>>", style: UIBarButtonItemStyle.Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationItem.leftBarButtonItem?.enabled = false
        self.navigationController?.navigationBar.barTintColor = UIColor.grayColor()
        self.navigationController?.navigationBar.translucent = false
        self.navigationController?.navigationBar.titleTextAttributes = [NSFontAttributeName:UIFont(name: "Avenir Next", size: 18)!, NSForegroundColorAttributeName: UIColor.whiteColor()];
        self.title = "Racky Tickets"
        self.tabBar.hidden = true
        self.tabBar.backgroundImage = raxutils.createImageFromColor(UIColor(red: 0, green: 0, blue: 0, alpha: 0.7))
        self.tabBar.tintColor = UIColor.redColor()
        self.tabBar.translucent = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        //All this stuff was in viewWillAppear, but it kept intermmitently causing EXC_BAD_ACCESS as if the objects
        //referenced below weren't available yet, so whatever - I guess viewDidAppear is good enough. I do wish I knew 
        //exactly what is wrong with this code being in viewWillAppear.
        //This is the most complex object in this app. A TabView controller with 3 sub UIViewcontrollers in it, must all be ready immediately.
        //While it's okay to expect this viewcontroller to be ready, Apple never assured me the sub-viewcontrollers in the tabs would be read
        //before they were actually called upon to be drawn on screen.... so ....meh, do it here instead.
        
        (self.viewControllers?[0] as UIViewController!).title = "Racky Tickets"
        (self.viewControllers?[1] as! TicketListViewController).title = "Open Tickets"
        (self.viewControllers?[1] as! TicketListViewController).t_status = "NOT_CLOSED"
        (self.viewControllers?[2] as! TicketListViewController).title = "Closed Tickets"
        (self.viewControllers?[2] as! TicketListViewController).t_status = "CLOSED"
        for tbItem in self.tabBar.items as [UITabBarItem]! {
            tbItem.setTitleTextAttributes([NSFontAttributeName:UIFont(name: "Avenir Next", size: 15)!], forState: UIControlState.Normal)
        }
        self.tabBar.hidden = false
        NSOperationQueue().addOperationWithBlock {
            sleep(1)
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.navigationItem.leftBarButtonItem?.title =  "←Dismiss"
                self.navigationItem.leftBarButtonItem?.enabled = true
            }
        }
    }
}
