import UIKit
import Foundation
import CoreData
import Security


class raxutils {
    class func alert(title: String, message:String, vc: UIViewController, onDismiss:((UIAlertAction?)->())! ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: onDismiss))
        OperationQueue.main.addOperation {
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    class func askToRestartApp(vc:UIViewController) {
        raxutils.confirmDialog(title: "Auth error",
            message: "Either you have no network connection or your authtoken/websessionid has expired. We need to go back to the login screen to refresh.",
            vc: raxutils.getOnscreenViewController(),
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                self.restartApp()
            })
    }
    
    class func reportGenericError(vc:UIViewController,message:String="Sorry, something went wrong. It's probably a network failure, expired session or the returned data contained something that wasn't expected, or whatever. \n¯\\_(ツ)_/¯\n Try restarting the app to refresh session and verify the internet is reachable.") {//catch-all for stuff I don't specifically deal with yet.
        raxutils.setUIBusy(v: nil, isBusy: false)
        self.alert(title: "Problem", message:message, vc:vc, onDismiss: nil)
    }
    
    class func substringUsingRegex(regexPattern:String, sourceString:String) -> String! {
        var retval:String!
        let range = (try! NSRegularExpression(pattern:regexPattern, options:[])).firstMatch(in: sourceString, options: [], range: NSMakeRange(0,sourceString.lengthOfBytes(using: String.Encoding.utf8)))?.range(at: 1)
        if range == nil {
            return nil
        }
        retval = (sourceString as NSString).substring(with: NSMakeRange((range?.location)!, (range?.length)!))
        return retval
    }
    
    class func verticallyMoveView(uiview:UIView, moveUp:Bool, distance:Int) {
        let movement = (moveUp) ? -distance : distance
        UIView.animate(withDuration: 0.3, animations: { ()->Void in
            UIView.beginAnimations("__verticallyMoveView", context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            uiview.frame = CGRect(x: CGFloat(0), y: CGFloat(movement), width: uiview.frame.width, height: uiview.frame.height)
            UIView.commitAnimations()
        })
    }
    
    class func addBorderAndShadowToView(v:UIView) {//Only looks good on large solid squares.
        v.layer.cornerRadius = CGFloat(0.8)
        v.layer.masksToBounds = false
        v.layer.borderWidth = CGFloat(1.0)
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = Float(0.8)
        v.layer.shadowRadius = 6
        v.layer.shadowOffset = CGSize(width: CGFloat(6), height: CGFloat(6))
    }
    
    class func flashView(v:UIView, myDuration:TimeInterval=0.7, myDelay:TimeInterval=0, myColor:UIColor=UIColor.white) {
        let tempView = UIView()
        tempView.backgroundColor = myColor
        tempView.frame = v.frame
        
        if(v.isKind(of: UITextView.self)) {
            tempView.frame.origin = v.superview!.convert(v.frame.origin, to:v.superview!)
            v.superview?.addSubview(tempView)
            v.superview?.bringSubview(toFront: tempView)
        } else {
            tempView.center = CGPoint(x: v.bounds.size.width / 2,  y: v.bounds.size.height / 2)
            v.addSubview(tempView)
            v.bringSubview(toFront: tempView)
        }
        UIView.animate(withDuration: myDuration, delay: myDelay, options: [.curveEaseIn, .curveEaseOut, .allowUserInteraction],
           animations:{
                tempView.alpha = 0.0
            },completion: { finished in
                if !finished {
                    return
                }
                v.layer.removeAllAnimations()
                tempView.removeFromSuperview()
                v.setNeedsDisplay()
                CATransaction.flush()
            })
    }
    
    class func swingView(v:UIView, myDuration:TimeInterval=0.5, myDelay:TimeInterval=0, myRotationDegrees:CGFloat=45.0) {
        v.layer.removeAllAnimations()
        v.layer.transform = CATransform3DMakeRotation(-myRotationDegrees, 0, 0, 1.0)
        UIView.animate(withDuration: myDuration, delay: myDelay, options: [.curveEaseIn, .curveEaseOut, .allowUserInteraction, .autoreverse, .beginFromCurrentState, .repeat],
            animations:{
                v.layer.transform = CATransform3DMakeRotation(myRotationDegrees, 0, 0, 1.0)
            },completion: { finished in
                v.layer.transform = CATransform3DMakeRotation(0, 0, 0, 1.0)
            })
    }
    
    class func tableLightwave(tableview:UITableView, myColor:UIColor=UIColor.white) {
        let wave:(NSArray)->() = { cells in
            var myDelay:TimeInterval = 0
            for case let cell as AnyObject in cells {
                RunLoop.current.run(until: NSDate(timeIntervalSinceNow:0.05) as Date)
                self.flashView(v: cell.contentView, myDuration:0.6, myColor:myColor)
                cell.reloadInputViews()
                myDelay+=0.1
            }
        }
        OperationQueue.main.addOperation {
            wave(Array(tableview.visibleCells.reversed()) as NSArray)
            RunLoop.current.run(until: NSDate(timeIntervalSinceNow:0.2) as Date)
            wave(tableview.visibleCells as NSArray)
        }
    }
    
    class func createImageFromColor(myColor:UIColor, myWidth:CGFloat=1, myHeight:CGFloat=1) -> UIImage {
        var image:UIImage
        let rect = CGRect(x: 0, y: 0, width: myWidth, height: myHeight)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(myColor.cgColor)
        context!.fill(rect)
        image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    class func getColorForState(state:String) -> UIColor {
        var stateColor:UIColor
        if state.lowercased() == "ok" {
            stateColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        } else if state.lowercased() == "warn" || state.lowercased() == "warning" {
            stateColor = UIColor.orange
        } else if state.lowercased() == "crit" || state.lowercased() == "critical" {
            stateColor = UIColor.red
        } else {
            stateColor = UIColor.blue
        }
        return stateColor
    }
    
    class func createColoredImageFromUIImage(myImage:UIImage,myColor:UIColor) -> UIImage {
        var coloredImage:UIImage = myImage.copy() as! UIImage
        var context:CGContext!
        let rect:CGRect = CGRect(x: CGFloat(0), y: CGFloat(0), width: myImage.size.width, height: myImage.size.height)
        UIGraphicsBeginImageContextWithOptions(myImage.size, false, myImage.scale)
        coloredImage.draw(in: rect)
        context = UIGraphicsGetCurrentContext()!
        context.setBlendMode(CGBlendMode.sourceIn)
        context.setFillColor(myColor.cgColor)
        context.fill(rect)
        coloredImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return coloredImage
    }
    
    class func imageHueFlash(myImageView:UIImageView, myDuration:TimeInterval=1.5, myColor:UIColor=UIColor.white) {
        CATransaction.flush()
        let transition = CATransition()
        let origImage = myImageView.image!.copy() as! UIImage
        transition.duration = myDuration
        transition.autoreverses = false
        transition.isRemovedOnCompletion = true
        myImageView.image = createColoredImageFromUIImage(myImage: myImageView.image!, myColor: myColor)
        RunLoop.current.run(until: NSDate(timeIntervalSinceNow:0.1) as Date)
        myImageView.layer.add(transition, forKey: nil)
        myImageView.image = origImage
    }
    
    class func navbarGlow(navbar:UINavigationBar, myDuration:TimeInterval=1.5, myColor:UIColor=UIColor.white) {
        navbar.layer.removeAllAnimations()
        navbar.reloadInputViews()
        CATransaction.flush()
        let transition = CATransition()
        transition.duration = myDuration
        transition.autoreverses = true
        transition.isRemovedOnCompletion = true
        transition.repeatCount = Float.infinity
        navbar.isTranslucent = true
        navbar.setBackgroundImage(createImageFromColor(myColor: UIColor.black), for: UIBarMetrics.default)
        
        //This 0.5 second runloop prevents iOS from ignoring the the set-to-black above.
        //It's important because the CAtransition must believe it's going from black to myColor:UIColor.
        //Remove this and you'll see that the navbar won't glow properly.
        RunLoop.current.run(until: NSDate(timeIntervalSinceNow:0.5) as Date)
        
        navbar.layer.add(transition, forKey: nil)
        navbar.setBackgroundImage(createImageFromColor(myColor: myColor), for: UIBarMetrics.default)
    }
    
    class func fadeInAndOut(uiview:UIView) {
        //This code doesn't make perfect sense, but after much testing this seems to be
        //the 100% assured way to keep animation going smoothly in a UITableViewCell.
        //Otherwise, scrolling up & down tends to stop the animation.
        //Also, the ViewController showing the table must call reloadData inside of viewWillAppear.
        CATransaction.flush()
        UIView.animate(withDuration: 0.7, delay: 0, options: [.curveEaseIn, .curveEaseOut, .autoreverse, .beginFromCurrentState, .repeat],
        animations:{
            uiview.alpha = 0.1
        },completion: { finished in
            if finished {
                uiview.layer.removeAllAnimations()
                self.fadeInAndOut(uiview: uiview)
            }
        })
    }
    
    class func dictionaryToJSONstring(dictionary:NSDictionary) -> String! {
        var result:String!
        var data:NSData!
        data = try? JSONSerialization.data(withJSONObject: dictionary, options: JSONSerialization.WritingOptions()) as NSData
        if data != nil {
            result = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue) as String!
        }
        return result
    }
    
    class func getOnscreenViewController() -> UIViewController! {
        var vc:UIViewController!
        var recursiveSearch:((UIViewController)->())!
        recursiveSearch = { currentVC in
            if (currentVC is UINavigationController) {
                recursiveSearch((currentVC as! UINavigationController).topViewController!)
            } else if (currentVC.presentedViewController != nil) {
                recursiveSearch(currentVC.presentedViewController!)
            } else {
                vc = currentVC
            }
        }
        recursiveSearch((UIApplication.shared.delegate as! AppDelegate).navctrl!)
        return vc
    }
    
    class func restartApp() {
        GlobalState.reset()
        (UIApplication.shared.delegate as! AppDelegate).beginApp()
    }
    
    class func showPrivacyPolicy() {
        UIApplication.shared.openURL(NSURL(string:"https://github.com/tokunbo/Rackyview/wiki/Rackyview-Privacy-Policy")! as URL)
    }
    
    class func getVersion() -> String {
        return "version: "+(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)+"("+(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String)+")"
    }
    
    class func confirmDialog(title: String, message:String, vc: UIViewController, cancelAction:((UIAlertAction?)->())!, okAction:((UIAlertAction?)->())! ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: cancelAction))
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.destructive, handler: okAction))
        OperationQueue.main.addOperation {
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    class func logout(v:UIViewController) {
        raxutils.deleteUserdata()
        _ = raxutils.deleteDataInKeychain()
        GlobalState.reset()
        (UIApplication.shared.delegate as! AppDelegate).beginApp()
    }
    
    class func syncTickets(tickets:NSArray) -> NSMutableArray {
        var wasFound:Bool = false
        let ticketsToBeRemovedOnNextUpdate:NSMutableArray = NSMutableArray()
        var currentTicket:NSMutableDictionary
        var cachedTicket:NSMutableDictionary!
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let openTickets = customSettings["openTickets"] as! NSMutableDictionary
        let checkedTickets = NSMutableArray()
        for t in tickets {
            currentTicket = t as! NSMutableDictionary
            cachedTicket = openTickets[currentTicket["ticket-id"] as! String] as! NSMutableDictionary!
            if cachedTicket == nil {
                currentTicket["hasUnreadComments"] = true
            } else {
                if currentTicket["public-comment-count"] as! NSNumber != cachedTicket["public-comment-count"] as! NSNumber {
                    currentTicket["hasUnreadComments"] = true
                } else {
                    currentTicket["hasUnreadComments"] = false
                }
            }
            checkedTickets.add(currentTicket)
        }
        for key in openTickets.keyEnumerator() {
            wasFound = false
            for t in tickets {
                currentTicket = t as! NSMutableDictionary
                if key as! String == currentTicket["ticket-id"] as! String {
                    wasFound = true
                }
            }
            if !wasFound {
                ticketsToBeRemovedOnNextUpdate.add(key)//--Because removing while in keyEnumerator() forLoop causes crash.
            }
        }
        for key in ticketsToBeRemovedOnNextUpdate {
            openTickets.removeObject(forKey: key)
        }
        return checkedTickets
    }

    class func updateTicketCommentCount(ticket:NSMutableDictionary) {//---In effect, this is Mark As Read
        ((GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary)["openTickets"] as! NSMutableDictionary)[ticket["ticket-id"] as! String] = ticket
        raxutils.saveUserdata(userdata: NSKeyedArchiver.archivedData(withRootObject: GlobalState.instance.userdata) as NSData)
    }
    
    class func alarmHasBeenMarkedAsFavorite(alarm:NSDictionary) -> Bool {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let alarmFavorites = customSettings["alarmFavorites"] as! NSMutableDictionary
        let key = (alarm["entity_id"] as! NSString as String)+":"+(alarm["alarm_id"] as! NSString as String)
        return alarmFavorites.value(forKey: key) != nil
    }
    
    class func entityHasBeenMarkedAsFavorite(entity:NSDictionary) -> Bool {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let entityFavorites = customSettings["entityFavorites"] as! NSMutableDictionary
        let key = entity["entity_id"] as! NSString as String
        return entityFavorites.value(forKey: key) != nil
    }
    
    class func updateAlarmFavorites(alarm:NSDictionary, action:String) {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let alarmFavorites = customSettings["alarmFavorites"] as! NSMutableDictionary
        let key = (alarm["entity_id"] as! NSString as String)+":"+(alarm["alarm_id"] as! NSString as String)
        if action == "add" {
            alarmFavorites[key] = alarm
        } else {
            alarmFavorites.removeObject(forKey: key)
        }
        customSettings["alarmFavorites"] = alarmFavorites
        GlobalState.instance.userdata["customSettings"] = customSettings
        raxutils.saveUserdata(userdata: NSKeyedArchiver.archivedData(withRootObject: GlobalState.instance.userdata) as NSData)
    }
    
    class func updateEntityFavorites(entity:NSDictionary, action:String) {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let entityFavorites = customSettings["entityFavorites"] as! NSMutableDictionary
        let key = entity["entity_id"] as! NSString as String
        if action == "add" {
            entityFavorites[key] = entity
        } else {
            entityFavorites.removeObject(forKey: key)
        }
        customSettings["entityFavorites"] = entityFavorites
        GlobalState.instance.userdata["customSettings"] = customSettings
        raxutils.saveUserdata(userdata: NSKeyedArchiver.archivedData(withRootObject: GlobalState.instance.userdata) as NSData)
    }
    
    class func getUserdata() -> NSData! {
        var mocontext:NSManagedObjectContext!
        mocontext = (UIApplication.shared.delegate as AnyObject).managedObjectContext
        let res:NSArray = try! mocontext!.fetch(NSFetchRequest(entityName: "AppData")) as NSArray
        if res.count > 0 {
            return((res[0] as! NSManagedObject).value(forKey: "userdataNSDATA") as! NSData!)
        }
        return nil
    }
    
    class func saveUserdata(userdata:NSData) {
        self.deleteUserdata()
        var mocontext:NSManagedObjectContext!
        mocontext = (UIApplication.shared.delegate as AnyObject).managedObjectContext
        let appdata:AnyObject! = NSEntityDescription.insertNewObject(forEntityName: "AppData", into: mocontext!)
        appdata.setValue(userdata, forKey: "userdataNSDATA")
        do {
            try mocontext!.save()
        } catch _ {
            //TODO: Probably should do something if a save failed, rather than silently fail
        }
    }
    
    class func deleteUserdata() {
        var mocontext:NSManagedObjectContext!
        mocontext = (UIApplication.shared.delegate as AnyObject).managedObjectContext
        
        for e in NSArray(array: try! mocontext!.fetch(NSFetchRequest(entityName: "AppData"))) {
            mocontext!.delete(e as! NSManagedObject)
        }
        do {
            try mocontext!.save()
        } catch _ {
        }
    }
    
    class func encryptData(plaindata:NSData) -> NSData! {
        var data:NSData!
        var cipherdata_length:CInt = 0
        let key = UIDevice().identifierForVendor!.uuidString
        /*https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIDevice_Class/#//apple_ref/occ/instp/UIDevice/identifierForVendor
        The value of this property is the same for apps that come from the same vendor running on the same device. 
        A different value is returned for apps on the same device that come from different vendors, and for apps on different devices regardless of vendor.
        ........and this is all going into the iOS Keychain after encryption.*/
        let plaindata_ptr:UnsafePointer = UnsafePointer<UInt8>(plaindata.bytes.assumingMemoryBound(to: UInt8.self))
        var key_ptr:UnsafePointer<UInt8>
        key.data(using: String.Encoding.utf8, allowLossyConversion: false)?.withUnsafeBytes {
            key_ptr = $0.successor()
        }
        let key_buf = UnsafeMutablePointer<UInt8>.allocate(capacity: key.lengthOfBytes(using: String.Encoding.utf8)+1)
        memset(key_buf, 0, key.lengthOfBytes(using: String.Encoding.utf8)+1)//C string needs to be null-terminated
        memcpy(key_buf, key_ptr, key.lengthOfBytes(using: String.Encoding.utf8))
        let cipherdata_ptr:UnsafeMutablePointer<UInt8> = rackyEncrypt(plaindata_ptr, key_buf, Int32(plaindata.length), &cipherdata_length)
        if (cipherdata_length > 0) {
            data = NSData(bytesNoCopy: cipherdata_ptr, length: Int(cipherdata_length), freeWhenDone: true)
        }
        free(key_buf)
        return data
    }
    
    class func decryptData(cipherdata:NSData) -> NSData! {
        var data:NSData!
        var plaindata_length:CInt = 0
        let key = UIDevice().identifierForVendor!.uuidString
        let cipherdata_ptr:UnsafePointer = UnsafePointer<UInt8>(cipherdata.bytes.assumingMemoryBound(to: UInt8.self))
        var key_ptr:UnsafePointer<UInt8>
        key.data(using: String.Encoding.utf8, allowLossyConversion: false)?.withUnsafeBytes {
            key_ptr = $0.successor()
        }
        let key_buf = UnsafeMutablePointer<UInt8>.allocate(capacity: key.lengthOfBytes(using: String.Encoding.utf8)+1)
        memset(key_buf, 0, key.lengthOfBytes(using: String.Encoding.utf8)+1)//C string needs to be null-terminated
        memcpy(key_buf, key_ptr, key.lengthOfBytes(using: String.Encoding.utf8))
        let plaindata_ptr:UnsafeMutablePointer<UInt8> = rackyDecrypt(cipherdata_ptr, key_buf, Int32(cipherdata.length), &plaindata_length)
        if(plaindata_length > 0 ) {
            data = NSData(bytesNoCopy: plaindata_ptr, length: Int(plaindata_length), freeWhenDone: true)
        }
        free(key_buf)
        return data
    }
    
    class func _getTemplateKeychainQuery() -> [String:AnyObject] {
        var keychainQuery:[String:AnyObject]! = [kSecClass as String:kSecClassGenericPassword as AnyObject]
        keychainQuery[kSecAttrGeneric as String] = Bundle.main.bundleIdentifier as AnyObject
        keychainQuery[kSecAttrAccount as String] = Bundle.main.bundleIdentifier as AnyObject
        return keychainQuery
    }
    
    class func saveDataToKeychain(data:NSData) -> OSStatus {
        var keychainQuery:[String:AnyObject] = _getTemplateKeychainQuery()
        _ = deleteDataInKeychain()
        keychainQuery[kSecValueData as String] = data
        return SecItemAdd(keychainQuery as CFDictionary, nil)
    }
    
    class func getDataFromKeychain() -> NSData! {
        var data:NSData! = nil
        var dataTypeRef:AnyObject?
        var osstatus:OSStatus
        var keychainQuery:[String:AnyObject] = _getTemplateKeychainQuery()
        keychainQuery[kSecReturnData as String] = kCFBooleanTrue
        keychainQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        osstatus = SecItemCopyMatching(keychainQuery as CFDictionary, &dataTypeRef)
        if(osstatus == 0 && dataTypeRef != nil) {
            data = dataTypeRef as? NSData
        }
        return data
    }
    class func savePasswordToKeychain(password:String) -> OSStatus {
        var nsdata:NSData! = password.data(using: String.Encoding.utf8, allowLossyConversion: false)! as NSData
        nsdata = encryptData(plaindata: nsdata)
        return saveDataToKeychain(data: nsdata)
    }
    
    class func getPasswordFromKeychain() -> String! {
        var nsdata:NSData! = getDataFromKeychain()
        if(nsdata == nil ) {
            return nil
        }
        nsdata = decryptData(cipherdata: nsdata)
        if(nsdata == nil) {
            return nil
        }
        return NSString(data: nsdata as Data, encoding: String.Encoding.utf8.rawValue) as String!
    }
    
    class func deleteDataInKeychain() -> OSStatus {
        return SecItemDelete(_getTemplateKeychainQuery() as CFDictionary)
    }
    
    class func setUIBusy(v: UIView!, isBusy: Bool, expectingSignificantLoadTime:Bool=false) {
        if(!isBusy) {
            if GlobalState.instance.aiview != nil {
                OperationQueue.main.addOperation {
                    GlobalState.instance.aiview.stopAnimating()
                    while GlobalState.instance.aiview.superview?.viewWithTag(777) != nil {//Another horrible hack, I don't know why I have to do this.
                        GlobalState.instance.aiview.removeFromSuperview()
                    }
                    RunLoop.current.run(until: NSDate(timeIntervalSinceNow:0.1) as Date)//Allow iOS to redraw the UI
                }
            }
        } else {
            if v.superview?.viewWithTag(777) != nil {//Don't allow 2 busy windows to stack up on each other.
                return
            }
            var actindview = UIActivityIndicatorView()
            v.endEditing(true)
            actindview = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
            actindview.tag = 777
            actindview.hidesWhenStopped = true
            actindview.color = UIColor.white
            actindview.backgroundColor = UIColor.black
            actindview.frame = v.frame
            actindview.alpha = 0.8
            actindview.center = CGPoint(x: v.bounds.size.width / 2,  y: v.bounds.size.height / 2)
            v.addSubview(actindview)
            if(v.isKind(of: UITableView.self)) {
                actindview.frame.offsetBy(dx: 0, dy: (v as! UITableView).contentOffset.y)
            }
            if expectingSignificantLoadTime {
                let img = UIImageView(image: UIImage(named: "chainhourglass.png"))
                img.center = CGPoint(x: actindview.center.x+24, y: actindview.center.y-24)
                if(v.isKind(of: UITableView.self)) {
                    img.center = CGPoint(x: actindview.center.x+24, y: actindview.center.y-24-(v as! UITableView).contentOffset.y)
                } else {
                    img.center = CGPoint(x: actindview.center.x+24, y: actindview.center.y-24)
                }
                actindview.addSubview(img)
                raxutils.fadeInAndOut(uiview: img)
            }
            actindview.startAnimating()
            RunLoop.current.run(until: NSDate(timeIntervalSinceNow:0.1) as Date)//Allow iOS to redraw the UI
            GlobalState.instance.aiview = actindview
        }
    }

    
    class func compareAlarmEvents(ae1:AnyObject!, ae2:AnyObject!) -> ComparisonResult {
        let timestamp1:Double = (ae1 as! NSDictionary).object(forKey: "timestamp") as! Double
        let timestamp2:Double = (ae2 as! NSDictionary).object(forKey: "timestamp") as! Double
        
        if( timestamp1 > timestamp2) {
            return ComparisonResult.orderedAscending
        }
        if(timestamp1 < timestamp2) {
            return ComparisonResult.orderedDescending
        }
        return ComparisonResult.orderedSame
    }
    
    class func compareEntityByFirstAlarmEventTime(ent1:AnyObject!,ent2:AnyObject!) -> ComparisonResult {
        let ae1:NSDictionary = ((ent1 as! NSDictionary).object(forKey: "latest_alarm_states") as! NSArray)[0] as! NSDictionary
        let ae2:NSDictionary = ((ent2 as! NSDictionary).object(forKey: "latest_alarm_states") as! NSArray)[0] as! NSDictionary
        let timestamp1:Double =  ae1.object(forKey: "timestamp") as! Double
        let timestamp2:Double =  ae2.object(forKey: "timestamp") as! Double
        
        if( timestamp1 > timestamp2) {
            return ComparisonResult.orderedAscending
        }
        if(timestamp1 < timestamp2) {
            return ComparisonResult.orderedDescending
        }
        return ComparisonResult.orderedSame
    }
    
    class func sortEntitiesAndTheirEvents(entities:NSArray) -> NSArray {
        let sortedAlarmEventList:NSMutableArray = NSMutableArray()
        let tmpEntityArray:NSMutableArray = NSMutableArray()

        for e in entities {
            sortedAlarmEventList.removeAllObjects()
            sortedAlarmEventList.addObjects(from: ((e as! NSDictionary).object(forKey: "criticalAlarms") as! NSArray).sortedArray(comparator: compareAlarmEvents as! (Any, Any) -> ComparisonResult))
            sortedAlarmEventList.addObjects(from: ((e as! NSDictionary).object(forKey: "warningAlarms") as! NSArray).sortedArray(comparator: compareAlarmEvents as! (Any, Any) -> ComparisonResult))
            sortedAlarmEventList.addObjects(from: ((e as! NSDictionary).object(forKey: "okAlarms") as! NSArray).sortedArray(comparator: compareAlarmEvents as! (Any, Any) -> ComparisonResult))
            sortedAlarmEventList.addObjects(from: ((e as! NSDictionary).object(forKey: "unknownAlarms") as! NSArray).sortedArray(comparator: compareAlarmEvents as! (Any, Any) -> ComparisonResult))
            (e as AnyObject).set(sortedAlarmEventList.copy(), forKey: "latest_alarm_states")
            tmpEntityArray.add(e)
        }
        return tmpEntityArray.sortedArray(comparator: compareEntityByFirstAlarmEventTime as! (Any, Any) -> ComparisonResult) as NSArray
    }

    class func sortAlarmsBySeverityThenTime(in_alarms:NSArray) -> NSArray {
        let outputArray = NSMutableArray()
        let criticalAlarms = NSMutableArray()
        let warningAlarms = NSMutableArray()
        let unknownAlarms = NSMutableArray()
        let okAlarms = NSMutableArray()
        for case let alarm as AnyObject in in_alarms {
            let alarmState = (alarm.object(forKey: "state") as! String).lowercased()
            if(alarmState.range(of: "ok") != nil) {
                okAlarms.add(alarm)
            } else if(alarmState.range(of: "warning") != nil) {
                warningAlarms.add(alarm)
            } else if(alarmState.range(of: "critical") != nil) {
                criticalAlarms.add(alarm)
            } else {
                unknownAlarms.add(alarm)
            }
        }
        outputArray.addObjects(from: unknownAlarms.sortedArray(comparator: raxutils.compareAlarmEvents as! (Any, Any) -> ComparisonResult))
        outputArray.addObjects(from: criticalAlarms.sortedArray(comparator: raxutils.compareAlarmEvents as! (Any, Any) -> ComparisonResult))
        outputArray.addObjects(from: warningAlarms.sortedArray(comparator: raxutils.compareAlarmEvents as! (Any, Any) -> ComparisonResult))
        outputArray.addObjects(from: okAlarms.sortedArray(comparator: raxutils.compareAlarmEvents as! (Any, Any) -> ComparisonResult))
        return outputArray.copy() as! NSArray
    }
    
    class func sortEntitiesBySeverityThenTime(in_entities:NSArray) -> NSArray {
        let outputArray = NSMutableArray()
        let criticalEntities = NSMutableArray()
        let warningEntities = NSMutableArray()
        let okEntities = NSMutableArray()
        let unknownEntities = NSMutableArray()
        for case let entity as AnyObject in in_entities {
            let entityState = (entity.object(forKey: "state") as! String).lowercased()
            if(entityState.range(of: "ok") != nil) {
                okEntities.add(entity)
            } else if(entityState.range(of: "warn") != nil) {
                warningEntities.add(entity)
            } else if(entityState.range(of: "crit") != nil) {
                criticalEntities.add(entity)
            } else {
                unknownEntities.add(entity)
            }
        }
        outputArray.addObjects(from: unknownEntities.sortedArray(comparator: raxutils.compareEntityByFirstAlarmEventTime as! (Any, Any) -> ComparisonResult))
        outputArray.addObjects(from: criticalEntities.sortedArray(comparator: raxutils.compareEntityByFirstAlarmEventTime as! (Any, Any) -> ComparisonResult))
        outputArray.addObjects(from: warningEntities.sortedArray(comparator: raxutils.compareEntityByFirstAlarmEventTime as! (Any, Any) -> ComparisonResult))
        outputArray.addObjects(from: okEntities.sortedArray(comparator: raxutils.compareEntityByFirstAlarmEventTime as! (Any, Any) -> ComparisonResult))
        return outputArray.copy() as! NSArray
    }
    
    class func epochToHumanReadableTimeAgo(epochTime: Double) -> String {
        let calunits:NSCalendar.Unit = NSCalendar.Unit().union(NSCalendar.Unit.day).union(NSCalendar.Unit.hour).union(NSCalendar.Unit.minute)
        let gregorianCalendar:NSCalendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)!
        let epochDate:NSDate = NSDate(timeIntervalSince1970: TimeInterval(epochTime/1000))
        let currentDate:NSDate = NSDate()
        let dateComponents:NSDateComponents = gregorianCalendar.components(calunits, from: epochDate as Date, to: currentDate as Date, options: NSCalendar.Options.matchStrictly) as NSDateComponents
        return String(dateComponents.day)+" day(s) "+String(dateComponents.hour)+" hr(s) "+String(dateComponents.minute)+" min(s) ago"

    }
}
