import MapKit
import SwiftUI

/// How the satellite backdrop should read. Switching modes must not remount
/// the `Map` — that reloads tiles and reads as a jump.
enum VelvetMapAtmosphere: Equatable {
    /// Home: framed on the selected exit node, pan and pinch enabled.
    case focused
    /// First-run connect: slow continuous globe spin, pins hidden.
    case spinningGlobe
    /// Adding a configuration: same map, modest pull-back and continuous spin.
    case pullbackGlobe
}

/// Vertical band where the globe should sit — between the header and island/form.
struct VelvetMapViewportBand: Equatable {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    /// Breathing room above and below the globe disc within the band.
    var margin: CGFloat = 16
    /// Empty space on each horizontal side — full globe disc stays inside.
    var sideMarginFraction: CGFloat = 0.14

    var bandHeight: CGFloat {
        max(screenHeight - topInset - bottomInset - margin * 2, 1)
    }

    var heightFraction: CGFloat {
        guard screenHeight > 0 else { return 0.36 }
        return min(max(bandHeight / screenHeight, 0.24), 0.52)
    }

    var usableWidthFraction: CGFloat {
        max(1 - sideMarginFraction * 2, 0.58)
    }

    /// Nudges latitude toward the overview centroid so the disc centers in the band.
    var centeringBias: Double { 0.14 }
}

/// Satellite backdrop that keeps the selected exit node in frame. The map is
/// decoration first, so every gesture it accepts has a plain equivalent in the
/// location list below it.
struct VelvetMapBackground: View {
    let selectedLocation: VPNLocation
    let isConnected: Bool
    var atmosphere: VelvetMapAtmosphere = .focused
    /// `nil` skips the bottom treatment — used only in isolated prototypes.
    var bottomBackdropStyle: VPNBottomBackdropStyle? = .blur
    /// Frames the pull-back so the globe fits between chrome, not full-screen.
    var viewportBand: VelvetMapViewportBand?
    var onPickCoordinate: (GeoCoordinate) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var camera = VelvetMapCamera.overview
    @State private var visibleRegion = VelvetMapCamera.overviewRegion
    @State private var presentedCamera: MapCamera?
    @State private var dragOriginRegion: MKCoordinateRegion?
    @State private var pulses = false
    @State private var rotationLongitude = VelvetMapCamera.overviewRegion.center.longitude
    @State private var cameraMotionTask: Task<Void, Never>?

    private var isInteractive: Bool { atmosphere == .focused }
    private var showsPins: Bool { atmosphere != .spinningGlobe }

