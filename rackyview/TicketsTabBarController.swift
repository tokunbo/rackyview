

import UIKit
import Foundation

class TicketsTabBarController: UITabBarController {
    
    @IBAction func actionDismiss() {
        super.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "<<wait...>>", style: UIBarButtonItemStyle.plain, target: self, action: #selector(TicketsTabBarController.actionDismiss))
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationItem.leftBarButtonItem?.isEnabled = false
        self.navigationController?.navigationBar.barTintColor = UIColor.gray
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.font:UIFont(name: "Avenir Next", size: 18)!, NSAttributedStringKey.foregroundColor: UIColor.white];
        self.title = "Racky Tickets"
        self.tabBar.isHidden = true
        self.tabBar.backgroundImage = raxutils.createImageFromColor(myColor: UIColor(red: 0, green: 0, blue: 0, alpha: 0.7))
        self.tabBar.tintColor = UIColor.red
        self.tabBar.isTranslucent = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
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
            tbItem.setTitleTextAttributes([NSAttributedStringKey.font:UIFont(name: "Avenir Next", size: 15)!], for: UIControlState.normal)
        }
        self.tabBar.isHidden = false
        OperationQueue().addOperation {
            sleep(1)
            OperationQueue.main.addOperation {
                self.navigationItem.leftBarButtonItem?.title =  "←Dismiss"
                self.navigationItem.leftBarButtonItem?.isEnabled = true
            }
        }
    }
}
