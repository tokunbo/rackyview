
import UIKit
import Foundation

class raxAPI {
    class func _createRequest(method: String, url: String, data: String!, qparams: String!, content_type:String!) -> NSMutableURLRequest! {
        let req:NSMutableURLRequest = NSMutableURLRequest()
        var cookieString:String = ""
        req.HTTPMethod = method
        if (content_type == nil) {
            req.setValue("application/json", forHTTPHeaderField:"content-type")
        } else {
            req.setValue(content_type, forHTTPHeaderField:"content-type")
        }
        req.setValue("Rackyview (iOS app "+raxutils.getVersion()+")", forHTTPHeaderField:"User-Agent")
        if(GlobalState.instance.authtoken != nil && url.rangeOfString("//mycloud") == nil) {
            req.setValue(GlobalState.instance.authtoken, forHTTPHeaderField:"X-Auth-Token")
        }
        if(url.rangeOfString("//mycloud") != nil && url.rangeOfString("com/") != nil) {//Don't set cookies when trying to login.
            if(GlobalState.instance.sessionid != nil) {
                cookieString.appendContentsOf("sessionid="+GlobalState.instance.sessionid+";")
            }
            if(GlobalState.instance.csrftoken != nil) {
                cookieString.appendContentsOf("csrftoken="+GlobalState.instance.csrftoken+";")
            }
            if(cookieString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0) {//setting an empty string breaks the whole req object, i think.
                req.setValue(cookieString,forHTTPHeaderField:"Cookie")
            }
        }
        if(url.rangeOfString("com/") == nil) {
            req.setValue("https://mycloud.rackspace.com/?logout_success=true", forHTTPHeaderField:"Referer")//Apparently Rackspace needs this now during login.
        }

        if(qparams != nil){
            req.URL = NSURL(string: url+"/"+qparams!)
        } else {
            req.URL = NSURL(string: url)
        }
        if(data != nil) {
            req.HTTPBody = (data as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        }
        if(method == "HEAD") {
            req.setValue("close", forHTTPHeaderField: "Connection")
        }
        return req
    }
    
    //Because Apple deprecated NSURLConnection.sendSynchronousRequest, but I really like its blocking behavior
    //Idea comes from the Obj-C equiv someone else wrote: https://forums.developer.apple.com/thread/11519
    class func sendSynchronousRequest(request:NSURLRequest, inout returningResponse:NSURLResponse?) throws -> NSData! {
        var nsdata:NSData! = nil
        var nserror:NSError! = nil
        let mysemaphore:dispatch_semaphore_t = dispatch_semaphore_create(0)
        NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        .dataTaskWithRequest(request, completionHandler:{
            (async_nsdata, async_response, async_error) -> Void in
            nsdata = async_nsdata
            returningResponse = async_response
            nserror = async_error
            dispatch_semaphore_signal(mysemaphore)
        }).resume()

        dispatch_semaphore_wait(mysemaphore, DISPATCH_TIME_FOREVER)

        if nserror != nil {
            throw nserror
        }
        return nsdata
    }
    
