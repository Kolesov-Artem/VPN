import MapKit
import SwiftUI

/// Satellite backdrop that keeps the selected exit node in frame. The map is
/// decoration first, so every gesture it accepts has a plain equivalent in the
/// location list below it.
struct VelvetMapBackground: View {
    let selectedLocation: VPNLocation
    let isConnected: Bool
    var onPickCoordinate: (GeoCoordinate) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera = VelvetMapCamera.overview
    @State private var visibleRegion = VelvetMapCamera.overviewRegion
    @State private var dragOriginRegion: MKCoordinateRegion?
    @State private var pulses = false

    var body: some View {
        GeometryReader { geometry in
            MapReader { proxy in
                Map(position: $camera, interactionModes: .zoom) {
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
                .mapStyle(.hybrid(elevation: .realistic, pointsOfInterest: .excludingAll))
                .onMapCameraChange(frequency: .continuous) { context in
                    visibleRegion = context.region
                }
                .simultaneousGesture(slowPanGesture(in: geometry.size))
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    onPickCoordinate(
                        GeoCoordinate(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                    )
                }
            }
        }
        .overlay {
            scrim
        }
        .ignoresSafeArea()
        .onAppear {
            camera = VelvetMapCamera.make(for: selectedLocation)
            pulses = !reduceMotion
        }
        .onChange(of: selectedLocation) { _, location in
            withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 1.1)) {
                camera = VelvetMapCamera.make(for: location)
            }
        }
        .accessibilityHidden(true)
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
                        ? .easeOut(duration: 2.2).repeatForever(autoreverses: false)
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

        return LinearGradient(
            stops: [
                .init(color: topColor.opacity(0.95), location: 0),
                .init(color: midColor.opacity(0.32), location: 0.16),
                .init(color: VelvetTheme.softPurple.opacity(0.06), location: 0.34),
                .init(color: Color(.systemBackground).opacity(0.28), location: 0.54),
                .init(color: Color(.systemBackground).opacity(0.9), location: 0.68),
                .init(color: Color(.systemBackground), location: 0.8),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.55), value: isConnected)
    }

    /// A deliberately heavy pan: the map follows one third of the finger's
    /// travel and carries a restrained amount of projected momentum on release.
    private func slowPanGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let origin = dragOriginRegion ?? visibleRegion
                if dragOriginRegion == nil {
                    dragOriginRegion = origin
                }

                camera = .region(
                    region(
                        from: origin,
                        translation: value.translation,
                        in: size
                    )
                )
            }
            .onEnded { value in
                guard let origin = dragOriginRegion else { return }
                let destination = region(
                    from: origin,
                    translation: value.predictedEndTranslation,
                    in: size
                )

                dragOriginRegion = nil
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.15)
                        : .spring(response: 0.55, dampingFraction: 0.92)
                ) {
                    camera = .region(destination)
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

    private func normalizedLongitude(_ longitude: Double) -> Double {
        var value = longitude
        while value > 180 { value -= 360 }
        while value < -180 { value += 360 }
        return value
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
