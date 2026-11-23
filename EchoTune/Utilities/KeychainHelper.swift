//
//  KeychainHelper.swift
//  EchoTune
//
//  Secure storage for API keys using macOS Keychain
//
//  TEST HOST BYPASS
//  -----------------
//  Under `xcodebuild test` the host app runs without a signing identity that can
//  reach the login keychain, so every `SecItemAdd`/`SecItemCopyMatching` either
//  blocks on `securityd` or returns `errSecInteractionNotAllowed`, which used to
//  hang CI for minutes. When we detect a test host we swap the Security
//  framework for an in-memory dictionary. Production behaviour is unchanged.
//

import Foundation
import Security

struct KeychainHelper {
    private static let service = "com.echotune.EchoTune"

    /// True when running inside XCTest / Swift Testing / a UI-test host.
    static let isTestHost: Bool = {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || env["XCTestBundlePath"] != nil
            || env["ECHOTUNE_TEST_HOST"] == "1"
    }()

    /// In-memory stand-in used only under `isTestHost`.
    private final class InMemoryStore {
        static let shared = InMemoryStore()
        private let lock = NSLock()
        private var storage: [String: String] = [:]
        private init() {}

        func set(_ value: String, key: String) {
            lock.lock(); defer { lock.unlock() }
            storage[key] = value
        }

        func get(_ key: String) -> String? {
            lock.lock(); defer { lock.unlock() }
            return storage[key]
        }

        func remove(_ key: String) {
            lock.lock(); defer { lock.unlock() }
            storage.removeValue(forKey: key)
        }

        func removeAll() {
            lock.lock(); defer { lock.unlock() }
            storage.removeAll()
        }
    }

    /// Test-only: wipe the in-memory stand-in between test cases.
    static func resetInMemoryStoreForTesting() {
        InMemoryStore.shared.removeAll()
    }

    static func save(_ value: String, forKey key: String) {
        if isTestHost {
            InMemoryStore.shared.set(value, key: key)
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
            return InMemoryStore.shared.get(key) ?? ""
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
            InMemoryStore.shared.remove(key)
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
