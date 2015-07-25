
import UIKit
import Foundation

class GlobalState {
    var authtoken:String! = nil
    var sessionid:String! = nil
    var csrftoken:String! = nil
    var userdata:NSMutableDictionary! = nil
    var username:String!
    var monitoringEndpoint:String! = nil
    var serverEndpoints:NSArray = NSArray()
    var aiview:UIActivityIndicatorView! = nil
    var opqueues:NSMutableDictionary = NSMutableDictionary()
    var serverlistview:ServerListViewController!
    var latestAlarmStates:NSMutableDictionary!
    
    struct Static {
        static var onlyoneinstance:dispatch_once_t = 0
        static var instance: GlobalState!
    }
    
    class var instance: GlobalState {
        dispatch_once(&Static.onlyoneinstance, { Static.instance = GlobalState() } )
        return Static.instance
    }
    
    class func reset() {
        self.Static.instance = GlobalState()
    }
    
    class func addBackgroundTask(name:String, block:( () -> () )) {
        if self.Static.instance.opqueues.valueForKey(name) != nil {
            return
        }
        var q = NSOperationQueue()
        self.Static.instance.opqueues.setValue(q,forKey: name)
        q.suspended = true
        q.addOperationWithBlock{
            block();
            self.Static.instance.opqueues.removeObjectForKey(name)
        }
        q.suspended = false
    }
}


