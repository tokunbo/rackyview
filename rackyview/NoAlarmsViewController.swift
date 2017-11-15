import UIKit
import Foundation

//Displayed for accounts that don't have any alarms in OK, warning or critical status.
class NoAlarmsViewController: UIViewController {
    
    var unknownEntities:NSArray!
   
    @IBAction func actionDismiss() {
        GlobalState.instance.latestAlarmStates = nil
        super.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let selector = #selector(self.actionDismiss)
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "← Retry", style: UIBarButtonItemStyle.plain,
                                                                target: self, action: selector) as UIBarButtonItem
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor.black
        self.navigationController?.navigationBar.isTranslucent = false
        self.title = "Rackyview Minimal Mode"
    }
    
    @IBAction func btnPressed(button:UIButton) {
        if button.tag == 1 {
            let miscviewcontroller = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "MiscViewController") as! MiscViewController
            miscviewcontroller.unknownEntities = unknownEntities
            self.present( UINavigationController(rootViewController: miscviewcontroller),
                animated: true, completion: nil)
        } else if button.tag == 2 {
            if(GlobalState.instance.serverlistview == nil) {
                GlobalState.instance.serverlistview = UIStoryboard(name:"Main",bundle:nil)
                    .instantiateViewController(withIdentifier: "ServerListView") as! ServerListViewController
            }
            self.present(UINavigationController(rootViewController: GlobalState.instance.serverlistview), animated: true, completion: nil)
        }
    }
}
