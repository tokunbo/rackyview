

import UIKit
import Foundation

class MiscViewController: UIViewController {
    @IBOutlet var loggedinas:UILabel!
    @IBOutlet var versionLabel:UILabel!
    var unknownEntities:NSArray!
    
    func disableRememberPasswordButton() {
        let btn = self.view.viewWithTag(3) as! UIButton
        btn.setTitle("1 password saved", for: UIControlState.disabled)
        btn.backgroundColor = UIColor.gray
        btn.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(MiscViewController.dismiss))
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        self.navigationController?.navigationBar.isTranslucent = false
        self.title = "Miscellaneous Stuff"
        self.loggedinas.text = "Logged in as: "
        self.loggedinas.text?.append(((GlobalState.instance.userdata["access"] as AnyObject).object(forKey: "user") as AnyObject).object(forKey: "name")! as! String)
        self.versionLabel.text = raxutils.getVersion()
        if raxutils.getPasswordFromKeychain() != nil {
            disableRememberPasswordButton()
        }
        for v in self.view.subviews {
            if v.isKind(of: UIButton.self) && v.tag != 4 {
                raxutils.addBorderAndShadowToView(v: v)
            }
        }
    }
    

    @IBAction func onButtonPress(button:UIButton) {
        if(button.tag == 1) {
            let confirmLogout:()->() = {
                raxutils.confirmDialog(title: "You really sure you wanna logout?", message: "You'll lose all your favorites and the knowledge of what ticktets have been read on this iOS device.\n\nReally logout?", vc: self,
                    cancelAction:{ (action:UIAlertAction!) -> Void in
                        return
                    },
                    okAction:{ (action:UIAlertAction!) -> Void in
                        raxutils.logout(v: self)
                    })
            }
            raxutils.confirmDialog(title: "About to logout", message: "Wanna logout and erase all locally saved user data for this app on this device?", vc: self,
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    confirmLogout()
                }
            )
        } else if(button.tag == 2) {
            startRackyTickets()
        } else if(button.tag == 3) {
            rememberPassword()
        } else if(button.tag == 4) {
            raxutils.showPrivacyPolicy()
        } else if(button.tag == 5) {
            showFavoriteAlarms()
        } else if(button.tag == 6) {
            showFavoriteEntities()
        } else if(button.tag == 7) {
            if unknownEntities == nil || unknownEntities.count == 0 {
                raxutils.alert(title: "Nothing to see here.", message: "No entities with undetermined alarm statuses were seen. Note that an Entity with no alarm events is basically invisible to this app.", vc: self, onDismiss: nil)
            } else {
                let entitylistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "EntityListView") as! EntityListViewController
                entitylistview.entities = raxutils.sortEntitiesBySeverityThenTime(in_entities: unknownEntities)
                entitylistview.highestSeverityFoundColor = raxutils.getColorForState(state: "????")
                entitylistview.viewingstate = "unknown"
                self.present( UINavigationController(rootViewController: entitylistview),
                    animated: true, completion: nil)
            }
        } else if(button.tag == 8) {
            if raxutils.getPasswordFromKeychain() == nil {
                raxutils.alert(title: "Password not saved.", message: "Your password must be saved by this app before using refresh-session.", vc: self, onDismiss: nil)
            } else {
                raxutils.confirmDialog(title: "Refresh Session", message: "We're going to replay login using the saved username & password.\n\nReady?", vc: self,
                    cancelAction:{ (action:UIAlertAction!) -> Void in
                        return
                    },
                    okAction:{ (action:UIAlertAction!) -> Void in
                        raxutils.restartApp()
                    })
            }
        }
    }
    
    func rememberPassword() {
        let testAndSavePassword:(_ password:String)->() = { password in
            let retval:String! = raxAPI.login(u: GlobalState.instance.username, p: password)
            raxutils.setUIBusy(v: nil, isBusy: false)
            if (retval != "OK" && retval != "twofactorauth") {
                raxutils.alert(title: "Login error", message: "That password doesn't work or you have no network connection.", vc: self, onDismiss: nil)
            } else if (raxutils.savePasswordToKeychain(password: password) != 0) {
                raxutils.alert(title: "keychain write error", message: "The password worked, but couldn't save it to keychain. Please restart the app. That should fix it.", vc: self, onDismiss: nil)
            } else {
                raxutils.alert(title: "keychain write success", message: "Password saved in keychain.", vc: self, onDismiss: { action in
                    raxutils.restartApp()
                })
            }
            raxutils.setUIBusy(v: nil, isBusy: false)
        }
        let getPasswordDialog:()->() = {
            let alert = UIAlertController(title: "Save Password to keychain", message: "Enter your password.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { action in
                return
            }))
            alert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.destructive, handler: { action in
                let p:String = (alert.textFields![0] as UITextField).text!
                if(p.lengthOfBytes(using: String.Encoding.utf8) < 1) {
                    raxutils.alert(title: "Error", message: "Password cannot be blank", vc: self, onDismiss: nil)
                    return
                }
                raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
                OperationQueue().addOperation { testAndSavePassword(p) }
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField) in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        }
        var msg:String = "We're going to save your password in the device's keychain. "
        msg += "Apple claims this is secure and no other app can access it besides this one. "
        msg += "Don't know what happens with jailbroken devices though. "
        msg += "Normally this app just remembers the username and authtoken(which expires around 24hrs or so.) "
        msg += "in the normal appdata area, but the keychain is safer for long-lasting powerful auth info like passwords. "
        msg += "By memorizing the password, we'll use it everytime the app starts up thus getting a fresh authtoken. "
        msg += " We'll also use it to get a fresh sessionID for viewing tickets. "
        msg += " We're also going to try hard at scrambling the password."
        msg += "\n\nYou can remove the password, username, authtoken and all other userdata "
        msg += "from this device by tapping the logout button."
        raxutils.confirmDialog(title: "Save Password", message: msg, vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                getPasswordDialog()
            }
        )
    }
    
    func startRackyTickets() {
        raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
        let retval = raxAPI.extend_session(reason: "tickets")
        raxutils.setUIBusy(v: nil, isBusy: false)
        if (retval != "OK" && retval != "twofactorauth") {
            raxutils.askToRestartApp(vc: self)
        } else {
            let TicketsController = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "TicketsTabBarController") as! TicketsTabBarController
            self.present(UINavigationController(rootViewController: TicketsController), animated: true, completion: {
                (self.presentedViewController as! UINavigationController).interactivePopGestureRecognizer!.isEnabled = false
            })
        }
    }
    
    func showFavoriteAlarms() {
        let alarmlistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "AlarmListView") as! AlarmListViewController
        alarmlistview.displayingFavorites = true
        alarmlistview.highestSeverityFoundColor = UIColor.black
        self.present( UINavigationController(rootViewController: alarmlistview), animated: true, completion: {
            (self.presentedViewController as! UINavigationController).interactivePopGestureRecognizer!.isEnabled = false
            alarmlistview.refreshFavorites()
        })
    }
    
    func showFavoriteEntities() {
        let entitylistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "EntityListView") as! EntityListViewController
        entitylistview.displayingFavorites = true
        entitylistview.viewingstate = "Favorite"
        self.present( UINavigationController(rootViewController: entitylistview), animated: true, completion: {
            (self.presentedViewController as! UINavigationController).interactivePopGestureRecognizer!.isEnabled = false
            entitylistview.refreshFavorites()
        })
    }
}
