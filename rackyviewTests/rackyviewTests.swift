import UIKit
import XCTest
@testable import Rackyview

class rackyviewTests: XCTestCase {
    var isTestComplete:Bool = false
    let mySecretMessage:String = "Tatsunoko vs. Capcom"
    
    func waitForAsync() {
        let timeout = 30.0
        let startTime:NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        while(!isTestComplete){
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow:1))
            let elapsedTime:NSTimeInterval = NSDate.timeIntervalSinceReferenceDate() - startTime
            if(elapsedTime > timeout) {
                XCTFail("This unittest took too long. More than "+String(format:"%f", timeout)+" seconds")
                self.isTestComplete = true
                break
            }
        }
    }
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        self.isTestComplete = false
    }
    
    override func tearDown() {
        //Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_crypt() {
        let encrypted_data = raxutils.encryptData(mySecretMessage.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        let decrypted_data = raxutils.decryptData(encrypted_data)
        let decrypted_message = NSString(data: decrypted_data, encoding: NSUTF8StringEncoding) as String!
        if (decrypted_message != mySecretMessage) {
            XCTFail("Decrypted message: \(decrypted_message), doesn't equal  original: \(mySecretMessage)")
        }
    }
    
    func test_keychain() {
        raxutils.savePasswordToKeychain(mySecretMessage)
        let password = raxutils.getPasswordFromKeychain()
        if(password != mySecretMessage) {
            XCTFail("Returned password: \(password), doesn't equal original: \(mySecretMessage)")
        }
        
    }
    
    
    func test_xcdatamodel() {
        raxutils.deleteUserdata()
        if(raxutils.getUserdata() != nil) {
            XCTFail("Userdata should be nil, but it wasn't")
        }
        
        raxutils.saveUserdata(mySecretMessage.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        let returned_message = NSString(data: raxutils.getUserdata(), encoding: NSUTF8StringEncoding) as String!
        if(returned_message != mySecretMessage) {
            XCTFail("Returned password: \(returned_message), doesn't equal original: \(mySecretMessage)")
        }
    }
    
    /*func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }*/
}
