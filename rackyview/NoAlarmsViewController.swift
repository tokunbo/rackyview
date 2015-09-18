import UIKit
import Foundation

//Displayed for accounts that don't have any alarms in OK, warning or critical status.
class NoAlarmsViewController: UIViewController {
    
    var unknownEntities:NSArray!
    
    func dismiss() {
        GlobalState.instance.latestAlarmStates = nil
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Retry", style: UIBarButtonItemStyle.Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.barTintColor = UIColor.blackColor()
        self.navigationController?.navigationBar.translucent = false
        self.title = "Rackyview Minimal Mode"
    }
    
    @IBAction func btnPressed(button:UIButton) {
        if button.tag == 1 {
            let miscviewcontroller = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("MiscViewController") as! MiscViewController
            miscviewcontroller.unknownEntities = unknownEntities
            self.presentViewController( UINavigationController(rootViewController: miscviewcontroller),
                animated: true, completion: nil)
        } else if button.tag == 2 {
            if(GlobalState.instance.serverlistview == nil) {
                GlobalState.instance.serverlistview = UIStoryboard(name:"Main",bundle:nil)
                    .instantiateViewControllerWithIdentifier("ServerListView") as! ServerListViewController
            }
            self.presentViewController(UINavigationController(rootViewController: GlobalState.instance.serverlistview), animated: true, completion: nil)
        }
    }
}