import SwiftUI

/// First-time setup and pairing. One screen per step; the step lives in
/// `AppModel` so rotation or a view rebuild never restarts pairing.
struct OnboardingView: View {
    let model: AppModel
    let step: OnboardingStep
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.fullScreenSize
            let safe = proxy.safeAreaInsets
            let landscape = size.width > size.height
            ZStack {
                palette.bg.ignoresSafeArea()
                screen
                    .frame(maxWidth: landscape ? 520 : .infinity)
                    .padding(insets(safe: safe, landscape: landscape))
                    .id(stepID)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 24)), removal: .opacity))
            }
            .animation(.easeOut(duration: 0.28), value: stepID)
            .ignoresSafeArea()
        }
    }

    /// Setup screens keep the original 24 pt sides and 34 pt bottom.
    private func insets(safe: EdgeInsets, landscape: Bool) -> EdgeInsets {
        if landscape {
            let side = max(safe.leading, safe.trailing, 24)
            return EdgeInsets(top: 16, leading: side, bottom: max(safe.bottom, 16), trailing: side)
        }
        return EdgeInsets(top: max(safe.top, 20), leading: 24, bottom: max(safe.bottom, 16), trailing: 24)
    }

    private var stepID: String {
        switch step {
        case .welcome: "welcome"
        case .finding: "finding"
        case .chooseCar: "choose"
        case .enterVIN: "vin"
        case .addKey: "addKey"
        case .confirmInCar: "confirm"
        case .paired: "paired"
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .welcome: WelcomeScreen(model: model)
        case .finding: FindingScreen(model: model)
        case .chooseCar: ChooseCarScreen(model: model)
        case let .enterVIN(expected): EnterVINScreen(model: model, expectedLocalName: expected)
        case let .addKey(identity): AddKeyScreen(model: model, identity: identity)
        case let .confirmInCar(identity):
            if case let .failed(message) = model.pairing.phase {
                PairFailedScreen(model: model, identity: identity, message: message)
            } else {
                ConfirmInCarScreen(model: model, identity: identity)
            }
        case let .paired(identity): PairedScreen(model: model, identity: identity)
        }
    }
}

// MARK: - Shared pieces

struct SetupTitle: View {
    let title: String
    var detail: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.64)
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.system(size: 17))
                    .lineSpacing(3.5)
                    .foregroundStyle(palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SetupBackBar: View {
    let model: AppModel
    var body: some View {
        HStack {
            CircleNavButton(glyph: .chevronLeft, label: String(localized: "Back")) { model.goBack() }
            Spacer()
        }
        .frame(height: 44)
    }
}

/// Spinner + status line at the bottom of waiting screens.
struct StatusLine: View {
    let text: String
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: 10) {
            ArcSpinner()
            Text(text).font(.system(size: 17)).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .accessibilityElement(children: .combine)
    }
}

/// Touchscreen with signal arcs above it, from the Pairing 2 mockup.
/// `failed` greys the screen and adds the attention badge (Pairing 2b).
struct CarIllustration: View {
    var failed = false
    @Environment(\.palette) private var palette