    var body: some View {
        GeometryReader { geometry in
            MapReader { proxy in
                Map(position: $camera, interactionModes: isInteractive ? .zoom : []) {
                    if showsPins {
                        ForEach(otherLocations) { location in
                            if let coordinate = location.coordinate {
                                Annotation(location.city, coordinate: coordinate.clCoordinate) {
                                    Circle()
                                        .fill(.white.opacity(0.55))
                                        .frame(width: 7, height: 7)
                                        .shadow(radius: 2)
                                }
                                .annotationTitles(.hidden)
                            }
                        }

                        if let coordinate = selectedLocation.coordinate {
                            Annotation(selectedLocation.city, coordinate: coordinate.clCoordinate) {
                                serverPin
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic, pointsOfInterest: .excludingAll))
                .onMapCameraChange(frequency: .continuous) { context in
                    visibleRegion = context.region
                    presentedCamera = context.camera
                    rotationLongitude = context.camera.centerCoordinate.longitude
                }
                .modifier(MapInteractionModifier(
                    isInteractive: isInteractive,
                    onPanChanged: { translation in
                        let origin = dragOriginRegion ?? visibleRegion
                        if dragOriginRegion == nil {
                            dragOriginRegion = origin
                        }

                        camera = .region(
                            region(
                                from: origin,
                                translation: translation,
                                in: geometry.size
                            )
                        )
                    },
                    onPanEnded: { predictedTranslation in
                        guard let origin = dragOriginRegion else { return }
                        let destination = region(
                            from: origin,
                            translation: predictedTranslation,
                            in: geometry.size
                        )

                        dragOriginRegion = nil
                        withAnimation(VelvetMotion.mapPanEnd(reduceMotion: reduceMotion)) {
                            camera = .region(destination)
                        }
                    },
                    onTap: { point in
                        guard let coordinate = proxy.convert(point, from: .local) else { return }
                        onPickCoordinate(
                            GeoCoordinate(
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude
                            )
                        )
                    }
                ))
            }
        }
        .overlay {
            scrim
        }
        .ignoresSafeArea()
        .onAppear {
            applyInitialAtmosphere()
        }
        .onDisappear {
            stopCameraMotion()
        }
        .onChange(of: selectedLocation) { _, location in
            guard atmosphere == .focused else { return }
            stopCameraMotion()
            withAnimation(VelvetMotion.mapCamera(reduceMotion: reduceMotion)) {
                camera = VelvetMapCamera.make(for: location)
            }
        }
        .onChange(of: atmosphere) { oldValue, newValue in
            handleAtmosphereChange(from: oldValue, to: newValue)
        }
        .accessibilityHidden(true)
    }

    private func applyInitialAtmosphere() {
        pulses = atmosphere == .focused && !reduceMotion

        switch atmosphere {
        case .focused:
            apply(VelvetMapCamera.makeCamera(for: selectedLocation))
        case .spinningGlobe:
            startSpinningGlobe(animated: false)
        case .pullbackGlobe:
            animatePullbackGlobe()
        }
    }

    private func handleAtmosphereChange(
        from old: VelvetMapAtmosphere,
        to new: VelvetMapAtmosphere
    ) {
        pulses = new == .focused && !reduceMotion

        switch (old, new) {
        case (_, .spinningGlobe):
            startSpinningGlobe(animated: !reduceMotion)
        case (.focused, .pullbackGlobe):
            animatePullbackGlobe()
        case (.pullbackGlobe, .focused), (.spinningGlobe, .focused):
            flyToFocused()
        default:
            break
        }
    }

    private func startSpinningGlobe(animated: Bool) {
        stopCameraMotion()
        rotationLongitude = currentCamera.centerCoordinate.longitude
        let position = VelvetMapCamera.overviewGlobe(longitude: rotationLongitude)

        if animated {
            withAnimation(VelvetMotion.easeInOut(duration: VelvetMotion.globeIntroDuration)) {
                camera = position
            }
        } else {
            camera = position
        }

        guard !reduceMotion else { return }

        cameraMotionTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: VelvetMotion.globeSpinFrameInterval)
                rotationLongitude = normalizedLongitude(
                    rotationLongitude + VelvetMotion.globeSpinStepPerTick
                )
                camera = VelvetMapCamera.overviewGlobe(longitude: rotationLongitude)
            }
        }
    }

    /// Full globe in the header–form band with side margins; spin starts on frame one.
    private func animatePullbackGlobe() {
        stopCameraMotion()
        guard !reduceMotion else { return }

        let start = currentCamera
        let band = viewportBand
        let targetDistance = VelvetMapCamera.addSubscriptionPullbackDistance(
            from: start.distance,
            viewport: band
        )
        let targetLatitude = start.centerCoordinate.latitude
            + (VelvetMapCamera.overviewRegion.center.latitude - start.centerCoordinate.latitude)
            * (band?.centeringBias ?? 0.14)

        var longitude = start.centerCoordinate.longitude
        let duration = VelvetMotion.globePullbackDuration

        cameraMotionTask = Task { @MainActor in
            let pullbackStart = Date.now
            var pullbackFinished = false

            while !Task.isCancelled {
                if !pullbackFinished {
                    let linear = min(Date.now.timeIntervalSince(pullbackStart) / duration, 1)
                    let progress = VelvetMotion.easeOutProgress(linear)
                    let distance = start.distance + (targetDistance - start.distance) * progress
                    let latitude = start.centerCoordinate.latitude
                        + (targetLatitude - start.centerCoordinate.latitude) * progress

                    longitude = normalizedLongitude(longitude + VelvetMotion.globeSpinStepPerFrame)

                    apply(
                        MapCamera(
                            centerCoordinate: CLLocationCoordinate2D(
                                latitude: latitude,
                                longitude: longitude
                            ),
                            distance: distance,
                            heading: start.heading,
                            pitch: start.pitch
                        )
                    )

                    if linear >= 1 {
                        pullbackFinished = true
                    }
                } else {
                    longitude = normalizedLongitude(longitude + VelvetMotion.globeSpinStepPerFrame)
                    apply(
                        MapCamera(
                            centerCoordinate: CLLocationCoordinate2D(
                                latitude: targetLatitude,
                                longitude: longitude
                            ),
                            distance: targetDistance,
                            heading: start.heading,
                            pitch: start.pitch
                        )
                    )
                }

                try? await Task.sleep(for: VelvetMotion.globeSpinRenderInterval)
            }
        }
    }

    private func flyToFocused() {
        let start = currentCamera
        let target = VelvetMapCamera.makeCamera(for: selectedLocation)
        let yaw = shortestLongitudeDelta(
            from: start.centerCoordinate.longitude,
            to: target.centerCoordinate.longitude
        )

        fly(
            from: start,
            to: target,
            yaw: yaw,
            duration: VelvetMotion.globePullback(reduceMotion: reduceMotion)
        )
    }

    private func fly(
        from start: MapCamera,
        to target: MapCamera,
        yaw: Double,
        duration: Double
    ) {
        stopCameraMotion()

        guard duration > 0 else {
            apply(target)
            return
        }

        cameraMotionTask = Task { @MainActor in
            let started = Date.now

            while !Task.isCancelled {
                let linear = min(Date.now.timeIntervalSince(started) / duration, 1)
                let eased = VelvetMotion.easeOutProgress(linear)
                apply(interpolatedCamera(from: start, to: target, yaw: yaw, progress: eased))
                if linear >= 1 { break }
                try? await Task.sleep(for: VelvetMotion.globeSpinRenderInterval)
            }
        }
    }

    private func interpolatedCamera(
        from start: MapCamera,
        to target: MapCamera,
        yaw: Double,
        progress: Double
    ) -> MapCamera {
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: start.centerCoordinate.latitude
                    + (target.centerCoordinate.latitude - start.centerCoordinate.latitude) * progress,
                longitude: normalizedLongitude(start.centerCoordinate.longitude + yaw * progress)
            ),
            distance: start.distance + (target.distance - start.distance) * progress,
            heading: start.heading + (target.heading - start.heading) * progress,
            pitch: start.pitch + (target.pitch - start.pitch) * progress
        )
    }

    private var currentCamera: MapCamera {
        presentedCamera ?? VelvetMapCamera.makeCamera(for: selectedLocation)
    }

    private func apply(_ mapCamera: MapCamera) {
        presentedCamera = mapCamera
        rotationLongitude = mapCamera.centerCoordinate.longitude
        camera = .camera(mapCamera)
    }

    private func stopCameraMotion() {
        cameraMotionTask?.cancel()
        cameraMotionTask = nil
    }

    private var otherLocations: [VPNLocation] {
        VPNLocation.samples.filter { $0.id != selectedLocation.id }
    }

    private var serverPin: some View {
        let tint = isConnected ? Color.green : VelvetTheme.accent

        return ZStack {
            Circle()
                .stroke(tint.opacity(0.5), lineWidth: 2)
                .frame(width: 44, height: 44)
                .scaleEffect(pulses ? 1.35 : 0.85)
                .opacity(pulses ? 0 : 0.9)
                .animation(
                    pulses
                        ? VelvetMotion.easeOut(duration: 2.2).repeatForever(autoreverses: false)
                        : .default,
                    value: pulses
                )

            Circle()
                .fill(tint)
                .frame(width: 16, height: 16)
                .overlay {
                    Circle().stroke(.white, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
        }
    }

    /// Purple or green at the top for the brand bar; the bottom treatment depends
    /// on `bottomBackdropStyle`.
    private var scrim: some View {
        ZStack {
            LinearGradient(
                stops: scrimColorStops,
                startPoint: .top,
                endPoint: .bottom
            )

            if showsBottomBlur {
                bottomBlurOverlay
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(VelvetMotion.scrim(reduceMotion: reduceMotion), value: isConnected)
        .animation(VelvetMotion.scrim(reduceMotion: reduceMotion), value: bottomBackdropStyle)
    }

    private var brandTopColor: Color {
        isConnected ? .green : VelvetTheme.deepPurple
    }

    private var brandMidColor: Color {
        isConnected ? .green : VelvetTheme.deepPurple
    }

    private var brandSoftColor: Color {
        isConnected ? Color.green.opacity(0.55) : VelvetTheme.softPurple
    }

    private var scrimColorStops: [Gradient.Stop] {
        var stops: [Gradient.Stop] = [
            .init(color: brandTopColor.opacity(0.95), location: 0),
            .init(color: brandMidColor.opacity(0.32), location: 0.16),
            .init(color: brandSoftColor.opacity(0.06), location: 0.34),
        ]

        guard let bottomBackdropStyle else {
            stops.append(.init(color: .clear, location: 0.5))
            return stops
        }

        switch bottomBackdropStyle {
        case .none:
            stops.append(.init(color: .clear, location: 0.5))
        case .blur:
            if reduceTransparency {
                stops.append(contentsOf: compactSolidBottomContrastStops)
            } else {
                stops.append(.init(color: .clear, location: 0.5))
            }
        case .purple:
            stops.append(contentsOf: brandBottomContrastStops)
        }

        return stops
    }

    private var brandBottomContrastStops: [Gradient.Stop] {
        [
            .init(color: brandSoftColor.opacity(0.22), location: 0.54),
            .init(color: brandMidColor.opacity(0.65), location: 0.68),
            .init(color: brandTopColor.opacity(0.9), location: 0.8),
        ]
    }

    /// Fallback when Reduce Transparency is on and blur cannot render.
    private var compactSolidBottomContrastStops: [Gradient.Stop] {
        [
            .init(color: Color(.systemBackground).opacity(0.45), location: 0.52),
            .init(color: Color(.systemBackground).opacity(0.96), location: 0.72),
            .init(color: Color(.systemBackground), location: 0.82),
        ]
    }

    private var showsBottomBlur: Bool {
        bottomBackdropStyle == .blur && !reduceTransparency
    }

    private static let bottomBlurHeightFraction: CGFloat = 0.50

    private var bottomBlurOverlay: some View {
        GeometryReader { geometry in
            let height = geometry.size.height * Self.bottomBlurHeightFraction

            Rectangle()
                .fill(.thickMaterial)
                .frame(height: height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .mask(alignment: .bottom) {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.62), location: 0.28),
                            .init(color: .black, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height)
                }
        }
    }

    private func region(
        from origin: MKCoordinateRegion,
        translation: CGSize,
        in size: CGSize
    ) -> MKCoordinateRegion {
        guard size.width > 0, size.height > 0 else { return origin }

        let resistance = 0.34
        let latitudeDelta =
            Double(translation.height / size.height)
            * origin.span.latitudeDelta
            * resistance
        let longitudeDelta =
            -Double(translation.width / size.width)
            * origin.span.longitudeDelta
            * resistance

        let latitude = min(max(origin.center.latitude + latitudeDelta, -85), 85)
        let longitude = normalizedLongitude(origin.center.longitude + longitudeDelta)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: origin.span
        )
    }

    private func shortestLongitudeDelta(from: Double, to: Double) -> Double {
        var delta = to - from
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    private func normalizedLongitude(_ longitude: Double) -> Double {
        var value = longitude
        while value > 180 { value -= 360 }
        while value < -180 { value += 360 }
        return value
    }
}

private struct MapInteractionModifier: ViewModifier {
    let isInteractive: Bool
    let onPanChanged: (CGSize) -> Void
    let onPanEnded: (CGSize) -> Void
    let onTap: (CGPoint) -> Void

    func body(content: Content) -> some View {
        // Same modifier tree in both modes so the `Map` keeps its identity.
        // Branching here remounted MapKit and reloaded tiles on every route change.
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard isInteractive else { return }
                        onPanChanged(value.translation)
                    }
                    .onEnded { value in
                        guard isInteractive else { return }
                        onPanEnded(value.predictedEndTranslation)
                    }
            )
            .onTapGesture { point in
                guard isInteractive else { return }
                onTap(point)
            }
    }
}

