
import UIKit
import Foundation


class LoginViewController: UIViewController,NSURLSessionTaskDelegate {
    @IBOutlet var usernamefield:UITextField!
    @IBOutlet var passwordfield:UITextField!
    @IBOutlet var versionLable:UILabel!
    var passwordFromKeychain:String!

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        let userdata:NSData! = raxutils.getUserdata()
        if(userdata != nil) {
            GlobalState.instance.userdata = NSKeyedUnarchiver.unarchiveObjectWithData(userdata) as! NSMutableDictionary!
            GlobalState.instance.sessionid = (GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary)["sessionid"] as! NSString as String
            GlobalState.instance.csrftoken = (GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary)["csrftoken"] as! NSString as String
        }
        versionLable.text = raxutils.getVersion()
        self.usernamefield.text = ""
        self.passwordfield.text = ""
        passwordFromKeychain = raxutils.getPasswordFromKeychain()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
               
        if(passwordFromKeychain != nil && GlobalState.instance.userdata != nil) {
            //If a password is found in the keychain but userdata wasn't found in the appdata area, that means the user
            //must have removed & reinstalled the app without logging out. Because removing an app doesn't automatically
            //clear the keychain. If I don't do this check, the app will crash on startup without any way for the
            //end user to resolve it. I don't know how to clear the iOS keychain entry short of a factory-reset if you can't
            //use the original app to do it.
            //UPDATE: Actually, in iOS 8.3 it appears removing the app deletes any keychain stuff it made... I think...I dunno.
            self.usernamefield.text = GlobalState.instance.userdata.objectForKey("access")!.objectForKey("user")!.objectForKey("name")! as? String
            self.passwordfield.text = passwordFromKeychain
            self.loginBtnTapped()
        } else if(GlobalState.instance.userdata != nil) {
            self.usernamefield.text = GlobalState.instance.userdata.objectForKey("access")!.objectForKey("user")!.objectForKey("name")! as? String
            raxutils.setUIBusy(self.view, isBusy: true)
            raxAPI.refreshUserData(self.getcatalogCallback)
        }
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: Selector("dismissKeyboard")))
    }
    
    func getcatalogCallback( returneddata: NSData?, response: NSURLResponse?,error: NSError?) {
        self.view.setNeedsDisplay()
        NSOperationQueue.mainQueue().addOperationWithBlock {
            if(error != nil) {
                raxutils.alert("Login Error",message:"Username or password not correct.\n\n\n"+error!.description,vc:self,onDismiss: nil)
                raxutils.setUIBusy(nil, isBusy: false)
                return
            }
            if (response as! NSHTTPURLResponse).statusCode != 200 {
                raxutils.alert("Login Error",message:"Wrong HTTP response code received. Session might have expired:\n"+String( (response as! NSHTTPURLResponse).statusCode),vc:self,onDismiss: nil)
                raxutils.setUIBusy(nil, isBusy: false)
                return
            }
            
            var userdata:NSMutableDictionary!
            do {
                 try userdata = NSJSONSerialization.JSONObjectWithData(returneddata!, options: NSJSONReadingOptions.MutableContainers) as! NSMutableDictionary
            } catch {
                raxutils.alert("Login Error", message: "invalid JSON.", vc: self, onDismiss: nil)
                raxutils.setUIBusy(nil, isBusy: false)
                return
            }

            if(self.passwordFromKeychain != self.passwordfield.text) {
                raxutils.deleteDataInKeychain()
            }
            if(GlobalState.instance.userdata != nil && GlobalState.instance.userdata["customSettings"] != nil && (GlobalState.instance.userdata.objectForKey("access")!.objectForKey("user")!.objectForKey("name")! as! String) == self.usernamefield.text) {
                userdata["customSettings"] = GlobalState.instance.userdata["customSettings"]
            } else {
                let customSettings = NSMutableDictionary()
                customSettings["alarmFavorites"] = NSMutableDictionary()
                customSettings["entityFavorites"] = NSMutableDictionary()
                customSettings["openTickets"] = NSMutableDictionary()
                userdata["customSettings"] =  customSettings
            }
  
            (userdata["customSettings"] as! NSMutableDictionary)["sessionid"] = GlobalState.instance.sessionid
            GlobalState.instance.userdata = userdata
            GlobalState.instance.csrftoken = raxAPI.get_csrftoken()
            if GlobalState.instance.csrftoken != nil {
                (userdata["customSettings"] as! NSMutableDictionary)["csrftoken"] = GlobalState.instance.csrftoken
            }
            GlobalState.instance.authtoken = userdata.objectForKey("access")!.objectForKey("token")!.objectForKey("id")! as! String
            GlobalState.instance.username = GlobalState.instance.userdata.objectForKey("access")!.objectForKey("user")!.objectForKey("name")! as! String
            
            for obj in (userdata.objectForKey("access")!.objectForKey("serviceCatalog")! as! NSArray) {
                if(obj.objectForKey("name")!.isEqualToString("cloudMonitoring")) {
                    GlobalState.instance.monitoringEndpoint = (obj.objectForKey("endpoints") as! NSArray)[0].objectForKey("publicURL") as! String
                    break
                }
            }
            if(GlobalState.instance.monitoringEndpoint == nil) {
                raxutils.alert("API error?",
                    message:"There's no 'cloudMonitoring' endpoint in your serviceCatalog.",vc:self, onDismiss: nil)
                raxutils.setUIBusy(nil, isBusy: false)
                return
            }
            for obj in (userdata.objectForKey("access")!.objectForKey("serviceCatalog")! as! NSArray) {
                if(obj.objectForKey("name")!.isEqualToString("cloudServersOpenStack")) {
                    GlobalState.instance.serverEndpoints =  obj.objectForKey("endpoints") as! NSArray
                    break
                }
            }
            var monitoringRoleOrAdminFound:Bool = false
            for role in userdata.objectForKey("access")!.objectForKey("user")!.objectForKey("roles") as! NSArray {
                if ((role as! NSDictionary)["name"] as! String).rangeOfString("monitoring:") != nil ||
                ((role as! NSDictionary)["name"] as! String).rangeOfString(":user-admin") != nil {
                    monitoringRoleOrAdminFound = true
                    break
                }
            }
            raxutils.setUIBusy(nil, isBusy: false)
            let overviewcontroller = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("Overview") as! OverviewViewController
            if !monitoringRoleOrAdminFound {
                raxutils.confirmDialog("Permissons don't appear to be high enough", message: "This account doesn't look like it's an admin account or even an account with the 'monitoring' role enabled. This means the app will probably malfunction & crash.\n\nStill wanna try anyway?", vc: self,
                    cancelAction:{ (action:UIAlertAction!) -> Void in
                        return
                    },
                    okAction:{ (action:UIAlertAction!) -> Void in
                        raxutils.saveUserdata(NSKeyedArchiver.archivedDataWithRootObject(GlobalState.instance.userdata))
                        self.presentViewController(overviewcontroller, animated: true, completion: nil)
                    })
                return
            } else {
                raxutils.saveUserdata(NSKeyedArchiver.archivedDataWithRootObject(GlobalState.instance.userdata))
                self.presentViewController(overviewcontroller, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    @IBAction func loginBtnTapped() {
        if(usernamefield.text!.stringByReplacingOccurrencesOfString(" ", withString: "").lengthOfBytesUsingEncoding(NSUTF8StringEncoding) < 1 ||
            passwordfield.text!.stringByReplacingOccurrencesOfString(" ", withString: "").lengthOfBytesUsingEncoding(NSUTF8StringEncoding) < 1) {
                raxutils.alert("Error",message:"Username & Password cannot be blank", vc: self, onDismiss: nil)
                return
        }
        raxutils.setUIBusy(self.view, isBusy: true, expectingSignificantLoadTime: true)
        GlobalState.instance.sessionid = nil
        GlobalState.instance.csrftoken = nil
        GlobalState.instance.latestAlarmStates = nil
        let retval:String! = raxAPI.login(usernamefield.text!, p: passwordfield.text!)
        if retval == "twofactorauth" {
            handleTwoFactorAuth()
            return
        }
        if retval != "OK" {
            raxutils.reportGenericError(self, message: "Username or password not correct or login endpoint not reached.  Sometimes that just happens because \n¯\\_(ツ)_/¯\nTry again.\n\n"+retval)
            return
        }
        proceedWithLogin()
    }
    
    func handleTwoFactorAuth() {
        let alert = UIAlertController(title: "TwoFactorAuth detected", message: "In a moment you should get a numerical code via SMS. Enter it below:", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addTextFieldWithConfigurationHandler({(textField: UITextField) in
            textField.placeholder = "Code"
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: { action in
            raxutils.setUIBusy(nil, isBusy: false)
            return
        }))
        alert.addAction(UIAlertAction(title: "Send", style: UIAlertActionStyle.Destructive, handler: { action in
            let code:String = (alert.textFields![0]).text!
            if(code.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) < 1) {
                raxutils.setUIBusy(nil, isBusy: false)
                raxutils.alert("Error", message: "Code cannot be blank", vc: self, onDismiss: nil)
                return
            }
            raxAPI._getSessionidWith2FAcode(code, myDelegate: self)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func proceedWithLogin() {
        //You might be wondering why I go through all this to login. It's because of TwoFactorAuth and the Tickets API.
        //There is no official Ticketing API, I must use the websession & csrftokens to access it.
        //At the same time, I want to use the regular documented API where possible. An account with TwoFactorAuth would
        //need to send 2 Verification pins to login twice. Once on the documented API endpoint and another for the website's API to reach ticketing.
        //I think having to enter verification pin twice is a horrible experience, so I opted to only login at the website-endpoint and do whatever
        //it takes to get the APIkey from that single login, so I can use it to access the documented API-endpoints without a 2nd login needing a 2nd
        //verification pin for TwoAuth users.
        //.....yup, pretty crazy.... but it works.
        //When rackspace decides to make an official Ticketing API, then I won't have these 2 endpoints to login to.
        var retval:String! = raxAPI.getUserIdForUsername(usernamefield.text!)
        if retval == nil {
            raxutils.setUIBusy(nil, isBusy: false)
            raxutils.reportGenericError(self, message: "No userid hash?")
            return
        }
        retval = raxAPI.getAPIkeyForUserid(retval)
        if retval == nil {
            raxutils.setUIBusy(nil, isBusy: false)
            raxutils.reportGenericError(self, message: "No apikey?")
            return
        }
        raxAPI.getServiceCatalogUsingUsernameAndAPIKey(usernamefield.text!, apiKey: retval, funcptr: getcatalogCallback)
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, willPerformHTTPRedirection response: NSHTTPURLResponse, newRequest request: NSURLRequest, completionHandler: (NSURLRequest?) -> Void) {
        let setcookie:String! = response.allHeaderFields["Set-Cookie"] as? String!
        if setcookie == nil {
            raxutils.setUIBusy(nil, isBusy: false)
            raxutils.alert("Auth Error", message: "Something went wrong. I see no cookies in the response headers", vc: self, onDismiss: nil)
            return
        }
        if setcookie.rangeOfString("Path=/cloud/") != nil {
            GlobalState.instance.sessionid = raxutils.substringUsingRegex("sessionid=(\\S+);", sourceString: setcookie)
            if(GlobalState.instance.sessionid == nil) {
                raxutils.setUIBusy(nil, isBusy: false)
                raxutils.reportGenericError(self)
                return
            }
            proceedWithLogin()
        } else {
            raxutils.setUIBusy(nil, isBusy: false)
            raxutils.alert("Code Error", message: "Wrong verification code. Please try again.", vc: self, onDismiss: nil)
        }
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if(GlobalState.instance.sessionid == nil || error != nil) {
            if error != nil {
                raxutils.reportGenericError(self,message: "Some kind of problem with code verification...\n\n"+error!.description)
            } else {
                raxutils.alert("Code Error", message: "This doesn't seem to be the correct verification code. Please try again.", vc: self, onDismiss: nil)
            }
            raxutils.setUIBusy(nil, isBusy: false)
        }
    }
    
    @IBAction func privacyPolicyBtnTapped() {
        raxutils.showPrivacyPolicy()
    }
}