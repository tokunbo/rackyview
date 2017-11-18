

import Foundation
import UIKit

class ServerDetailViewController: UIViewController {
    var server:NSMutableDictionary! = nil
    var alreadyAutoRefreshed:Bool = false
    
    @IBAction func details () {
        raxutils.confirmDialog(title: "A lot of details about this server. Copy this info to clipboard?", message: String(stringInterpolationSegment: server), vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                UIPasteboard.general.string = String(stringInterpolationSegment: self.server)
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if alreadyAutoRefreshed {
            return
        } else {
            alreadyAutoRefreshed = true
        }
        raxutils.setUIBusy(v: self.view, isBusy: true)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Details", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ServerDetailViewController.details))
        self.title = (server["server"] as! NSDictionary)["name"] as! NSString! as String!
        let textview = self.view.viewWithTag(1) as! UITextView
        textview.text = "Public IPs:\n"
        for address in ((server["server"] as! NSDictionary)["addresses"] as! NSDictionary)["public"] as! NSArray {
            textview.text.append("  ")
            textview.text.append(((address as! NSDictionary) as NSDictionary)["addr"] as! NSString as String)
            textview.text.append("\n")
        }
        textview.text.append("\nPrivate IPs:\n")
        for address in ((server["server"] as! NSDictionary)["addresses"] as! NSDictionary)["private"] as! NSArray {
            textview.text.append("  ")
            textview.text.append(((address as! NSDictionary) as NSDictionary)["addr"] as! NSString as String)
            textview.text.append("\n")
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OperationQueue().addOperation {
            var flavor:NSDictionary!
            var image:NSDictionary!
            let ostypeLabel = self.view.viewWithTag(2) as! UILabel
            flavor = raxAPI.getServerFlavor(server: self.server)
            image = raxAPI.getServerImage(server: self.server)
            OperationQueue.main.addOperation {
                ostypeLabel.text = "image: "
                if(image == nil) {
                    ostypeLabel.text?.append("N/A\n")
                } else {
                    ostypeLabel.text?.append((image["image"] as! NSDictionary)["name"] as! NSString as String)
                    ostypeLabel.text?.append("\n")
                }
                ostypeLabel.text?.append("flavor: ")
                if (flavor == nil) {
                    ostypeLabel.text?.append("N/A")
                } else {
                    ostypeLabel.text?.append((flavor["flavor"] as! NSDictionary)["name"] as! NSString as String)
                }
            }
            raxutils.setUIBusy(v: nil, isBusy: false)
        }
    }
    
    @IBAction func viewAgentInfoButtonPressed() {
        let agentinfoview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "AgentInfoViewController") as! AgentInfoViewController
        agentinfoview.agentid = (server["server"] as! NSDictionary)["id"] as! NSString! as String!
        if agentinfoview.agentid == nil {
            raxutils.alert(title: "No Agent installed", message:"No agentID found. See rackspace's docs on how to install an agent and ensure it's running in rackspace's website", vc:self, onDismiss:nil)
            return
        }
        agentinfoview.title = (server["server"] as! NSDictionary)["name"] as! NSString! as String!
        self.present(UINavigationController(rootViewController: agentinfoview), animated: true, completion: nil)
    }
    
    @IBAction func rebootButtonPressed() {
        var reboottype:String = ""
        
        let rebootCallback:( Data?, URLResponse?, Error?)->() = { returneddata, response, error in
            if(response != nil && (response as! HTTPURLResponse).statusCode == 202 ) {
                raxutils.alert(title: "Reboot Command Sent", message: "The command to reboot was sent to the server!", vc: self, onDismiss: nil)
            } else {
                var msg:String = "Something went wrong. Unexpected HTTP response code: "
                if(response != nil) {
                    msg.append((String((response as! HTTPURLResponse).statusCode)))
                } else {
                    msg.append("n/a")
                }
                raxutils.alert(title: "Reboot Command Error", message: msg, vc: self, onDismiss: nil)
            }
            raxutils.setUIBusy(v: nil, isBusy: false)
        }
        let actuallySendRebootCmd:()->() = {
            raxutils.setUIBusy(v: self.view, isBusy: true)
            var postdata:String = "{ \"reboot\":{\"type\":\""
            postdata.append(reboottype)
            postdata.append("\"}}")
            raxAPI.serveraction(server: self.server, postdata: postdata, funcptr: rebootCallback)
        }
        let askForConfirmationAgain:()->() = {
            let message:String = "You really want a "+reboottype+" reboot of server "+String((self.server["server"] as! NSDictionary)["name"] as! NSString)+"?"
            raxutils.confirmDialog(title: "REALLY Reboot Server?", message: message, vc: self,
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    actuallySendRebootCmd()
            })
        }
        let selectrebootType:()->() = {
            let message = "We can reboot soft, tell the OS to gracefully shutdown and restart.\n Or go hardcore, similar to just cutting the power for a moment.\n What do you wanna do?"
            let alert = UIAlertController(title: "Reboot method", message: message, preferredStyle: UIAlertControllerStyle.actionSheet)
            alert.addAction(UIAlertAction(title: "Soft", style: UIAlertActionStyle.destructive, handler: { (action:UIAlertAction) -> Void in
                reboottype = "SOFT"
                askForConfirmationAgain()
            }))
            alert.addAction(UIAlertAction(title: "Hard", style: UIAlertActionStyle.destructive, handler: { (action:UIAlertAction) -> Void in
                reboottype = "HARD"
                askForConfirmationAgain()
            } ))
            alert.addAction(UIAlertAction(title: "*** Don't Do Anything ***", style: UIAlertActionStyle.cancel, handler: { (action:UIAlertAction) -> Void in
                return
            } ))
            self.present(alert, animated: true, completion: nil)
        }
        raxutils.confirmDialog(title: "Reboot Server", message: "You really sure you want to do this?\nI'll ask again one more time.", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                selectrebootType()
            })
    }
}