enum VelvetMapCamera {
    /// Wide shot used for the automatic server, which stands for the whole
    /// network rather than one city, framed on where Velvet actually has nodes.
    static let overviewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38, longitude: 32),
        span: MKCoordinateSpan(latitudeDelta: 95, longitudeDelta: 95)
    )
    static let overview = MapCameraPosition.region(overviewRegion)

    /// Wide globe shot for the connect step backdrop.
    static let globeDistance: Double = 23_500_000

    static func overviewGlobe(longitude: Double) -> MapCameraPosition {
        .camera(overviewGlobeCamera(longitude: longitude))
    }

    static func overviewGlobeCamera(longitude: Double) -> MapCamera {
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: overviewRegion.center.latitude,
                longitude: longitude
            ),
            distance: globeDistance
        )
    }

    /// Far enough out that the server reads as a country rather than a hillside.
    static let serverDistance: Double = 3_000_000

    /// Measured against the simulator: the camera distance in metres maps to
    /// roughly this many degrees of visible latitude.
    private static let degreesPerMetre = 3.9e-6

    /// The bottom half of the screen belongs to the status text and the panel,
    /// so the camera sits south of the server to lift the pin into the clear
    /// band above them.
    static var framingOffset: Double {
        serverDistance * degreesPerMetre * 0.2
    }

    static func makeCamera(for location: VPNLocation) -> MapCamera {
        guard let coordinate = location.coordinate else {
            return MapCamera(
                centerCoordinate: overviewRegion.center,
                distance: globeDistance
            )
        }

        return MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: max(coordinate.latitude - framingOffset, -85),
                longitude: coordinate.longitude
            ),
            distance: serverDistance
        )
    }

    static func make(for location: VPNLocation) -> MapCameraPosition {
        .camera(makeCamera(for: location))
    }

    /// Pull-back so the full globe disc fits the band with lateral breathing room.
    static func addSubscriptionPullbackDistance(
        from startDistance: Double,
        viewport: VelvetMapViewportBand?
    ) -> Double {
        let band = viewport ?? VelvetMapViewportBand(
            screenWidth: 390,
            screenHeight: 844,
            topInset: 108,
            bottomInset: 440
        )

        // `globeDistance` ≈ edge-to-edge; widen for side margins and a shorter band.
        let lateralScale = 1.0 / Double(band.usableWidthFraction)
        let verticalScale = 1.0 + (1.0 - Double(band.heightFraction)) * 0.38
        let target = globeDistance * lateralScale * verticalScale

        return max(target, startDistance * 1.35)
    }
}

extension GeoCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
