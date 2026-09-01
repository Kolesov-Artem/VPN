import MapKit
import SwiftUI

/// Satellite backdrop that keeps the selected exit node in frame. The map is
/// decoration first, so every gesture it accepts has a plain equivalent in the
/// location list below it.
struct VelvetMapBackground: View {
    let selectedLocation: VPNLocation
    let isConnected: Bool
    var isInteractive: Bool = true
    var autoRotates: Bool = false
    var includesBottomContrast: Bool = true
    var onPickCoordinate: (GeoCoordinate) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera = VelvetMapCamera.overview
    @State private var visibleRegion = VelvetMapCamera.overviewRegion
    @State private var dragOriginRegion: MKCoordinateRegion?
    @State private var pulses = false
    @State private var rotationLongitude = VelvetMapCamera.overviewRegion.center.longitude
    @State private var rotationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            MapReader { proxy in
                Map(position: $camera, interactionModes: isInteractive ? .zoom : []) {
                    if !autoRotates {
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
            applyCameraMode(animated: false)
            pulses = !reduceMotion && !autoRotates
        }
        .onDisappear {
            stopAutoRotation()
        }
        .onChange(of: selectedLocation) { _, location in
            guard !autoRotates else { return }
            withAnimation(VelvetMotion.mapCamera(reduceMotion: reduceMotion)) {
                camera = VelvetMapCamera.make(for: location)
            }
        }
        .onChange(of: autoRotates) { _, rotates in
            applyCameraMode(animated: !reduceMotion)
            pulses = !reduceMotion && !rotates
        }
        .accessibilityHidden(true)
    }

    private func applyCameraMode(animated: Bool) {
        if autoRotates {
            rotationLongitude = VelvetMapCamera.overviewRegion.center.longitude
            let position = VelvetMapCamera.overviewGlobe(longitude: rotationLongitude)
            if animated {
                withAnimation(VelvetMotion.easeInOut(duration: VelvetMotion.globeIntroDuration)) {
                    camera = position
                }
            } else {
                camera = position
            }
            startAutoRotation()
        } else {
            stopAutoRotation()
            let position = VelvetMapCamera.make(for: selectedLocation)
            if animated {
                withAnimation(VelvetMotion.mapCamera(reduceMotion: reduceMotion)) {
                    camera = position
                }
            } else {
                camera = position
            }
        }
    }

    private func startAutoRotation() {
        stopAutoRotation()
        guard autoRotates, !reduceMotion else { return }

        rotationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(48))
                rotationLongitude = normalizedLongitude(rotationLongitude + 0.016)
                camera = VelvetMapCamera.overviewGlobe(longitude: rotationLongitude)
            }
        }
    }

    private func stopAutoRotation() {
        rotationTask?.cancel()
        rotationTask = nil
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

    /// Purple at the top for the brand bar, opaque at the bottom so the status
    /// text and the panel keep their contrast over bright terrain.
    private var scrim: some View {
        let topColor = isConnected ? Color.green : VelvetTheme.deepPurple
        let midColor = isConnected ? Color.green : VelvetTheme.deepPurple

        let stops: [Gradient.Stop] =
            if includesBottomContrast {
                [
                    .init(color: topColor.opacity(0.95), location: 0),
                    .init(color: midColor.opacity(0.32), location: 0.16),
                    .init(color: VelvetTheme.softPurple.opacity(0.06), location: 0.34),
                    .init(color: Color(.systemBackground).opacity(0.28), location: 0.54),
                    .init(color: Color(.systemBackground).opacity(0.9), location: 0.68),
                    .init(color: Color(.systemBackground), location: 0.8),
                ]
            } else {
                [
                    .init(color: topColor.opacity(0.95), location: 0),
                    .init(color: midColor.opacity(0.32), location: 0.16),
                    .init(color: VelvetTheme.softPurple.opacity(0.06), location: 0.34),
                    .init(color: Color.clear, location: 0.5),
                ]
            }

        return LinearGradient(
            stops: stops,
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(VelvetMotion.scrim(reduceMotion: reduceMotion), value: isConnected)
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
        if isInteractive {
            content
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            onPanChanged(value.translation)
                        }
                        .onEnded { value in
                            onPanEnded(value.predictedEndTranslation)
                        }
                )
                .onTapGesture(perform: onTap)
        } else {
            content
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
        .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: overviewRegion.center.latitude,
                    longitude: longitude
                ),
                distance: globeDistance
            )
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

    static func make(for location: VPNLocation) -> MapCameraPosition {
        guard let coordinate = location.coordinate else { return overview }

        return .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: max(coordinate.latitude - framingOffset, -85),
                    longitude: coordinate.longitude
                ),
                distance: serverDistance
            )
        )
    }
}

extension GeoCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
