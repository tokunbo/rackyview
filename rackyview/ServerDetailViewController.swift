

import Foundation
import UIKit

class ServerDetailViewController: UIViewController {
    var server:NSMutableDictionary! = nil
    var alreadyAutoRefreshed:Bool = false
    
    func details () {
        raxutils.confirmDialog("A lot of details about this server. Copy this info to clipboard?", message: String(stringInterpolationSegment: server), vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                UIPasteboard.generalPasteboard().string = String(stringInterpolationSegment: self.server)
        })
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if alreadyAutoRefreshed {
            return
        } else {
            alreadyAutoRefreshed = true
        }
        raxutils.setUIBusy(self.view, isBusy: true)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Details", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(ServerDetailViewController.details))
        self.title = (server["server"] as! NSDictionary)["name"] as! NSString! as String!
        let textview = self.view.viewWithTag(1) as! UITextView
        textview.text = "Public IPs:\n"
        for address in ((server["server"] as! NSDictionary)["addresses"] as! NSDictionary)["public"] as! NSArray {
            textview.text.appendContentsOf("  ")
            textview.text.appendContentsOf(((address as! NSDictionary) as NSDictionary)["addr"] as! NSString as String)
            textview.text.appendContentsOf("\n")
        }
        textview.text.appendContentsOf("\nPrivate IPs:\n")
        for address in ((server["server"] as! NSDictionary)["addresses"] as! NSDictionary)["private"] as! NSArray {
            textview.text.appendContentsOf("  ")
            textview.text.appendContentsOf(((address as! NSDictionary) as NSDictionary)["addr"] as! NSString as String)
            textview.text.appendContentsOf("\n")
        }
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        NSOperationQueue().addOperationWithBlock {
            var flavor:NSDictionary!
            var image:NSDictionary!
            let ostypeLabel = self.view.viewWithTag(2) as! UILabel
            flavor = raxAPI.getServerFlavor(self.server)
            image = raxAPI.getServerImage(self.server)
            NSOperationQueue.mainQueue().addOperationWithBlock {
                ostypeLabel.text = "image: "
                if(image == nil) {
                    ostypeLabel.text?.appendContentsOf("N/A\n")
                } else {
                    ostypeLabel.text?.appendContentsOf((image["image"] as! NSDictionary)["name"] as! NSString as String)
                    ostypeLabel.text?.appendContentsOf("\n")
                }
                ostypeLabel.text?.appendContentsOf("flavor: ")
                if (flavor == nil) {
                    ostypeLabel.text?.appendContentsOf("N/A")
                } else {
                    ostypeLabel.text?.appendContentsOf((flavor["flavor"] as! NSDictionary)["name"] as! NSString as String)
                }
            }
            raxutils.setUIBusy(nil, isBusy: false)
        }
    }
    
    @IBAction func viewAgentInfoButtonPressed() {
        let agentinfoview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("AgentInfoViewController") as! AgentInfoViewController
        agentinfoview.agentid = (server["server"] as! NSDictionary)["id"] as! NSString! as String!
        if agentinfoview.agentid == nil {
            raxutils.alert("No Agent installed", message:"No agentID found. See rackspace's docs on how to install an agent and ensure it's running in rackspace's website", vc:self, onDismiss:nil)
            return
        }
        agentinfoview.title = (server["server"] as! NSDictionary)["name"] as! NSString! as String!
        self.presentViewController(UINavigationController(rootViewController: agentinfoview), animated: true, completion: nil)
    }
    
    @IBAction func rebootButtonPressed() {
        var reboottype:String = ""
        
        let rebootCallback:( NSData?, NSURLResponse?, NSError?)->() = { returneddata, response, error in
            if(response != nil && (response as! NSHTTPURLResponse).statusCode == 202 ) {
                raxutils.alert("Reboot Command Sent", message: "The command to reboot was sent to the server!", vc: self, onDismiss: nil)
            } else {
                var msg:String = "Something went wrong. Unexpected HTTP response code: "
                if(response != nil) {
                    msg.appendContentsOf((String((response as! NSHTTPURLResponse).statusCode)))
                } else {
                    msg.appendContentsOf("n/a")
                }
                raxutils.alert("Reboot Command Error", message: msg, vc: self, onDismiss: nil)
            }
            raxutils.setUIBusy(nil, isBusy: false)
        }
        let actuallySendRebootCmd:()->() = {
            raxutils.setUIBusy(self.view, isBusy: true)
            var postdata:String = "{ \"reboot\":{\"type\":\""
            postdata.appendContentsOf(reboottype)
            postdata.appendContentsOf("\"}}")
            raxAPI.serveraction(self.server, postdata: postdata, funcptr: rebootCallback)
        }
        let askForConfirmationAgain:()->() = {
            let message:String = "You really want a "+reboottype+" reboot of server "+String((self.server["server"] as! NSDictionary)["name"] as! NSString)+"?"
            raxutils.confirmDialog("REALLY Reboot Server?", message: message, vc: self,
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    actuallySendRebootCmd()
            })
        }
        let selectrebootType:()->() = {
            let message = "We can reboot soft, tell the OS to gracefully shutdown and restart.\n Or go hardcore, similar to just cutting the power for a moment.\n What do you wanna do?"
            let alert = UIAlertController(title: "Reboot method", message: message, preferredStyle: UIAlertControllerStyle.ActionSheet)
            alert.addAction(UIAlertAction(title: "Soft", style: UIAlertActionStyle.Default, handler: { (action:UIAlertAction) -> Void in
                reboottype = "SOFT"
                askForConfirmationAgain()
            }))
            alert.addAction(UIAlertAction(title: "Hard", style: UIAlertActionStyle.Default, handler: { (action:UIAlertAction) -> Void in
                reboottype = "HARD"
                askForConfirmationAgain()
            } ))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        raxutils.confirmDialog("Reboot Server", message: "You really sure you want to do this?\nI'll ask again one more time.", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                selectrebootType()
            })
    }
}