    var body: some View {
        let palette = palette
        Canvas { context, canvas in
            context.translateBy(x: (canvas.width - 180) / 2, y: (canvas.height - 140) / 2)
            func stroke(_ d: String, _ color: Color) {
                context.stroke(SVGPath.parse(d), with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            let screen = failed ? palette.text3 : palette.text
            if !failed {
                stroke("M72 30a26 26 0 0 1 36 0", palette.text3)
                stroke("M62 20a40 40 0 0 1 56 0", palette.fill2)
            }
            stroke("M49 48h82a9 9 0 0 1 9 9v46a9 9 0 0 1-9 9H49a9 9 0 0 1-9-9V57a9 9 0 0 1 9-9z", screen)
            stroke("M54 96h28", screen)
            stroke("M20 126h140", palette.fill2)
            if failed {
                context.fill(Path(ellipseIn: CGRect(x: 120, y: 28, width: 32, height: 32)), with: .color(palette.warn))
                context.stroke(SVGPath.parse("M136 36v9"), with: .color(palette.bg), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                context.fill(Path(ellipseIn: CGRect(x: 134.2, y: 49.7, width: 3.6, height: 3.6)), with: .color(palette.bg))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.panel))
        .accessibilityHidden(true)
    }
}

// MARK: - Screens

struct WelcomeScreen: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Image("VelaMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text("Vela")
                    .font(.system(size: 40, weight: .semibold))
                    .tracking(-1)
                    .foregroundStyle(palette.text)
                Text(String(localized: "A calm second screen for your Tesla."))
                    .font(.system(size: 19))
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
            }
            .padding(.bottom, 40)
            .frame(maxHeight: .infinity)
            VStack(spacing: 16) {
                PrimaryButton(title: String(localized: "Get started")) { model.advance(to: .finding) }
                Text(String(localized: "Connects to your car over Bluetooth. No account needed."))
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct FindingScreen: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            SetupBackBar(model: model)
            SetupTitle(
                title: String(localized: "Finding your Tesla"),
                detail: String(localized: "Stay near your car with Bluetooth on. This usually takes a few seconds.")
            )
            .padding(.top, 28)
            ZStack {
                Circle().strokeBorder(palette.fill, lineWidth: 1.5).frame(width: 264, height: 264)
                Circle().strokeBorder(palette.fill2, lineWidth: 1.5).frame(width: 176, height: 176)
                Circle().strokeBorder(palette.text3, lineWidth: 1.5).frame(width: 88, height: 88)
                Circle().fill(palette.text).frame(width: 16, height: 16)
            }
            .scaleEffect(0.85)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
            Button {
                model.advance(to: .chooseCar)
            } label: {
                ScannerStatusLine(scanner: model.scanner)
            }
            .buttonStyle(.plain)
        }
        .task(id: model.scanner.vehicles.isEmpty) {
            // Move on once a car shows up, after a beat so the screen reads.
            guard !model.scanner.vehicles.isEmpty else { return }
            try? await Task.sleep(for: .seconds(1.2))
            if case .finding = model.onboarding { model.advance(to: .chooseCar) }
        }
    }
}

/// "Searching nearby", or what's stopping the search.
struct ScannerStatusLine: View {
    let scanner: NearbyTeslaScanner
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch scanner.status {
        case .poweredOff:
            Text(String(localized: "Turn on Bluetooth to search"))
                .font(.system(size: 17)).foregroundStyle(palette.warn)
                .frame(maxWidth: .infinity, minHeight: 56)
        case .unauthorized:
            Button(String(localized: "Allow Bluetooth in Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.system(size: 17, weight: .medium)).foregroundStyle(palette.warn)
            .frame(maxWidth: .infinity, minHeight: 56)
        default:
            StatusLine(text: String(localized: "Searching nearby"))
        }
    }
}

struct ChooseCarScreen: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            SetupBackBar(model: model)
            SetupTitle(title: String(localized: "Choose your car"), detail: String(localized: "Pick the one you're sitting in. The closest car is listed first."))
                .padding(.top, 28)
            Hairline().padding(.top, 32)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    let cars = model.scanner.vehicles
                    ForEach(cars) { car in
                        Button {
                            model.advance(to: .enterVIN(expectedLocalName: car.localName))
                        } label: {
                            row(car)
                        }
                        .buttonStyle(.plain)
                    }
                    if cars.isEmpty {
                        ScannerStatusLine(scanner: model.scanner)
                            .frame(minHeight: 76)
                            .overlay(alignment: .bottom) { Hairline() }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Button(action: model.searchAgain) {
                Text(String(localized: "Search again"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Signal-strength tiers, not a distance: BLE signal strength can't give
    /// a trustworthy distance.
    private func row(_ car: NearbyTeslaScanner.Advertisement) -> some View {
        let (bars, tier): (Int, String) = switch car.rssi {
        case (-60)...: (4, String(localized: "Very close · likely the car you are in"))
        case -72 ..< -60: (3, String(localized: "Nearby"))
        case -84 ..< -72: (2, String(localized: "A bit farther"))
        default: (1, String(localized: "Far"))
        }
        return HStack(spacing: 16) {
            SignalBars(level: bars, on: palette.text, off: palette.fill2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Tesla").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
                Text(tier).font(.system(size: 15)).foregroundStyle(palette.text2)
            }
            Spacer()
            Icon(.chevronRight, size: 18).foregroundStyle(palette.text3)
        }
        .frame(minHeight: 76)
        .overlay(alignment: .bottom) { Hairline() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The advertisement doesn't carry the VIN and pairing is addressed by VIN,
/// so the user types it once. When they picked a car from the list, the VIN
/// must hash to that car's advertised name.
struct EnterVINScreen: View {
    let model: AppModel
    let expectedLocalName: String?
    @Environment(\.palette) private var palette
    @State private var text = ""
    @FocusState private var focused: Bool

    private enum Check {
        case typing
        case valid(VehicleIdentity)
        case format
        case mismatch
    }

    private var check: Check {
        let cleaned = text.uppercased().filter { !$0.isWhitespace }
        if cleaned.contains(where: { "IOQ".contains($0) }) { return .format }
        guard cleaned.count >= 17 else { return .typing }
        guard let vin = VehicleIdentity.normalize(cleaned) else { return .format }
        let identity = VehicleIdentity(vin: vin)
        if let expectedLocalName, identity.bleLocalName != expectedLocalName { return .mismatch }
        return .valid(identity)
    }

    var body: some View {
        let check = check
        let (message, bad): (String?, Bool) = switch check {
        case .typing: (nil, false)
        case let .valid(identity): (identity.modelName, false)
        case .format: (String(localized: "A VIN has 17 letters and numbers and never uses I, O or Q."), true)
        case .mismatch: (String(localized: "This VIN belongs to a different car than the one you picked. Check it, or go back and pick another car."), true)
        }
        let validIdentity: VehicleIdentity? = if case let .valid(identity) = check { identity } else { nil }
        VStack(spacing: 0) {
            SetupBackBar(model: model)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    SetupTitle(
                        title: String(localized: "Enter the VIN"),
                        detail: String(localized: "Vela needs the 17-character VIN to set up the key for this car. It stays on this phone.")
                    )
                    .padding(.top, 28)
                    TrackedLabel(text: String(localized: "VIN")).padding(.top, 32)
                    TextField("", text: $text)
                        .font(.system(size: 20, design: .monospaced))
                        .tracking(1.6)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.continue)
                        .focused($focused)
                        .foregroundStyle(palette.text)
                        .padding(.horizontal, 16)
                        .frame(height: 60)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.bg))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(bad ? palette.danger : focused || validIdentity != nil ? palette.text : palette.fill2, lineWidth: 2)
                        )
                        .padding(.top, 10)
                        .onSubmit { if let validIdentity { model.advance(to: .addKey(validIdentity)) } }
                        .onChange(of: text) { _, new in
                            let upper = String(new.uppercased().filter { !$0.isWhitespace }.prefix(17))
                            if upper != new { text = upper }
                        }
                        .accessibilityLabel(String(localized: "VIN"))
                    HStack(alignment: .top, spacing: 12) {
                        if let message {
                            HStack(alignment: .top, spacing: 8) {
                                Icon(bad ? .errorCircle : .check, size: 18)
                                    .foregroundStyle(bad ? palette.danger : palette.text)
                                    .padding(.top, 1)
                                Text(message)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(bad ? palette.danger : palette.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                        Text("\(text.count) / 17")
                            .font(.system(size: 15))
                            .monospacedDigit()
                            .foregroundStyle(palette.text2)
                    }
                    .padding(.top, 10)

                    TrackedLabel(text: String(localized: "WHERE TO FIND IT")).padding(.top, 32)
                    Hairline().padding(.top, 10)
                    findRow(String(localized: "On the touchscreen: Controls › Software"))
                    findRow(String(localized: "Bottom of the windshield, driver's side"))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: String(localized: "Continue"), enabled: validIdentity != nil) {
                if let validIdentity {
                    focused = false
                    model.advance(to: .addKey(validIdentity))
                }
            }
            .padding(.top, 12)
        }
        .onAppear { focused = true }
    }

    private func findRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .overlay(alignment: .bottom) { Hairline() }
    }
}

struct AddKeyScreen: View {
    let model: AppModel
    let identity: VehicleIdentity
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            SetupBackBar(model: model)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    Icon(.key, size: 40, lineWidth: 1.7)
                        .foregroundStyle(palette.text)
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(palette.fill))
                        .padding(.top, 36)
                    SetupTitle(
                        title: String(localized: "Add Vela as a key"),
                        detail: String(localized: "Your car adds Vela as a phone key. Vela uses it to show driving and charging info, and for the controls you use in the app.")
                    )
                    .padding(.top, 28)
                    Hairline().padding(.top, 32)
                    checkRow(String(localized: "Works without internet"))
                    checkRow(String(localized: "Remove it anytime in your car's Locks menu"))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: String(localized: "Continue")) { model.startPairing(identity) }
                .padding(.top, 12)
        }
    }

