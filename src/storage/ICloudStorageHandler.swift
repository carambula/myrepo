/**
 * iCloud Storage Handler for iOS/macOS
 * 
 * This Swift code integrates with NSUbiquitousKeyValueStore
 * to provide iCloud-synced storage for min apps.
 * 
 * Setup:
 * 1. Enable iCloud in Xcode project capabilities
 * 2. Enable "Key-value storage" in iCloud services
 * 3. Add this handler to your WKWebView configuration
 * 4. Settings will automatically sync via iCloud
 */

import Foundation
import WebKit

class ICloudStorageHandler: NSObject, WKScriptMessageHandler {
    
    // Reference to iCloud key-value store
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    
    // Initialize and start observing iCloud changes
    override init() {
        super.init()
        
        // Observe iCloud changes to update UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
        
        // Synchronize with iCloud on init
        iCloudStore.synchronize()
    }
    
    // Handle messages from JavaScript
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let messageBody = message.body as? [String: Any],
              let action = messageBody["action"] as? String,
              let callbackId = messageBody["callbackId"] as? Int
        else {
            return
        }
        
        switch action {
        case "getItem":
            handleGetItem(messageBody: messageBody, callbackId: callbackId)
        case "setItem":
            handleSetItem(messageBody: messageBody, callbackId: callbackId)
        case "removeItem":
            handleRemoveItem(messageBody: messageBody, callbackId: callbackId)
        case "clear":
            handleClear(callbackId: callbackId)
        case "keys":
            handleKeys(callbackId: callbackId)
        default:
            sendResponse(
                callbackId: callbackId,
                value: nil,
                error: "Unknown action: \(action)"
            )
        }
    }
    
    // Get item from iCloud
    private func handleGetItem(messageBody: [String: Any], callbackId: Int) {
        guard let key = messageBody["key"] as? String else {
            sendResponse(callbackId: callbackId, value: nil, error: "Missing key")
            return
        }
        
        let value = iCloudStore.string(forKey: key)
        sendResponse(callbackId: callbackId, value: value, error: nil)
    }
    
    // Set item in iCloud
    private func handleSetItem(messageBody: [String: Any], callbackId: Int) {
        guard let key = messageBody["key"] as? String,
              let value = messageBody["value"] as? String
        else {
            sendResponse(callbackId: callbackId, value: nil, error: "Missing key or value")
            return
        }
        
        iCloudStore.set(value, forKey: key)
        
        // Synchronize immediately for faster sync
        let synced = iCloudStore.synchronize()
        
        if synced {
            sendResponse(callbackId: callbackId, value: true, error: nil)
        } else {
            sendResponse(
                callbackId: callbackId,
                value: nil,
                error: "Failed to sync to iCloud"
            )
        }
    }
    
    // Remove item from iCloud
    private func handleRemoveItem(messageBody: [String: Any], callbackId: Int) {
        guard let key = messageBody["key"] as? String else {
            sendResponse(callbackId: callbackId, value: nil, error: "Missing key")
            return
        }
        
        iCloudStore.removeObject(forKey: key)
        iCloudStore.synchronize()
        
        sendResponse(callbackId: callbackId, value: true, error: nil)
    }
    
    // Clear all items from iCloud
    private func handleClear(callbackId: Int) {
        let dictionary = iCloudStore.dictionaryRepresentation
        
        for key in dictionary.keys {
            iCloudStore.removeObject(forKey: key)
        }
        
        iCloudStore.synchronize()
        sendResponse(callbackId: callbackId, value: true, error: nil)
    }
    
    // Get all keys from iCloud
    private func handleKeys(callbackId: Int) {
        let dictionary = iCloudStore.dictionaryRepresentation
        let keys = Array(dictionary.keys)
        
        sendResponse(callbackId: callbackId, value: keys, error: nil)
    }
    
    // Send response back to JavaScript
    private func sendResponse(
        callbackId: Int,
        value: Any?,
        error: String?
    ) {
        guard let webView = getWebView() else { return }
        
        var response: [String: Any] = ["callbackId": callbackId]
        
        if let error = error {
            response["error"] = error
        } else if let value = value {
            response["value"] = value
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: response),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let script = "window.handleICloudStorageResponse(\(jsonString));"
            
            DispatchQueue.main.async {
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }
    
    // Handle iCloud changes from other devices
    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        guard let webView = getWebView(),
              let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        else {
            return
        }
        
        // Only handle external changes (from other devices)
        if changeReason == NSUbiquitousKeyValueStoreServerChange ||
           changeReason == NSUbiquitousKeyValueStoreInitialSyncChange {
            
            // Get changed keys
            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                
                // Notify JavaScript about the changes
                let script = """
                    if (window.handleICloudSync) {
                        window.handleICloudSync({
                            changedKeys: \(jsonStringArray(changedKeys)),
                            reason: '\(changeReason == NSUbiquitousKeyValueStoreServerChange ? "server" : "initial")'
                        });
                    }
                """
                
                DispatchQueue.main.async {
                    webView.evaluateJavaScript(script, completionHandler: nil)
                }
            }
        }
    }
    
    // Helper to get web view (implement based on your app structure)
    private func getWebView() -> WKWebView? {
        // Return reference to your WKWebView instance
        // This should be set from your view controller
        return ICloudStorageHandler.webView
    }
    
    // Static reference to web view (set from view controller)
    static weak var webView: WKWebView?
    
    // Helper to convert string array to JSON
    private func jsonStringArray(_ array: [String]) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: array),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "[]"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

/**
 * Extension for easy WKWebView configuration
 */
extension WKWebView {
    func configureICloudStorage() {
        let handler = ICloudStorageHandler()
        
        // Store reference to web view
        ICloudStorageHandler.webView = self
        
        // Add script message handler
        configuration.userContentController.add(
            handler,
            name: "iCloudStorage"
        )
    }
}

/**
 * Example View Controller Setup
 */
/*
import UIKit
import WebKit

class MinAppViewController: UIViewController {
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create web view configuration
        let configuration = WKWebViewConfiguration()
        
        // Create web view
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        
        // Configure iCloud storage
        webView.configureICloudStorage()
        
        // Add to view
        view.addSubview(webView)
        
        // Load your app
        if let url = URL(string: "https://yourapp.com") {
            webView.load(URLRequest(url: url))
        }
    }
}
*/
