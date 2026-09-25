import SwiftUI

/// First-time setup and pairing. One screen per step; the step lives in
/// `AppModel` so rotation or a view rebuild never restarts pairing.
struct OnboardingView: View {
    let model: AppModel
    let step: OnboardingStep
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let layout = PageLayout(size: proxy.fullScreenSize, safe: proxy.safeAreaInsets, landscape: proxy.size.width > proxy.size.height)
            ZStack {
                palette.bg.ignoresSafeArea()
                screen
                    .frame(maxWidth: layout.landscape ? 520 : .infinity)
                    .padding(layout.insets)
                    .id(stepID)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 24)), removal: .opacity))
            }
            .animation(.easeOut(duration: 0.28), value: stepID)
            .ignoresSafeArea()
        }
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
        case let .confirmInCar(identity): ConfirmInCarScreen(model: model, identity: identity)
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
                    .lineSpacing(17 * 0.45 - 4)
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
            CircleNavButton(icon: .chevronLeft, label: "Back") { model.goBack() }
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

// MARK: - Screens

struct WelcomeScreen: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                VelaLogo(size: 72).foregroundStyle(palette.text)
                Text("Vela")
                    .font(.system(size: 40, weight: .semibold))
                    .tracking(-1)
                    .foregroundStyle(palette.text)
                Text("A calm second screen for your Tesla.")
                    .font(.system(size: 19))
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
            }
            .padding(.bottom, 40)
            .frame(maxHeight: .infinity)
            VStack(spacing: 16) {
                PrimaryButton(title: "Get started") { model.advance(to: .finding) }
                Text("Connects to your car over Bluetooth. No account needed.")
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
                title: "Finding your Tesla",
                detail: "Stay near your car with Bluetooth on. This usually takes a few seconds."
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
            Text("Turn on Bluetooth to search")
                .font(.system(size: 17)).foregroundStyle(palette.warn)
                .frame(maxWidth: .infinity, minHeight: 56)
        case .unauthorized:
            Button("Allow Bluetooth in Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.system(size: 17, weight: .medium)).foregroundStyle(palette.warn)
            .frame(maxWidth: .infinity, minHeight: 56)
        default:
            StatusLine(text: "Searching nearby")
        }
    }
}

struct ChooseCarScreen: View {
    let model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            SetupBackBar(model: model)
            SetupTitle(title: "Choose your car", detail: "Pick the one you're sitting in. The closest car is listed first.")
                .padding(.top, 28)
            Hairline().padding(.top, 36)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    let cars = model.scanner.vehicles
                    ForEach(Array(cars.enumerated()), id: \.element.id) { index, car in
                        Button {
                            model.advance(to: .enterVIN(expectedLocalName: car.localName))
                        } label: {
                            row(car, isFirst: index == 0)
                        }
                        .buttonStyle(.plain)
                        Hairline()
                    }
                    if cars.isEmpty {
                        ScannerStatusLine(scanner: model.scanner)
                            .frame(height: 80)
                        Hairline()
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Button {
                model.advance(to: .enterVIN(expectedLocalName: nil))
            } label: {
                Text("My car isn't listed")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ car: NearbyTeslaScanner.Advertisement, isFirst: Bool) -> some View {
        // RSSI buckets, not a distance estimate: BLE signal strength can't
        // give a trustworthy distance.
        let (bars, proximity): (Int, String) = switch car.rssi {
        case (-60)...: (4, "Very close")
        case -72 ..< -60: (3, "Nearby")
        case -84 ..< -72: (2, "A little further")
        default: (1, "Far away")
        }
        let detail = isFirst && bars >= 3 ? "\(proximity) · Likely yours" : proximity
        return HStack(spacing: 16) {
            SignalBars(level: bars)
            VStack(alignment: .leading, spacing: 3) {
                Text("Tesla").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
                Text(detail).font(.system(size: 15)).foregroundStyle(palette.text2)
            }
            Spacer()
            Icon(.chevronRight, size: 18).foregroundStyle(palette.text3)
        }
        .frame(height: 80)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The advertisement doesn't carry the VIN, and the car's key pairing is
/// addressed by VIN, so the user types it once. When they picked a car from
/// the list, the VIN must hash to that car's advertised name.
struct EnterVINScreen: View {
    let model: AppModel
    let expectedLocalName: String?
    @Environment(\.palette) private var palette
    @State private var text = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SetupBackBar(model: model)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    SetupTitle(
                        title: "Enter your VIN",
                        detail: "Find it on the touchscreen under Controls › Software, or at the base of the windshield."
                    )
                    .padding(.top, 28)
                    TextField("", text: $text, prompt: Text("17 characters").foregroundStyle(palette.text3))
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.continue)
                        .focused($focused)
                        .foregroundStyle(palette.text)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.fill))
                        .padding(.top, 32)
                        .onSubmit(submit)
                        .onChange(of: text) { _, new in
                            error = nil
                            let upper = new.uppercased()
                            if upper != new { text = upper }
                        }
                        .accessibilityLabel("VIN")
                    if let error {
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundStyle(palette.warn)
                            .padding(.top, 12)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: "Continue", enabled: !text.isEmpty, action: submit)
                .padding(.top, 12)
        }
        .onAppear { focused = true }
    }

    private func submit() {
        guard let vin = VehicleIdentity.normalize(text) else {
            error = "A VIN has 17 letters and numbers, without I, O or Q."
            return
        }
        let identity = VehicleIdentity(vin: vin)
        if let expectedLocalName, identity.bleLocalName != expectedLocalName {
            error = "This VIN doesn't match the car you picked. Check it, or go back and pick another car."
            return
        }
        focused = false
        model.advance(to: .addKey(identity))
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
                        title: "Add Vela as a key",
                        detail: "Your car adds Vela as a phone key. Vela uses it only to show speed, gear and battery, and to control climate and music."
                    )
                    .padding(.top, 28)
                    Hairline().padding(.top, 32)
                    checkRow("Works without internet")
                    Hairline()
                    checkRow("Remove it anytime in your car's Locks menu")
                    Hairline()
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: "Continue") { model.startPairing(identity) }
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
    }
}