    private func checkRow(_ text: String) -> some View {
        HStack(spacing: 14) {
            Icon(.check, size: 22).foregroundStyle(palette.text)
            Text(text).font(.system(size: 17)).foregroundStyle(palette.text)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct ConfirmInCarScreen: View {
    let model: AppModel
    let identity: VehicleIdentity
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(String(localized: "Cancel")) { model.cancelPairing() }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(height: 44)
                Spacer()
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    CarIllustration().padding(.top, 28)
                    SetupTitle(title: String(localized: "Confirm in your car")).padding(.top, 32)
                    VStack(alignment: .leading, spacing: 18) {
                        stepRow(1, String(localized: "Sit in the car with the touchscreen awake."))
                        stepRow(2, String(localized: "Tap your key card on the card reader."))
                        stepRow(3, String(localized: "Tap Confirm on the touchscreen."))
                    }
                    .padding(.top, 24)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            StatusLine(text: model.pairing.phase == .waitingForApproval ? String(localized: "Waiting for your car") : String(localized: "Connecting to your car"))
        }
        .onChange(of: model.pairing.phase) { _, phase in
            if phase == .paired { model.pairingSucceeded(identity) }
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(number))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(width: 28, height: 28)
                .background(Circle().fill(palette.fill))
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(palette.text)
                .padding(.top, 3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Pairing 2b: the car didn't confirm, or couldn't be reached.
struct PairFailedScreen: View {
    let model: AppModel
    let identity: VehicleIdentity
    let message: PairingSession.Failure
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(String(localized: "Cancel")) { model.cancelPairing() }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(height: 44)
                Spacer()
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    CarIllustration(failed: true).padding(.top, 28)
                    SetupTitle(title: message.title, detail: message.detail).padding(.top, 32)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 8) {
                PrimaryButton(title: String(localized: "Try again")) { model.pairing.start(identity) }
                Button(String(localized: "Check the VIN")) { model.recheckVIN() }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
        }
    }
}

struct PairedScreen: View {
    let model: AppModel
    let identity: VehicleIdentity
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Icon(.check, size: 40, lineWidth: 2.2)
                    .foregroundStyle(palette.bg)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(palette.text))
                    .padding(.bottom, 12)
                Text(String(localized: "You're all set"))
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.64)
                    .foregroundStyle(palette.text)
                Text(String(localized: "\(identity.modelName) is paired. From now on, Vela connects on its own when you get in."))
                    .font(.system(size: 17))
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.bottom, 40)
            .frame(maxHeight: .infinity)
            PrimaryButton(title: String(localized: "Open dashboard")) { model.openDashboard() }
        }
    }
}