    class func login(u:String, p:String) -> String {
        let url:String = "https://mycloud.rackspace.com"
        var setcookie:String!
        var postdata:String = "username="+u
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        postdata += "&password="+p.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        postdata += "&type=password"
        do {
            try self.sendSynchronousRequest(
                self._createRequest("POST", url: url, data: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded")!,
                returningResponse:&resp)
        } catch let error as NSError {
            err = error
        }
        if (resp == nil || err != nil) {
            if (err == nil) {
                return String(stringInterpolationSegment: resp)
            } else {
                return String(stringInterpolationSegment: err)
            }
        }
        setcookie = (resp as? NSHTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String!
        if setcookie == nil {
            return "Not Set-Cookie in responseHeaders"
        }
        let respURL = String(stringInterpolationSegment: resp?.URL)
        if respURL.rangeOfString("/cloud/") != nil {
            GlobalState.instance.sessionid = raxutils.substringUsingRegex("sessionid=(\\S+);", sourceString: setcookie)
            return "OK"
        } else if respURL.rangeOfString("/accounts/verify") != nil {
            return "twofactorauth"
        } else if respURL.rangeOfString("/home") != nil {
            return "Routed to deadend(Sometimes that happens, just try again): "+respURL
        }
        return String(stringInterpolationSegment: resp)
    }
    
    class func _getSessionidWith2FAcode(code:String,myDelegate:NSURLSessionDelegate) {
        let url:String = "https://mycloud.rackspace.com/accounts/verify"
        let postdata:String = "verification_code="+code+"&mfa_type=multifactor_auth"
        let request = self._createRequest("POST", url: url, data: postdata, qparams: nil,
            content_type: "application/x-www-form-urlencoded")!
        NSURLSession(configuration:NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: myDelegate, delegateQueue: NSOperationQueue()).dataTaskWithRequest(request).resume()
    }
    
    class func get_csrftoken() -> String! {
        var csrftoken:String! = nil
        var resp:NSURLResponse? = nil
        var url:String = "https://mycloud.rackspace.com/cloud/"
        url.appendContentsOf(GlobalState.instance.userdata.objectForKey("access")!
            .objectForKey("token")!.objectForKey("tenant")!.objectForKey("id")! as! String)
        url.appendContentsOf("/servers")
        do {
            try self.sendSynchronousRequest(
                self._createRequest("HEAD", url: url, data: nil, qparams: nil, content_type: "text/html; charset=utf-8")!,
                returningResponse:&resp)
        } catch _ as NSError {
            //
        }
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            let setcookie:String! = (resp as? NSHTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String
            csrftoken = raxutils.substringUsingRegex("csrftoken=(\\S+);", sourceString: setcookie)
        }
        return csrftoken
    }
    
    class func getUserIdForUsername(username:String) -> String! {
        var userid:String!
        let url:String = "https://mycloud.rackspace.com/proxy/identity/v2.0/users/?limit=1000"
        var resp:NSURLResponse? = nil
        var nsdata:NSData! = nil
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            print("Error in getUserIdForUsername")
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
        if jsonData != nil {
            for user in (jsonData["users"] as! NSArray) {
                if (user as! NSDictionary)["username"] as! NSString! as String == username {
                    userid = (user as! NSDictionary)["id"] as! NSString! as String
                    break
                }
            }
        }
        return userid
    }
    
    class func getAPIkeyForUserid(userid:String) -> String! {
        var apikey:String!
        let url:String = "https://mycloud.rackspace.com/proxy/identity/v2.0/users/"+userid+"/OS-KSADM/credentials/RAX-KSKEY:apiKeyCredentials"
        var resp:NSURLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
        if jsonData != nil {
            apikey = (jsonData["RAX-KSKEY:apiKeyCredentials"] as! NSDictionary)["apiKey"] as! NSString! as String
        }
        return apikey
    }
    
    class func getServiceCatalogUsingUsernameAndAPIKey(username:String,apiKey:String,funcptr:(data: NSData?, response: NSURLResponse?, error: NSError?)->Void) {
        let url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        let postdata = raxutils.dictionaryToJSONstring(
            ["auth": [
                "RAX-KSKEY:apiKeyCredentials":[
                    "username": username,
                    "apiKey": apiKey
                ]
            ]])
    
         NSURLSession.sharedSession().dataTaskWithRequest(_createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!, completionHandler: funcptr).resume()
    }
    
    class func latestAlarmStatesUsingSavedUsernameAndPassword()->NSMutableDictionary {//This is purely for the appleWatch.
        let results = NSMutableDictionary()
        let userdata = raxutils.getUserdata()
        if userdata == nil {
            results["error"] = "Userdata hasn't been saved in host iOS app"
            return results
        }
        let username = (NSKeyedUnarchiver.unarchiveObjectWithData(userdata) as! NSMutableDictionary!).objectForKey("access")!.objectForKey("user")!.objectForKey("name")! as! String
        let password:String! = raxutils.getPasswordFromKeychain()
        if password == nil {
            results["error"] = "Password wasn't saved in host iOS app."
            return results
        }
        let url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        let postdata = raxutils.dictionaryToJSONstring(
            ["auth": [
                "passwordCredentials":[
                    "username": username,
                    "password": password
                ]
            ]])
        var resp:NSURLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            results["error"] = "Couldn't get service catalog."
            results["response"] = resp
            return results
        }
        let serviceCatalog = ((try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!)
        GlobalState.instance.authtoken = serviceCatalog.objectForKey("access")!.objectForKey("token")!.objectForKey("id")! as! String
        for obj in (serviceCatalog.objectForKey("access")!.objectForKey("serviceCatalog")! as! NSArray) {
            if(obj.objectForKey("name")!.isEqualToString("cloudMonitoring")) {
                GlobalState.instance.monitoringEndpoint = (obj.objectForKey("endpoints") as! NSArray)[0].objectForKey("publicURL") as! String
                break
            }
        }
        results["latestAlarmStates"] = latestAlarmStates()
        return results
    }
    
    
    //TODO: This function is not actually used in the App right now.
    //Maybe add some UI to display the data from this function later?
    class func getAlarmHistory(alarm:NSDictionary) -> NSArray! {
        let ahistoricAlerts:NSMutableArray = NSMutableArray()
        let entityID:String = alarm["entity_id"] as! String
        let checkID:String = alarm["check_id"] as! String
        let alarmID:String = alarm["alarm_id"] as! String
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID+"/alarms/"+alarmID+"/notification_history/"+checkID
        var resp:NSURLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
        if jsonData == nil {
            return nil
        }
        for alert in jsonData["values"] as! NSArray {
            ahistoricAlerts.addObject(alert as! NSDictionary)
        }
        return ahistoricAlerts.copy() as! NSArray
    }
    
    class func getAlarmChangelogs(entityID:String!=nil) -> NSArray! {
        let changeLogs:NSMutableArray = NSMutableArray()
        var url = GlobalState.instance.monitoringEndpoint+"/changelogs/alarms/?"
        if entityID != nil {
            url += "entityId="+entityID+"&limit=1000"
        } else {
            url += "limit=1000"
        }
        var resp:NSURLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
        if jsonData == nil {
            return nil
        }
        for changelog in jsonData["values"] as! NSArray {
            changeLogs.addObject(changelog as! NSDictionary)
        }
        return changeLogs.copy() as! NSArray
    }
    
    class func refreshUserData(funcptr:(data: NSData?, response: NSURLResponse?, error: NSError?) -> Void) {
        let url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        let tenantID = GlobalState.instance.userdata.objectForKey("access")!.objectForKey("token")!.objectForKey("tenant")!.objectForKey("id")! as! String
        let authtoken = GlobalState.instance.userdata.objectForKey("access")!.objectForKey("token")!.objectForKey("id")! as! String
        let postdata = raxutils.dictionaryToJSONstring(
        ["auth": [
            "tenantId": tenantID,
            "token": [
                "id": authtoken
            ]
        ]])
        NSURLSession.sharedSession().dataTaskWithRequest(_createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!, completionHandler: funcptr).resume()
    }
    
    class func latestAlarmStates(isStreaming:Bool=false, updateGlobal:Bool=true) -> NSMutableDictionary! {
        let results = NSMutableDictionary()
        var url:String
        //Why do I use the website endpoint for streaming? Because an authtoken can expire at any random time after 24hrs.
        //But it appears that by calling extend_session can keep the websessionID alive for 12hrs from the point of time
        //I use the extend_session API. So, I rather do that instead of just using the authtoken that might fail soon afterwards.
        //A known 12hr limit versus a 24hrs limit that might be 20 minutes away from expiring.
        if isStreaming  {
            url = "https://mycloud.rackspace.com/proxy/rax:monitor,cloudMonitoring/views/latest_alarm_states?limit=1000"
        } else {
            url = GlobalState.instance.monitoringEndpoint+"/views/latest_alarm_states?limit=1000"
        }
        var resp:NSURLResponse? = nil

        var severity = ""
        var alarmstatelist:NSArray! = nil
        var alarmState:String = ""
        var allCriticalAlarms:NSMutableArray = NSMutableArray()
        var allWarningAlarms:NSMutableArray = NSMutableArray()
        var allOkAlarms:NSMutableArray = NSMutableArray()
        var allUnknownAlarms:NSMutableArray = NSMutableArray()
        let allAlarmsFoundOnEntity:NSMutableArray = NSMutableArray()
        
        let criticalAlarms:NSMutableArray = NSMutableArray()
        let warningAlarms:NSMutableArray = NSMutableArray()
        let okAlarms:NSMutableArray = NSMutableArray()
        let unknownAlarms:NSMutableArray = NSMutableArray()
        
        let allEntities = NSMutableArray()
        var okEntities = NSMutableArray()
        var warningEntities = NSMutableArray()
        var criticalEntities = NSMutableArray()
        var unknownEntities = NSMutableArray()
        
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }

        if(nsdata == nil || resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200  ) {
            return nil
        }
        let jsonData = (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
        if jsonData == nil {
            return nil
        }
        for entity in (jsonData.objectForKey("values") as! NSArray) {
            criticalAlarms.removeAllObjects()
            warningAlarms.removeAllObjects()
            okAlarms.removeAllObjects()
            unknownAlarms.removeAllObjects()
            allAlarmsFoundOnEntity.removeAllObjects()
            severity = ""
            alarmstatelist = (entity as! NSDictionary).objectForKey("latest_alarm_states") as! NSArray
            if(alarmstatelist.count == 0) {
                continue
            }
            for event in alarmstatelist {
                severity += ":"
                alarmState = (event.objectForKey("state") as! String).lowercaseString
                severity += alarmState
                if(alarmState.rangeOfString("ok") != nil) {
                    event.setObject(UIColor(red: 0, green: 0.5, blue: 0, alpha: 1), forKey: "UIColor")
                    okAlarms.addObject(event)
                    allOkAlarms.addObject(event)
                } else if(alarmState.rangeOfString("warning") != nil) {
                    event.setObject(UIColor.orangeColor(), forKey: "UIColor")
                    warningAlarms.addObject(event)
                    allWarningAlarms.addObject(event)
                } else if(alarmState.rangeOfString("critical") != nil) {
                    event.setObject(UIColor.redColor(), forKey: "UIColor")
                    allCriticalAlarms.addObject(event)
                    criticalAlarms.addObject(event)
                } else {//This alarm is in a state that we don't know about.
                    event.setObject(UIColor.blueColor(), forKey: "UIColor")
                    unknownAlarms.addObject(event)
                    allUnknownAlarms.addObject(event)
                }
                allAlarmsFoundOnEntity.addObject(event)
            }
            entity.setObject(raxutils.sortAlarmsBySeverityThenTime(allAlarmsFoundOnEntity), forKey:"allAlarms")
            entity.setObject(criticalAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "criticalAlarms")
            entity.setObject(warningAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "warningAlarms")
            entity.setObject(okAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "okAlarms")
            entity.setObject(unknownAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "unknownAlarms")
            if(unknownAlarms.count > 0 ) {
                entity.setValue("????", forKey: "state")
                unknownEntities.addObject(entity)
            } else if(severity.rangeOfString(":critical") != nil) {
                entity.setValue("CRIT", forKey: "state")
                criticalEntities.addObject(entity)
            } else if(severity.rangeOfString(":warning") != nil) {
                warningEntities.addObject(entity)
                entity.setValue("WARN", forKey: "state")
            } else {
                entity.setValue("OK", forKey: "state")
                okEntities.addObject(entity)
            }
            allEntities.addObject(entity)
        }
        unknownEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(unknownEntities))
        criticalEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(criticalEntities))
        warningEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(warningEntities))
        okEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(okEntities))
        allCriticalAlarms = NSMutableArray(array: allCriticalAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        allWarningAlarms = NSMutableArray(array: allWarningAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        allOkAlarms = NSMutableArray(array: allOkAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        allUnknownAlarms = NSMutableArray(array: allUnknownAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        results["allEntities"] = raxutils.sortEntitiesBySeverityThenTime(allEntities)
        results["unknownEntities"] = unknownEntities
        results["criticalEntities"] = criticalEntities
        results["warningEntities"] = warningEntities
        results["okEntities"] = okEntities
        results["allCriticalAlarms"] = allCriticalAlarms
        results["allWarningAlarms"] = allWarningAlarms
        results["allOkAlarms"] = allOkAlarms
        results["allUnknownAlarms"] = allUnknownAlarms
        if updateGlobal {
            GlobalState.instance.latestAlarmStates = results
        }
        return results
    }
    
    class func getAgentInfoBasic(agentID:String) -> NSDictionary! {
        let url = "https://mycloud.rackspace.com/proxy/rax:monitor,cloudMonitoring/views/agent_host_info/?include=memory&include=system&include=cpus&include=filesystems&agentId="+agentID+"&sampleCpus=true"
        var resp:NSURLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
    }
    
    class func getSupportedAgentInfoTypes(agentID:String) -> NSDictionary! {
        let url = GlobalState.instance.monitoringEndpoint+"/agents/"+agentID+"/host_info_types"
        var resp:NSURLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
    }
    
    class func getAgentInfoByType(agentID:String, type:String) -> NSDictionary! {
        let url = GlobalState.instance.monitoringEndpoint+"/agents/"+agentID+"/host_info/"+type
        var resp:NSURLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
    }
    
    class func getEntity(entityID:String) -> NSDictionary! {
        var resp:NSURLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
    }
 
    class func getCheck(entityid:String, checkid:String) -> NSDictionary! {
        var nsdata:NSData!
        var resp:NSURLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityid+"/checks/"+checkid
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
    }
    
    class func getAlarm(entityID:String, alarmID:String) -> NSMutableDictionary! {
        var resp:NSURLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID+"/alarms/"+alarmID
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSMutableDictionary!
    }
    
    class func getNotificationPlan(np_id:String) -> NSDictionary! {
        var resp:NSURLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/notification_plans/"+np_id
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
    }
    
    class func test_check_or_alarm(entityid:String, postdata:String, targetType:String) -> NSData! {
        var nsdata:NSData!
        var resp:NSURLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityid+"/test-"+targetType
        do {
            nsdata = try self.sendSynchronousRequest(self._createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!,
                returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            nsdata = nil
        }
        return nsdata
    }
    
    class func extend_session(reason:String="") -> String! {
        var responseBody:String! = nil
        var resp:NSURLResponse? = nil
        var url:String = "https://mycloud.rackspace.com/cloud/"
        var data:NSData! = nil
        url.appendContentsOf(GlobalState.instance.userdata.objectForKey("access")!
            .objectForKey("token")!.objectForKey("tenant")!.objectForKey("id")! as! String)
        url.appendContentsOf("/extend_session?window_hash=rackyview_iOSapp&reason="+reason)
        do {
            data = try self.sendSynchronousRequest(
                self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: "text/html; charset=utf-8")!,
                returningResponse:&resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            responseBody = NSString(data: data, encoding: NSUTF8StringEncoding) as String!
        }
        return responseBody
    }
    
    class func _doProxyRequest(url:String) -> NSData! {
        var resp:NSURLResponse? = nil
        var data:NSData!
        do {
            data = try self.sendSynchronousRequest(_createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                    returningResponse: &resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            data = nil
        }
        return data
    }
    
    class func getServerFlavor(server:NSDictionary) -> NSDictionary! {
        var flavor:NSDictionary! = nil
        var url:String = server["APIendpoint"] as! NSString as String
        url.appendContentsOf("/flavors/")
        url.appendContentsOf(((server["server"] as! NSDictionary)["flavor"] as! NSDictionary)["id"] as! NSString as String)
        var resp:NSURLResponse? = nil
        var data:NSData!
        do {
            data = try self.sendSynchronousRequest(_createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            flavor = (try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
        }
        return flavor
    }
    
    class func getServerImage(server:NSDictionary) -> NSDictionary! {
        var image:NSDictionary!
        var url:String = server["APIendpoint"] as! NSString as String
        url.appendContentsOf("/images/")
        url.appendContentsOf(((server["server"] as! NSDictionary)["image"] as! NSDictionary)["id"] as! NSString as String)
        var resp:NSURLResponse? = nil
        var data:NSData!
        do {
            data = try self.sendSynchronousRequest(_createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            image = (try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
        }
        return image
    }
    
    class func serveraction(server:NSDictionary, postdata:String, funcptr:( data: NSData?, response: NSURLResponse?,error: NSError?) -> Void) {
        var url:String = server["APIendpoint"] as! NSString as String
        url.appendContentsOf("/servers/")
        url.appendContentsOf((server["server"] as! NSDictionary)["id"] as! NSString as String)
        url.appendContentsOf("/action")
        NSURLSession.sharedSession().dataTaskWithRequest(_createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!, completionHandler: funcptr).resume()
    }
    
    
    class func get_tickets_summary () -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/summary")
    }
    
    class func get_tickets_by_status(t_status:String) -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets?status="+t_status)
    }
    
    class func get_ticket_details(t_id:String) -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id)
    }
    
    class func get_ticket_categories() -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/ticket-categories")
    }
    
    
    class func createTicket(primaryCategoryName:String,primaryCategoryID:String,subCategoryName:String,subCategoryID:String,ticketSubject:String,ticketMessageBody:String) -> String! {
        let url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets"
        var newTicketID:String!
        var postdata:String = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken
        postdata += "&data="
        postdata += raxutils.dictionaryToJSONstring(
            ["ticket": [
                "category": [
                    "id": primaryCategoryID,
                    "name": primaryCategoryName,
                    "sub-category": [
                        "id": subCategoryID,
                        "name": subCategoryName
                    ]
            ],
            "subject": ticketSubject,
            "description": ticketMessageBody
        ]]).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        var resp:NSURLResponse? = nil
        do {
           try self.sendSynchronousRequest(_createRequest("POST", url: url, data:postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=UTF-8")!,returningResponse: &resp)
        } catch _ as NSError {
            //Nothing
        }
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 201 ) {
            let locationHeader:String! = (resp as? NSHTTPURLResponse)?.allHeaderFields["Location"] as? String
            let range = (try! NSRegularExpression(pattern:"/v1/tickets/(\\S+)", options:[])).firstMatchInString(locationHeader, options: [], range: NSMakeRange(0, locationHeader.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)))?.rangeAtIndex(1)
            newTicketID = (locationHeader as NSString).substringWithRange(NSMakeRange((range?.location)!, (range?.length)!))
        }
        return newTicketID
    }
    
    class func submitTicketComment(t_id:String,commentText:String, funcptr:( data: NSData?, response: NSURLResponse?, error: NSError?) -> Void) {
        let url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id+"/comments"
        var postdata = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken
        postdata += "&data="
        postdata += raxutils.dictionaryToJSONstring([
            "comment": [
                "type": "TextCommentForCreateType",
                "text": commentText
            ]
        ]).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        NSURLSession.sharedSession().dataTaskWithRequest(_createRequest("POST", url: url, data: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=utf-8")!, completionHandler: funcptr).resume()
    }
    
    class func closeTicket(t_id:String, rating:Int, comment:String) -> Int {
        let url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id+"/close"
        var responseCode:Int = 0
        var postdata:String = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken+"&data="
        postdata += raxutils.dictionaryToJSONstring(
            ["ticket-rating": [
                "rating":String(rating),
                "comment": [
                    "text":comment
                ]
            ]
        ]).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        var resp:NSURLResponse? = nil
        do {
           try self.sendSynchronousRequest(_createRequest("PUT", url: url, data:postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=UTF-8")!,returningResponse: &resp)
        } catch _ as NSError {
        //nothing
        }
        if(resp != nil) {
            responseCode = (resp as! NSHTTPURLResponse).statusCode
        }
        return responseCode
    }
    
    class func listServerDetails( funcptr:(servers:NSArray,errors:NSArray)->Void ){
        let serverlist:NSMutableArray = NSMutableArray()
        let errorlist:NSMutableArray = NSMutableArray()
        let q = NSOperationQueue()
        q.maxConcurrentOperationCount = 1
        q.suspended = true
        for ep in GlobalState.instance.serverEndpoints {
            q.addOperationWithBlock {
                let url = String(ep.objectForKey("publicURL") as! NSString)+"/servers/detail"
                var resp:NSURLResponse? = nil
                var err:NSError? = nil
                var data:NSData!
                do {
                    data = try self.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                                        returningResponse: &resp)
                } catch let error as NSError {
                    err = error
                    data = nil
                } catch {
                    fatalError()
                }
                if err != nil {
                    errorlist.addObject(err!)
                }
                if(data == nil) {
                    return
                }
                let serverdata:NSDictionary! = (try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
                if(serverdata == nil) {
                    return
                }
                var dentry:NSMutableDictionary!
                for s in serverdata.objectForKey("servers") as! NSArray {
                    dentry = NSMutableDictionary()
                    dentry.setValue(ep.objectForKey("region") as! String, forKeyPath: "region")
                    dentry.setValue(s, forKeyPath: "server")
                    dentry.setValue(ep.objectForKey("publicURL") as! NSString, forKeyPath: "APIendpoint")
                    serverlist.addObject(dentry)
                }
            }
        }
        q.suspended = false
        q.waitUntilAllOperationsAreFinished()
        funcptr(servers:serverlist.copy() as! NSArray,errors:errorlist.copy() as! NSArray)
    }
}