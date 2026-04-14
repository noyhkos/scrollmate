import SwiftUI

struct TipView: View {
    @Environment(\.dismiss) private var dismiss

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
                    .padding(.bottom, 38)

                    // Tier cards list
                    VStack(spacing: 10) {
                        ForEach(tiers, id: \.rawValue) { tier in
                            TierCard(tier: tier, isSelected: selectedTier == tier)
                                .onTapGesture { selectedTier = tier }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // CTA
                    Button {
                        // StoreKit purchase — implement after App Store Connect setup
                        SharedStorage.shared.purchasedTier = selectedTier
                        dismiss()
                    } label: {
                        Text("\(selectedTier.price) 후원하기")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appAccent)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    // Restore
                    Button {
                        // StoreKit restore — implement after App Store Connect setup
                    } label: {
                        Text("tip.restore")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.appTextSecondary.opacity(0.5))
                    }
                    .padding(.bottom, 32)
                }
                .padding(.top, 62)
            }
        }
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    let tier: TipTier
    let isSelected: Bool

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
                Text(tier.price)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            if isSelected {
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
