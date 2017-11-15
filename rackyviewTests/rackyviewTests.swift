import UIKit
import XCTest
//@testable import Rackyview

class rackyviewTests: XCTestCase {
    var isTestComplete:Bool = false
    let mySecretMessage:String = "Tatsunoko vs. Capcom"
    
    func waitForAsync() {
        let timeout = 30.0
        let startTime:TimeInterval = NSDate.timeIntervalSinceReferenceDate
        while(!isTestComplete){
            RunLoop.current.run(until: NSDate(timeIntervalSinceNow:1) as Date)
            let elapsedTime:TimeInterval = NSDate.timeIntervalSinceReferenceDate - startTime
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
        let encrypted_data = raxutils.encryptData(plaindata: mySecretMessage.data(using: String.Encoding.utf8, allowLossyConversion: false)! as NSData)
        let decrypted_data = raxutils.decryptData(cipherdata: encrypted_data!)
        let decrypted_message = NSString(data: decrypted_data! as Data, encoding: String.Encoding.utf8.rawValue) as String!
        if (decrypted_message != mySecretMessage) {
            XCTFail("Decrypted message: \(String(describing: decrypted_message)), doesn't equal  original: \(mySecretMessage)")
        }
    }
    
    func test_keychain() {
        _ = raxutils.savePasswordToKeychain(password: mySecretMessage)
        let password = raxutils.getPasswordFromKeychain()
        if(password != mySecretMessage) {
            XCTFail("Returned password: \(String(describing: password)), doesn't equal original: \(mySecretMessage)")
        }
        
    }
    
    func test_xcdatamodel() {
        raxutils.deleteUserdata()
        if(raxutils.getUserdata() != nil) {
            XCTFail("Userdata should be nil, but it wasn't")
        }
        raxutils.saveUserdata(userdata: mySecretMessage.data(using: String.Encoding.utf8, allowLossyConversion: false)! as NSData)
        let returned_message = NSString(data: raxutils.getUserdata() as Data, encoding: String.Encoding.utf8.rawValue) as String!
        if(returned_message != mySecretMessage) {
            XCTFail("Returned password: \(String(describing: returned_message)), doesn't equal original: \(mySecretMessage)")
        }
    }
    
    /*func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }*/
}
