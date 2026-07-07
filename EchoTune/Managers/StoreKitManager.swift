//
//  StoreKitManager.swift
//  EchoTune
//
//  StoreKit 2 In-App Purchase Manager
//  Handles Pro unlock purchase for App Store distribution
//

import StoreKit
import SwiftUI
import Combine

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // Product IDs - Must match App Store Connect
    private let proUnlockID = "com.echotune.EchoTune.pro"

    // Published state
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var isPurchasing = false

    // Transaction listener
    private var transactionListener: Task<Void, Error>?

    private init() {
        debugLog("✓ StoreKitManager initialized")

        // Start listening for transactions
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        do {
            let loadedProducts = try await Product.products(for: [proUnlockID])
            products = loadedProducts
            debugLog("✓ Loaded \(products.count) products from App Store")

            if let product = products.first {
                debugLog("  Product: \(product.displayName) - \(product.displayPrice)")
            }
        } catch {
            debugLog("❌ Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        debugLog("🛒 Starting purchase for: \(product.id)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify transaction
            let transaction = try checkVerified(verification)

            // Update purchased products
            await updatePurchasedProducts()

            // Finish transaction
            await transaction.finish()

            debugLog("✅ Purchase successful: \(product.id)")

            // Notify app - LicenseManager will update
            NotificationCenter.default.post(
                name: NSNotification.Name("PurchaseCompleted"),
                object: nil
            )

            return true

        case .userCancelled:
            debugLog("⏸️ Purchase cancelled by user")
            return false

        case .pending:
            debugLog("⏳ Purchase pending approval")
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        debugLog("🔄 Restoring purchases...")

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()

            if isProUnlocked {
                debugLog("✅ Purchases restored - Pro unlocked")

                // Notify app
                NotificationCenter.default.post(
                    name: NSNotification.Name("PurchaseCompleted"),
                    object: nil
                )
            } else {
                debugLog("ℹ️ No purchases found to restore")
            }
        } catch {
            debugLog("❌ Restore failed: \(error)")
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()

                    debugLog("✓ Transaction update processed: \(transaction.productID)")
                } catch {
                    debugLog("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            debugLog("❌ Transaction failed verification")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Product Status

    func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if product is still valid (not revoked/refunded)
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                debugLog("❌ Failed to verify entitlement: \(error)")
            }
        }

        purchasedProductIDs = purchasedIDs

        if !purchasedIDs.isEmpty {
            debugLog("✓ Updated purchased products: \(purchasedIDs)")
        }
    }

    // MARK: - Helpers

    var isProUnlocked: Bool {
        purchasedProductIDs.contains(proUnlockID)
    }

    var proProduct: Product? {
        products.first { $0.id == proUnlockID }
    }
}

enum StoreError: Error, LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed. Please try again."
        }
    }
}