struct ConfirmInCarScreen: View {
    let model: AppModel
    let identity: VehicleIdentity
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { model.cancelPairing() }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(height: 44)
                Spacer()
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    CarIllustration()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.art))
                        .padding(.top, 28)
                    SetupTitle(title: "Confirm in your car").padding(.top, 32)
                    VStack(alignment: .leading, spacing: 18) {
                        stepRow(1, "Sit in the car with the touchscreen awake.")
                        stepRow(2, "Tap your key card on the card reader.")
                        stepRow(3, "Tap Confirm on the touchscreen.")
                    }
                    .padding(.top, 24)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            status
        }
        .onChange(of: model.pairing.phase) { _, phase in
            if phase == .paired { model.pairingSucceeded(identity) }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.pairing.phase {
        case let .failed(message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.warn)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Try again") { model.pairing.start(identity) }
            }
            .padding(.top, 12)
        case .waitingForApproval:
            StatusLine(text: "Waiting for your car")
        case .idle, .findingCar, .paired:
            StatusLine(text: "Connecting to your car")
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

/// Touchscreen with signal arcs above it, from the Pairing 2 mockup.
struct CarIllustration: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, canvas in
            let origin = CGPoint(x: (canvas.width - 180) / 2, y: (canvas.height - 140) / 2)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x, y: origin.y + y) }
            let style = StrokeStyle(lineWidth: 2.5, lineCap: .round)

            var inner = Path()
            inner.addArc(center: p(90, 48.4), radius: 26, startAngle: .degrees(-135), endAngle: .degrees(-45), clockwise: false)
            context.stroke(inner, with: .color(palette.text3), style: style)
            var outer = Path()
            outer.addArc(center: p(90, 48.3), radius: 40, startAngle: .degrees(-135), endAngle: .degrees(-45), clockwise: false)
            context.stroke(outer, with: .color(palette.fill2), style: style)

            let screen = Path(roundedRect: CGRect(origin: p(40, 48), size: CGSize(width: 100, height: 64)), cornerRadius: 9)
            context.stroke(screen, with: .color(palette.text), style: style)
            var bar = Path()
            bar.move(to: p(54, 96)); bar.addLine(to: p(82, 96))
            context.stroke(bar, with: .color(palette.text), style: style)
            var ground = Path()
            ground.move(to: p(20, 126)); ground.addLine(to: p(160, 126))
            context.stroke(ground, with: .color(palette.fill2), style: style)
        }
        .accessibilityHidden(true)
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
                Text("You're all set")
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.64)
                    .foregroundStyle(palette.text)
                Text("\(identity.modelName) is paired. From now on, Vela connects on its own when you get in.")
                    .font(.system(size: 17))
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.bottom, 40)
            .frame(maxHeight: .infinity)
            PrimaryButton(title: "Open dashboard") { model.openDashboard() }
        }
    }
}
