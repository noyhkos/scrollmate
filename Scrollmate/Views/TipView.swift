import SwiftUI
import StoreKit

struct TipView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreKitManager.shared

    private let tiers: [TipTier] = [.bronze, .silver, .gold, .emerald, .diamond]
    @State private var selectedTier: TipTier = .bronze

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "#1c1c1c").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundColor(.appTextPrimary)
                            .padding(.top, 8)

                        Text("tip.title")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundColor(.appTextPrimary)

                        Text("tip.subtitle")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)

                    // Tier cards
                    VStack(spacing: 10) {
                        ForEach(tiers, id: \.rawValue) { tier in
                            TierCard(
                                tier: tier,
                                priceLabel: store.priceLabel(for: tier),
                                isSelected: selectedTier == tier,
                                isPurchased: SharedStorage.shared.purchasedTier >= tier
                            )
                            .onTapGesture { selectedTier = tier }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Error message
                    if let error = store.purchaseError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.bottom, 8)
                    }

                    // CTA
                    Button {
                        Task {
                            if let product = store.products.first(where: { $0.id == selectedTier.productId }) {
                                await store.purchase(product)
                                if SharedStorage.shared.purchasedTier >= selectedTier {
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Text("\(store.priceLabel(for: selectedTier)) \(String(localized: "tip.cta"))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(store.isPurchasing ? 0 : 1)

                            if store.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(store.products.isEmpty ? Color.gray : Color.appAccent)
                        )
                    }
                    .disabled(store.isPurchasing || store.products.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // Restore
                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Text("tip.restore")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.appTextSecondary.opacity(0.5))
                    }
                    .disabled(store.isPurchasing)
                    .padding(.bottom, 32)
                }
                .padding(.top, 92)
            }
        }
        .task {
            await store.loadProducts()
        }
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    let tier: TipTier
    let priceLabel: String
    let isSelected: Bool
    let isPurchased: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Ring preview
            ZStack {
                Circle()
                    .fill(Color(hex: "#111111"))
                    .frame(width: 44, height: 44)
                if let gradient = tier.ringGradient {
                    Circle()
                        .strokeBorder(gradient, lineWidth: 4)
                        .frame(width: 44, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tier.labelKey)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                Text(priceLabel)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            if isPurchased {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.appAccent)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.appAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#111111"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSelected ? Color.appAccent : Color.appBorder,
                            lineWidth: 1.5
                        )
                )
        )
    }
}
