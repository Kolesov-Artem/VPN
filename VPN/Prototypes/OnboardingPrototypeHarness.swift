#if DEBUG
import SwiftUI

/// Isolated onboarding exploration — three genuinely different directions behind
/// a picker. Launch with `--prototype-onboarding`.
enum OnboardingPrototypeVariant: String, CaseIterable, Identifiable {
    case quiet = "Quiet"
    case editorial = "Editorial"
    case fluid = "Fluid"

    var id: String { rawValue }

    var axis: String {
        switch self {
        case .quiet: "Minimal motion, borders over fills"
        case .editorial: "Large type, generous whitespace"
        case .fluid: "Material chrome, spring entrance, press feedback"
        }
    }
}

struct OnboardingPrototypeHarness: View {
    @State private var selected = OnboardingPrototypeVariant.fluid
    @State private var route: AppRoute = .onboarding
    @State private var configurationURL = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            prototypeContext

            ProtoVariantPicker(selection: $selected)
                .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var prototypeContext: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                VelvetMapBackground(
                    selectedLocation: VPNLocation.samples[0],
                    isConnected: false,
                    atmosphere: .spinningGlobe,
                    bottomBackdropStyle: nil,
                    onPickCoordinate: { _ in }
                )

                VStack(spacing: 0) {
                    HStack {
                        VelvetBrand()
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer()

                    variantContent
                        .padding(.horizontal, VelvetTheme.horizontalPadding)
                        .padding(.top, 20)
                        .padding(.bottom, max(safeBottom, VelvetTheme.minimumBottomMargin) + 72)
                        .frame(maxWidth: .infinity)
                        .background { OnboardingContentBackdrop() }
                        .id(selected)
                }
            }
        }
    }

    @ViewBuilder
    private var variantContent: some View {
        switch selected {
        case .quiet:
            OnboardingQuietVariant(
                route: $route,
                configurationURL: $configurationURL
            )
        case .editorial:
            OnboardingEditorialVariant(
                route: $route,
                configurationURL: $configurationURL
            )
        case .fluid:
            OnboardingFluidVariant(
                route: $route,
                configurationURL: $configurationURL
            )
        }
    }
}

// MARK: - Picker (adapted from prototype/PICKER.md — harness chrome, not a contestant)

private struct ProtoVariantPicker: View {
    @Binding var selection: OnboardingPrototypeVariant

    var body: some View {
        HStack(spacing: 2) {
            ForEach(OnboardingPrototypeVariant.allCases) { variant in
                Button {
                    selection = variant
                } label: {
                    Text(variant.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == variant ? .white : .white.opacity(0.62))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if selection == variant {
                                Capsule()
                                    .fill(.white.opacity(0.18))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == variant ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(.black.opacity(0.82), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Prototype variants")
    }
}

// MARK: - Quiet — borders, no entrance motion

private struct OnboardingQuietVariant: View {
    @Binding var route: AppRoute
    @Binding var configurationURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connect VPN")
                .font(.title3.weight(.semibold))

            borderedField

            HStack(spacing: 10) {
                quietSecondary("Upload", symbol: "folder")
                quietSecondary("Scan", symbol: "qrcode.viewfinder")
            }

            quietTrialCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var borderedField: some View {
        HStack {
            TextField("Configuration URL", text: $configurationURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Paste") {
                configurationURL = "https://yourvpn.34945"
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .overlay {
            RoundedRectangle(cornerRadius: VelvetTheme.controlRadius)
                .stroke(Color(.separator), lineWidth: 1)
        }
    }

    private func quietSecondary(_ title: String, symbol: String) -> some View {
        Button {} label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay {
                    RoundedRectangle(cornerRadius: VelvetTheme.controlRadius)
                        .stroke(Color(.separator), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var quietTrialCard: some View {
        Button {
            route = .home
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use Velvet VPN")
                        .font(.subheadline.weight(.semibold))
                    Text("3 days free trial")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .overlay {
                RoundedRectangle(cornerRadius: VelvetTheme.controlRadius)
                    .stroke(VelvetTheme.accent.opacity(0.45), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editorial — large type, whitespace

private struct OnboardingEditorialVariant: View {
    @Binding var route: AppRoute
    @Binding var configurationURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect")
                    .font(.largeTitle.weight(.bold))
                Text("Paste a configuration link or import from file.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Configuration")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                TextField("https://yourvpn.example", text: $configurationURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3)
                    .padding(.vertical, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                    }
            }

            HStack(spacing: 20) {
                editorialLink("Upload", symbol: "folder")
                editorialLink("Scan QR", symbol: "qrcode.viewfinder")
            }

            Spacer(minLength: 8)

            Button {
                route = .home
            } label: {
                Text("Start free trial")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(VelvetProminentButtonStyle(tint: VelvetTheme.accent))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editorialLink(_ title: String, symbol: String) -> some View {
        Button {} label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelvetTheme.accent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fluid — material, staggered spring entrance (Apple fluid + Emil craft)

private struct OnboardingFluidVariant: View {
    @Binding var route: AppRoute
    @Binding var configurationURL: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 24) {
            staggered(0) {
                Text("Connect VPN")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            staggered(1) {
                fluidField
            }

            staggered(2) {
                HStack(spacing: 12) {
                    fluidSecondary("Upload", symbol: "folder")
                    fluidSecondary("Scan", symbol: "qrcode.viewfinder")
                }
            }

            staggered(3) {
                fluidTrialCard
            }
        }
        .onAppear {
            guard !reduceMotion else {
                revealed = true
                return
            }
            withAnimation(VelvetMotion.route(reduceMotion: false)) {
                revealed = true
            }
        }
    }

    private func staggered<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : VelvetMotion.entranceOffsetY * 0.6)
            .animation(
                VelvetMotion.easeOut(duration: VelvetMotion.contentDuration)
                    .delay(Double(index) * VelvetMotion.rowStaggerStep + VelvetMotion.rowStaggerBase),
                value: revealed
            )
    }

    private var fluidField: some View {
        HStack(spacing: 0) {
            TextField("https://yourvpn.example", text: $configurationURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)

            Button("Paste") {
                configurationURL = "https://yourvpn.34945"
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 20)
            .frame(minHeight: 56)
            .background(.regularMaterial)
        }
        .frame(minHeight: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: VelvetTheme.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: VelvetTheme.controlRadius)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func fluidSecondary(_ title: String, symbol: String) -> some View {
        Button {} label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: VelvetTheme.controlRadius))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var fluidTrialCard: some View {
        Button {
            route = .home
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Velvet VPN")
                        .font(.subheadline.weight(.semibold))
                    Text("3 days free trial")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(VelvetTheme.accent, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
#endif
