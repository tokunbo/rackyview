

import UIKit
import Foundation
import CoreData
import Security


class raxutils {
    class func alert(title: String, message:String, vc: UIViewController, onDismiss:((UIAlertAction!)->())! ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: onDismiss))
        NSOperationQueue.mainQueue().addOperationWithBlock {
            vc.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    class func askToRestartApp(vc:UIViewController) {
        raxutils.confirmDialog("Auth error",
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
        raxutils.setUIBusy(nil, isBusy: false)
        self.alert("Problem", message:message, vc:vc, onDismiss: nil)
    }
    
    class func substringUsingRegex(regexPattern:String, sourceString:String) -> String! {
        var retval:String!
        let range = (try! NSRegularExpression(pattern:regexPattern, options:[])).firstMatchInString(sourceString, options: [], range: NSMakeRange(0,sourceString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)))?.rangeAtIndex(1)
        if range == nil {
            return nil
        }
        retval = (sourceString as NSString).substringWithRange(NSMakeRange((range?.location)!, (range?.length)!))
        return retval
    }
    
    class func verticallyMoveView(uiview:UIView, moveUp:Bool, distance:Int) {
        let movement = (moveUp) ? -distance : distance
        UIView.animateWithDuration(0.3, animations: { ()->Void in
            UIView.beginAnimations("__a", context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            uiview.frame = CGRectOffset(uiview.frame, CGFloat(0), CGFloat(movement))
            UIView.commitAnimations()
        })
    }
    
    class func addBorderAndShadowToView(v:UIView) {//Only looks good on large solid squares.
        v.layer.cornerRadius = CGFloat(0.8)
        v.layer.masksToBounds = false
        v.layer.borderWidth = CGFloat(1.0)
        v.layer.shadowColor = UIColor.blackColor().CGColor
        v.layer.shadowOpacity = Float(0.8)
        v.layer.shadowRadius = 6
        v.layer.shadowOffset = CGSizeMake(CGFloat(6), CGFloat(6))
    }
    
    class func flashView(v:UIView, myDuration:NSTimeInterval=0.7, myDelay:NSTimeInterval=0, myColor:UIColor=UIColor.whiteColor()) {
        let tempView = UIView()
        tempView.backgroundColor = myColor
        tempView.frame = v.frame
        if(v.isKindOfClass(UITextView)) {
            tempView.frame.origin = v.superview!.convertPoint(v.frame.origin, toView:v.superview!)
            v.superview?.addSubview(tempView)
            v.superview?.bringSubviewToFront(tempView)
        } else {
            
            tempView.center = CGPointMake(v.bounds.size.width / 2,  v.bounds.size.height / 2)
            v.addSubview(tempView)
            v.bringSubviewToFront(tempView)
        }
        UIView.animateWithDuration(myDuration, delay: myDelay, options: [UIViewAnimationOptions.CurveEaseInOut, UIViewAnimationOptions.AllowUserInteraction],
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
    
    class func swingView(v:UIView, myDuration:NSTimeInterval=0.5, myDelay:NSTimeInterval=0, myRotationDegrees:CGFloat=45.0) {
        v.layer.removeAllAnimations()
        v.layer.transform = CATransform3DMakeRotation(-myRotationDegrees, 0, 0, 1.0)
        UIView.animateWithDuration(myDuration, delay: myDelay, options: [UIViewAnimationOptions.CurveEaseInOut, UIViewAnimationOptions.AllowUserInteraction, UIViewAnimationOptions.Autoreverse, UIViewAnimationOptions.BeginFromCurrentState, UIViewAnimationOptions.Repeat],
            animations:{
                v.layer.transform = CATransform3DMakeRotation(myRotationDegrees, 0, 0, 1.0)
            },completion: { finished in
                v.layer.transform = CATransform3DMakeRotation(0, 0, 0, 1.0)
            })
    }
    
    class func tableLightwave(tableview:UITableView, myColor:UIColor=UIColor.whiteColor()) {
        let wave:(NSArray)->() = { cells in
            var myDelay:NSTimeInterval = 0
            for cell in cells {
                NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow:0.05))
                self.flashView(cell.contentView, myDuration:0.6, myColor:myColor)
                cell.reloadInputViews()
                myDelay+=0.1
            }
        }
        NSOperationQueue.mainQueue().addOperationWithBlock {
            wave(Array(tableview.visibleCells.reverse()))
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow:0.2))
            wave(tableview.visibleCells)
        }
    }
    
    class func createImageFromColor(myColor:UIColor, myWidth:CGFloat=1, myHeight:CGFloat=1) -> UIImage {
        var image:UIImage
        let rect = CGRect(x: 0, y: 0, width: myWidth, height: myHeight)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, myColor.CGColor)
        CGContextFillRect(context, rect)
        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    class func getColorForState(state:String) -> UIColor {
        var stateColor:UIColor
        if state.lowercaseString == "ok" {
            stateColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        } else if state.lowercaseString == "warn" || state.lowercaseString == "warning" {
            stateColor = UIColor.orangeColor()
        } else if state.lowercaseString == "crit" || state.lowercaseString == "critical" {
            stateColor = UIColor.redColor()
        } else {
            stateColor = UIColor.blueColor()
        }
        return stateColor
    }
    
    class func createColoredImageFromUIImage(myImage:UIImage,myColor:UIColor) -> UIImage {
        var coloredImage:UIImage = myImage.copy() as! UIImage
        var context:CGContextRef!
        let rect:CGRect = CGRectMake(0, 0, myImage.size.width, myImage.size.height)
        UIGraphicsBeginImageContextWithOptions(myImage.size, false, myImage.scale)
        coloredImage.drawInRect(rect)
        context = UIGraphicsGetCurrentContext()!
        CGContextSetBlendMode(context, CGBlendMode.SourceIn)
        CGContextSetFillColorWithColor(context, myColor.CGColor)
        CGContextFillRect(context, rect)
        coloredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return coloredImage
    }
    
    class func imageHueFlash(myImageView:UIImageView, myDuration:NSTimeInterval=1.5, myColor:UIColor=UIColor.whiteColor() ) {
        CATransaction.flush()
        let transition = CATransition()
        let origImage = myImageView.image!.copy() as! UIImage
        transition.duration = myDuration
        transition.autoreverses = false
        transition.removedOnCompletion = true
        myImageView.image = createColoredImageFromUIImage(myImageView.image!, myColor: myColor)
        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow:0.1))
        myImageView.layer.addAnimation(transition, forKey: nil)
        myImageView.image = origImage
    }
    
    class func navbarGlow(navbar:UINavigationBar, myDuration:NSTimeInterval=1.5, myColor:UIColor=UIColor.whiteColor()) {
        navbar.layer.removeAllAnimations()
        navbar.reloadInputViews()
        CATransaction.flush()
        let transition = CATransition()
        transition.duration = myDuration
        transition.autoreverses = true
        transition.removedOnCompletion = true
        transition.repeatCount = Float.infinity
        navbar.translucent = true
        navbar.setBackgroundImage(createImageFromColor(UIColor.blackColor()), forBarMetrics: UIBarMetrics.Default)
        
        //This 0.5 second runloop prevents iOS from ignoring the the set-to-black above.
        //It's important because the CAtransition must believe it's going from black to myColor:UIColor.
        //Remove this and you'll see that the navbar won't glow properly.
        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow:0.5))
        
        navbar.layer.addAnimation(transition, forKey: nil)
        navbar.setBackgroundImage(createImageFromColor(myColor), forBarMetrics: UIBarMetrics.Default)
    }
    
    class func fadeInAndOut(uiview:UIView) {
        //This code doesn't make perfect sense, but after much testing this seems to be
        //the 100% assured way to keep animation going smoothly in a UITableViewCell.
        //Otherwise, scrolling up & down tends to stop the animation.
        //Also, the ViewController showing the table must call reloadData inside of viewWillAppear.
        CATransaction.flush()
        UIView.animateWithDuration(0.7, delay: 0, options: [UIViewAnimationOptions.Autoreverse, UIViewAnimationOptions.Repeat, UIViewAnimationOptions.CurveEaseInOut, UIViewAnimationOptions.BeginFromCurrentState],
        animations:{
            uiview.alpha = 0.1
        },completion: { finished in
            if finished {
                uiview.layer.removeAllAnimations()
                self.fadeInAndOut(uiview)
            }
        })
    }
    
    class func dictionaryToJSONstring(dictionary:NSDictionary) -> String! {
        var result:String!
        var data:NSData!
        data = try? NSJSONSerialization.dataWithJSONObject(dictionary, options: NSJSONWritingOptions())
        if data != nil {
            result = NSString(data: data, encoding: NSUTF8StringEncoding) as String!
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
        recursiveSearch((UIApplication.sharedApplication().delegate as! AppDelegate).navctrl!)
        return vc
    }
    
    class func restartApp() {
        GlobalState.reset()
        (UIApplication.sharedApplication().delegate as! AppDelegate).beginApp()
    }
    
    class func showPrivacyPolicy() {
        UIApplication.sharedApplication()
            .openURL(NSURL(string:"https://github.com/tokunbo/Rackyview/wiki/Rackyview-Privacy-Policy")!)
    }
    
    class func getVersion() -> String {
        return "version: "+(NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String)+"("+(NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as! String)+")"
    }
    
    class func confirmDialog(title: String, message:String, vc: UIViewController, cancelAction:((UIAlertAction!)->())!, okAction:((UIAlertAction!)->())! ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: cancelAction))
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Destructive, handler: okAction))
        NSOperationQueue.mainQueue().addOperationWithBlock {
            vc.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    class func logout(v:UIViewController) {
        raxutils.deteleUserdata()
        raxutils.deleteDataInKeychain()
        GlobalState.reset()
        (UIApplication.sharedApplication().delegate as! AppDelegate).beginApp()
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
            checkedTickets.addObject(currentTicket)
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
                ticketsToBeRemovedOnNextUpdate.addObject(key)//--Because removing while in keyEnumerator() forLoop causes crash.
            }
        }
        for key in ticketsToBeRemovedOnNextUpdate {
            openTickets.removeObjectForKey(key)
        }
        return checkedTickets
    }

    class func updateTicketCommentCount(ticket:NSMutableDictionary) {//---In effect, this is Mark As Read
        ((GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary)["openTickets"] as! NSMutableDictionary)[ticket["ticket-id"] as! String] = ticket
        raxutils.saveUserdata(NSKeyedArchiver.archivedDataWithRootObject(GlobalState.instance.userdata))
    }
    
    class func alarmHasBeenMarkedAsFavorite(alarm:NSDictionary) -> Bool {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let alarmFavorites = customSettings["alarmFavorites"] as! NSMutableDictionary
        let key = (alarm["entity_id"] as! NSString as String)+":"+(alarm["alarm_id"] as! NSString as String)
        return alarmFavorites.valueForKey(key) != nil
    }
    
    class func entityHasBeenMarkedAsFavorite(entity:NSDictionary) -> Bool {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let entityFavorites = customSettings["entityFavorites"] as! NSMutableDictionary
        let key = entity["entity_id"] as! NSString as String
        return entityFavorites.valueForKey(key) != nil
    }
    
    class func updateAlarmFavorites(alarm:NSDictionary, action:String) {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let alarmFavorites = customSettings["alarmFavorites"] as! NSMutableDictionary
        let key = (alarm["entity_id"] as! NSString as String)+":"+(alarm["alarm_id"] as! NSString as String)
        if action == "add" {
            alarmFavorites[key] = alarm
        } else {
            alarmFavorites.removeObjectForKey(key)
        }
        customSettings["alarmFavorites"] = alarmFavorites
        GlobalState.instance.userdata["customSettings"] = customSettings
        raxutils.saveUserdata(NSKeyedArchiver.archivedDataWithRootObject(GlobalState.instance.userdata))
    }
    
    class func updateEntityFavorites(entity:NSDictionary, action:String) {
        let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
        let entityFavorites = customSettings["entityFavorites"] as! NSMutableDictionary
        let key = entity["entity_id"] as! NSString as String
        if action == "add" {
            entityFavorites[key] = entity
        } else {
            entityFavorites.removeObjectForKey(key)
        }
        customSettings["entityFavorites"] = entityFavorites
        GlobalState.instance.userdata["customSettings"] = customSettings
        raxutils.saveUserdata(NSKeyedArchiver.archivedDataWithRootObject(GlobalState.instance.userdata))
    }
    
    class func getUserdata() -> NSData! {
        let mocontext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        let res:NSArray = try! mocontext!.executeFetchRequest(NSFetchRequest(entityName: "AppData"))
        if res.count > 0 {
            return((res[0] as! NSManagedObject).valueForKey("userdataNSDATA") as! NSData!)
        }
        return nil
    }
    
    class func saveUserdata(userdata:NSData) {
        self.deteleUserdata()
        let mocontext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        let appdata:AnyObject! = NSEntityDescription.insertNewObjectForEntityForName("AppData", inManagedObjectContext: mocontext!)
        appdata.setValue(userdata, forKey: "userdataNSDATA")
        do {
            try mocontext!.save()
        } catch _ {
        }
    }
    
    class func deteleUserdata() {
        let mocontext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        
        for e in NSArray(array: try! mocontext!.executeFetchRequest(NSFetchRequest(entityName: "AppData"))) {
            mocontext!.deleteObject(e as! NSManagedObject)
        }
        do {
            try mocontext!.save()
        } catch _ {
        }
    }
    
    class func encryptData(plaindata:NSData) -> NSData! {
        var data:NSData!
        var cipherdata_length:CInt = 0
        
        let key = UIDevice().identifierForVendor!.UUIDString
        /*https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIDevice_Class/#//apple_ref/occ/instp/UIDevice/identifierForVendor
        The value of this property is the same for apps that come from the same vendor running on the same device. 
        A different value is returned for apps on the same device that come from different vendors, and for apps on different devices regardless of vendor.
        
        ........and this is all going into the iOS Keychain after encryption.
        */
        
        let plaindata_ptr:UnsafePointer = UnsafePointer<UInt8>(plaindata.bytes)
        let key_ptr = UnsafePointer<UInt8>((key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)?.bytes)!)
        var key_buf = UnsafeMutablePointer<UInt8>.alloc(key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)+1)
        memset(key_buf, 0, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)+1)//C string needs to be null-terminated
        memcpy(key_buf, key_ptr, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
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
        let key = UIDevice().identifierForVendor!.UUIDString
        var cipherdata_ptr:UnsafePointer = UnsafePointer<UInt8>(cipherdata.bytes)
        let key_ptr = UnsafePointer<UInt8>((key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)?.bytes)!)
        var key_buf = UnsafeMutablePointer<UInt8>.alloc(key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)+1)
        memset(key_buf, 0, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)+1)//C string needs to be null-terminated
        memcpy(key_buf, key_ptr, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        var plaindata_ptr:UnsafeMutablePointer<UInt8> = rackyDecrypt(cipherdata_ptr, key_buf, Int32(cipherdata.length), &plaindata_length)
        if(plaindata_length > 0 ) {
            data = NSData(bytesNoCopy: plaindata_ptr, length: Int(plaindata_length), freeWhenDone: true)
        }
        free(key_buf)
        return data
    }
    
    class func _getTemplateKeychainQuery() -> [String:AnyObject] {
        var keychainQuery:[String:AnyObject]! = [kSecClass as String:kSecClassGenericPassword as String]
        keychainQuery[kSecAttrGeneric as String] = NSBundle.mainBundle().bundleIdentifier
        keychainQuery[kSecAttrAccount as String] = NSBundle.mainBundle().bundleIdentifier
        return keychainQuery
    }
    
    class func saveDataToKeychain(data:NSData) -> OSStatus {
        var keychainQuery:[String:AnyObject] = _getTemplateKeychainQuery()
        deleteDataInKeychain()
        keychainQuery[kSecValueData as String] = data
        return SecItemAdd(keychainQuery as CFDictionaryRef, nil)
    }
    
    class func getDataFromKeychain() -> NSData! {
        var data:NSData! = nil
        var dataTypeRef:AnyObject?
        var osstatus:OSStatus
        var keychainQuery:[String:AnyObject] = _getTemplateKeychainQuery()
        keychainQuery[kSecReturnData as String] = kCFBooleanTrue
        keychainQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        osstatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        if(osstatus == 0 && dataTypeRef != nil) {
            data = dataTypeRef as? NSData
        }
        return data
    }
    class func savePasswordToKeychain(password:String) -> OSStatus {
        var nsdata:NSData! = password.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        nsdata = encryptData(nsdata)
        return saveDataToKeychain(nsdata)
    }
    
    class func getPasswordFromKeychain() -> String! {
        var nsdata:NSData! = getDataFromKeychain()
        if(nsdata == nil ) {
            return nil
        }
        nsdata = decryptData(nsdata)
        if(nsdata == nil) {
            return nil
        }
        return NSString(data: nsdata, encoding: NSUTF8StringEncoding) as String!
    }
    
    class func deleteDataInKeychain() -> OSStatus {
        return SecItemDelete(_getTemplateKeychainQuery() as CFDictionaryRef)
    }
    
    class func setUIBusy(v: UIView!, isBusy: Bool, expectingSignificantLoadTime:Bool=false) {
        if(!isBusy) {
            if GlobalState.instance.aiview != nil {
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    GlobalState.instance.aiview.stopAnimating()
                    while GlobalState.instance.aiview.superview?.viewWithTag(777) != nil {//Another horrible hack, I don't know why I have to do this.
                        GlobalState.instance.aiview.removeFromSuperview()
                    }
                    NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow:0.1))//Allow iOS to redraw the UI
                }
            }
        } else {
            if v.superview?.viewWithTag(777) != nil {//Don't allow 2 busy windows to stack up on each other.
                return
            }
            var actindview = UIActivityIndicatorView()
            v.endEditing(true)
            actindview = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
            actindview.tag = 777
            actindview.hidesWhenStopped = true
            actindview.color = UIColor.whiteColor()
            actindview.backgroundColor = UIColor.blackColor()
            actindview.frame = v.frame
            actindview.alpha = 0.8
            actindview.center = CGPointMake(v.bounds.size.width / 2,  v.bounds.size.height / 2)
            v.addSubview(actindview)
            if(v.isKindOfClass(UITableView)) {
                actindview.frame.offsetInPlace(dx: 0, dy: (v as! UITableView).contentOffset.y)
            }
            if expectingSignificantLoadTime {
                let img = UIImageView(image: UIImage(named: "chainhourglass.png"))
                img.center = CGPoint(x: actindview.center.x+24, y: actindview.center.y-24)
                if(v.isKindOfClass(UITableView)) {
                    img.center = CGPoint(x: actindview.center.x+24, y: actindview.center.y-24-(v as! UITableView).contentOffset.y)
                } else {
                    img.center = CGPoint(x: actindview.center.x+24, y: actindview.center.y-24)
                }
                actindview.addSubview(img)
                raxutils.fadeInAndOut(img)
            }
            actindview.startAnimating()
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow:0.1))//Allow iOS to redraw the UI
            GlobalState.instance.aiview = actindview
        }
    }

    
    class func compareAlarmEvents(ae1:AnyObject!,ae2:AnyObject!) -> NSComparisonResult {
        let timestamp1:Double = (ae1 as! NSDictionary).objectForKey("timestamp") as! Double
        let timestamp2:Double = (ae2 as! NSDictionary).objectForKey("timestamp") as! Double
        
        if( timestamp1 > timestamp2) {
            return NSComparisonResult.OrderedAscending
        }
        if(timestamp1 < timestamp2) {
            return NSComparisonResult.OrderedDescending
        }
        return NSComparisonResult.OrderedSame
    }
    
    class func compareEntityByFirstAlarmEventTime(ent1:AnyObject!,ent2:AnyObject!) -> NSComparisonResult {
        let ae1:NSDictionary = ((ent1 as! NSDictionary).objectForKey("latest_alarm_states") as! NSArray)[0] as! NSDictionary
        let ae2:NSDictionary = ((ent2 as! NSDictionary).objectForKey("latest_alarm_states") as! NSArray)[0] as! NSDictionary
        let timestamp1:Double =  ae1.objectForKey("timestamp") as! Double
        let timestamp2:Double =  ae2.objectForKey("timestamp") as! Double
        
        if( timestamp1 > timestamp2) {
            return NSComparisonResult.OrderedAscending
        }
        if(timestamp1 < timestamp2) {
            return NSComparisonResult.OrderedDescending
        }
        return NSComparisonResult.OrderedSame
    }
    
    class func sortEntitiesAndTheirEvents(entities:NSArray) -> NSArray {
        let sortedAlarmEventList:NSMutableArray = NSMutableArray()
        let tmpEntityArray:NSMutableArray = NSMutableArray()

        for e in entities {
            sortedAlarmEventList.removeAllObjects()

            sortedAlarmEventList.addObjectsFromArray(
                ((e as! NSDictionary).objectForKey("criticalAlarms") as! NSArray)
                    .sortedArrayUsingComparator(compareAlarmEvents)
            )
            sortedAlarmEventList.addObjectsFromArray(
                ((e as! NSDictionary).objectForKey("warningAlarms") as! NSArray)
                    .sortedArrayUsingComparator(compareAlarmEvents)
            )
            sortedAlarmEventList.addObjectsFromArray(
                ((e as! NSDictionary).objectForKey("okAlarms") as! NSArray)
                    .sortedArrayUsingComparator(compareAlarmEvents)
            )
            sortedAlarmEventList.addObjectsFromArray(
                ((e as! NSDictionary).objectForKey("unknownAlarms") as! NSArray)
                    .sortedArrayUsingComparator(compareAlarmEvents)
            )
            e.setObject(sortedAlarmEventList.copy(), forKey: "latest_alarm_states")
            tmpEntityArray.addObject(e)
        }
        
        return tmpEntityArray.sortedArrayUsingComparator(compareEntityByFirstAlarmEventTime)
    }

    class func sortAlarmsBySeverityThenTime(in_alarms:NSArray) -> NSArray {
        let outputArray = NSMutableArray()
        let criticalAlarms = NSMutableArray()
        let warningAlarms = NSMutableArray()
        let unknownAlarms = NSMutableArray()
        let okAlarms = NSMutableArray()
        for alarm in in_alarms {
            let alarmState = (alarm.objectForKey("state") as! String).lowercaseString
            if(alarmState.rangeOfString("ok") != nil) {
                okAlarms.addObject(alarm)
            } else if(alarmState.rangeOfString("warning") != nil) {
                warningAlarms.addObject(alarm)
            } else if(alarmState.rangeOfString("critical") != nil) {
                criticalAlarms.addObject(alarm)
            } else {
                unknownAlarms.addObject(alarm)
            }
        }
        outputArray.addObjectsFromArray(unknownAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        outputArray.addObjectsFromArray(criticalAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        outputArray.addObjectsFromArray(warningAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        outputArray.addObjectsFromArray(okAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        return outputArray.copy() as! NSArray
    }
    
    class func sortEntitiesBySeverityThenTime(in_entities:NSArray) -> NSArray {
        let outputArray = NSMutableArray()
        let criticalEntities = NSMutableArray()
        let warningEntities = NSMutableArray()
        let okEntities = NSMutableArray()
        let unknownEntities = NSMutableArray()
        for entity in in_entities {
            let entityState = (entity.objectForKey("state") as! String).lowercaseString
            if(entityState.rangeOfString("ok") != nil) {
                okEntities.addObject(entity)
            } else if(entityState.rangeOfString("warn") != nil) {
                warningEntities.addObject(entity)
            } else if(entityState.rangeOfString("crit") != nil) {
                criticalEntities.addObject(entity)
            } else {
                unknownEntities.addObject(entity)
            }
        }
        outputArray.addObjectsFromArray(unknownEntities.sortedArrayUsingComparator(raxutils.compareEntityByFirstAlarmEventTime))
        outputArray.addObjectsFromArray(criticalEntities.sortedArrayUsingComparator(raxutils.compareEntityByFirstAlarmEventTime))
        outputArray.addObjectsFromArray(warningEntities.sortedArrayUsingComparator(raxutils.compareEntityByFirstAlarmEventTime))
        outputArray.addObjectsFromArray(okEntities.sortedArrayUsingComparator(raxutils.compareEntityByFirstAlarmEventTime))
        return outputArray.copy() as! NSArray
    }
    
    class func epochToHumanReadableTimeAgo(epochTime: Double) -> String {
        var calunits:NSCalendarUnit = NSCalendarUnit()
        let gregorianCalendar:NSCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        
        calunits = calunits.union(NSCalendarUnit.Day)
        calunits = calunits.union(NSCalendarUnit.Hour)
        calunits = calunits.union(NSCalendarUnit.Minute)
        
        let epochDate:NSDate = NSDate(timeIntervalSince1970: NSTimeInterval(epochTime/1000))
        let currentDate:NSDate = NSDate()
        let dateComponents:NSDateComponents = gregorianCalendar.components(calunits,
            fromDate: epochDate, toDate: currentDate,
            options: NSCalendarOptions.MatchStrictly)
        return String(dateComponents.day)+" day(s) "+String(dateComponents.hour)+" hr(s) "+String(dateComponents.minute)+" min(s) ago"

    }
}
