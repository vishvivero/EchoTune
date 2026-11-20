//
//  KeychainHelper.swift
//  EchoTune
//
//  Secure storage for API keys using macOS Keychain
//

import Foundation
import Security

struct KeychainHelper {
    private static let service = "com.echotune.EchoTune"
    private static var testMemoryStore: [String: String] = [:]

    private static var isTestHost: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestSessionIdentifier"] != nil
    }

    static func save(_ value: String, forKey key: String) {
        if isTestHost {
            testMemoryStore[key] = value
            return
        }
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    static func load(forKey key: String) -> String {
        if isTestHost {
            return testMemoryStore[key] ?? ""
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        
        return string
    }
    
    static func delete(forKey key: String) {
        if isTestHost {
            testMemoryStore.removeValue(forKey: key)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
