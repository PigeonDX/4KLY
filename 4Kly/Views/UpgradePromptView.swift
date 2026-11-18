//
//  UpgradePromptView.swift
//  4Kly
//

import SwiftUI

struct UpgradePromptSheet: View {

    let promptInfo: UpgradePromptInfo?
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    // MARK: - License key state
    @State private var showKeyField: Bool = false
    @State private var licenseKeyInput: String = ""
    @State private var isActivating: Bool = false
    @State private var activationError: String?
    @State private var activated: Bool = false

    var body: some View {
        VStack(spacing: 20) {

            // Crown icon
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 24)

            Text("Unlock Premium Quality")
                .font(.title2.bold())

            // Two clickable tier cards
            HStack(spacing: 12) {

                // Free card — clicking closes popup
                Button(action: onDismiss) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Free")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Up to 720p")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Continue Free →")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue with free version")

                // Premium card — clicking opens upgrade URL
                Button(action: onUpgrade) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.purple)
                        Text("Premium")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text("Up to 4K & 8K")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Get Pro — $19.99 →")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Upgrade to Premium")
            }
            .padding(.horizontal, 20)

            Text("Your purchase supports independent development")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)

            Text("One-time payment · No subscription · Lifetime access")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)

            // ── Already have a key? ──────────────────────────────────────
            if showKeyField {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("4KLY-XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .frame(maxWidth: .infinity)

                        Button(action: activateKey) {
                            if isActivating {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Activate")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)
                    }

                    if let error = activationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    if activated {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Activated! Restart the app to apply.")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showKeyField = true }
                }) {
                    Text("Already have a key?")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)
        }
        .frame(width: 380, height: showKeyField ? 420 : 360)
        .animation(.easeInOut(duration: 0.2), value: showKeyField)
        .padding(.bottom, 20)
    }

    // MARK: - Activate license key

    private func activateKey() {
        let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !key.isEmpty else { return }

        isActivating = true
        activationError = nil

        Task {
            guard let url = URL(string: "https://4kly.com/api/activate") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["key": key])
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                if status == 200 {
                    // Store license locally so the free app knows user has upgraded
                    UserDefaults.standard.set(key, forKey: "com.4kly.license.key")
                    UserDefaults.standard.set(true, forKey: "com.4kly.license.activated")
                    activated = true
                    // Brief delay to show success, then close
                    try? await Task.sleep(for: .seconds(1.2))
                    onDismiss()
                } else {
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
                    activationError = json?["error"] ?? "Invalid license key. Please check and try again."
                }
            } catch {
                activationError = "Network error. Please check your connection."
            }

            isActivating = false
        }
    }
}

// MARK: - View Extension

extension View {
    func upgradePrompt(
        isPresented: Binding<Bool>,
        promptInfo: UpgradePromptInfo?,
        onUpgrade: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            UpgradePromptSheet(
                promptInfo: promptInfo,
                onUpgrade: onUpgrade,
                onDismiss: { isPresented.wrappedValue = false }
            )
        }
    }
}

#Preview {
    UpgradePromptSheet(
        promptInfo: UpgradePromptInfo(
            message: "Upgrade to Premium for 4K downloads.",
            upgradeURL: URL(string: "https://4kly.com")
        ),
        onUpgrade: {},
        onDismiss: {}
    )
}
