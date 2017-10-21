    

import UIKit
import Foundation
import CoreData
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    var window: UIWindow?
    var navctrl: UINavigationController?
    var loginview:LoginViewController!
    var becameInactiveAt:TimeInterval!
    
    func beginApp () {
        self.navctrl = UINavigationController(rootViewController: loginview)
        navctrl?.navigationBar.tintColor = UIColor.black
        navctrl!.navigationBar.barTintColor = UIColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 1.0)
        navctrl!.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        navctrl!.setNavigationBarHidden(false, animated: true)
        self.window!.rootViewController = navctrl
    }
    
    private func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        loginview = UIStoryboard(name:"Main", bundle:nil).instantiateViewController(withIdentifier: "LoginView") as! LoginViewController
        beginApp()
        if(WCSession.isSupported()) {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        return true
    }

    private func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: @escaping ([String : AnyObject]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let taskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {})
            var replydata = [String: AnyObject]()
            var las:NSMutableDictionary!
            if GlobalState.instance.authtoken != nil {
                las = NSMutableDictionary()
                las["latestAlarmStates"] = raxAPI.latestAlarmStates(isStreaming: false, updateGlobal: false)
            } else {
                las = raxAPI.latestAlarmStatesUsingSavedUsernameAndPassword()
            }
            if las != nil && las.object(forKey: "latestAlarmStates") != nil {
                las = las["latestAlarmStates"] as! NSMutableDictionary
                replydata["critCount"] = (las.object(forKey: "criticalEntities") as! NSArray).count as AnyObject
                replydata["warnCount"] = (las.object(forKey: "warningEntities") as! NSArray).count as AnyObject
                replydata["okCount"] = (las.object(forKey: "okEntities") as! NSArray).count as AnyObject
            } else {
                replydata["error"] = "Problem getting data from host iOS device" as AnyObject
            }
            replyHandler(replydata)
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        becameInactiveAt = NSDate.timeIntervalSinceReferenceDate
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        becameInactiveAt = NSDate.timeIntervalSinceReferenceDate
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if(becameInactiveAt == nil ) {
            return
        }
        if((NSDate.timeIntervalSinceReferenceDate - becameInactiveAt) > 300 && raxutils.getPasswordFromKeychain() != nil) {
            raxutils.confirmDialog(title: "Refresh session please",
                message: "iOS says the app has been inactive for more than 5mins. Recommend refreshing the session to prevent errors from expired authtokens and web sessionIDs.",
                vc: raxutils.getOnscreenViewController(),
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    raxutils.restartApp()
                })
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.rax.rackspacex.LIES" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1] as NSURL
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "rackyview", withExtension: "momd")
        return NSManagedObjectModel(contentsOf: modelURL!)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("rackyview.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch var error1 as NSError {
            error = error1
            coordinator = nil
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(String(describing: error)), \(error!.userInfo)")
            abort()
        } catch {
            fatalError()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if let moc = self.managedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges {
                do {
                    try moc.save()
                } catch let error1 as NSError {
                    error = error1
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    NSLog("Unresolved error \(String(describing: error)), \(error!.userInfo)")
                    abort()
                }
            }
        }
    }
    
}

