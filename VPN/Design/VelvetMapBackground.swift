import SwiftUI

/// Dotted world backdrop. Land is a field of dots on a color wash, so the
/// frame can pan and zoom without leaving the look of the static artwork.
struct VelvetMapBackground: View {
    let selectedLocation: VPNLocation
    let connectionState: VPNConnectionState
    var isInteractive: Bool = true
    var autoRotates: Bool = false
    /// White fade used on the full-screen island map. A card keeps the wash edge to edge.
    var showsEdgeFade: Bool = true
    /// Full-screen maps paint under the status bar. A card stays inside its own frame.
    var extendsIntoSafeArea: Bool = true
    /// The island names the active pin. A card already shows that name in its header.
    var showsPinTitles: Bool = true
    /// Pulls the land dots out of the lower card so presets sit on the wash.
    var scrimBottomIntoWash: Bool = false
    /// The island pin breathes. A small card turns that ring off so it stays off the title.
    var showsPinPulse: Bool = true
    var onPickCoordinate: (GeoCoordinate) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame = DottedMapFrame.overview
    @State private var dragOrigin: DottedMapFrame?
    @State private var pinchOrigin: DottedMapFrame?
    @State private var dragMoved = false
    @State private var pulses = false
    @State private var driftTask: Task<Void, Never>?
    @State private var washFrom = VelvetTheme.mapDisconnected
    @State private var washTo = VelvetTheme.mapDisconnected
    @State private var waveProgress = 1.0
    @State private var zoom = 1.0
    @State private var zoomTask: Task<Void, Never>?
    @State private var routeFrom: GeoCoordinate?
    @State private var routeTo: GeoCoordinate?
    @State private var routeProgress = 0.0
    @State private var routeOpacity = 0.0
    @State private var waveToken = 0
    @State private var routeToken = 0
    @State private var parallax = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                DottedMapScene(
                    frame: frame,
                    locations: mapPins,
                    selectedLocationID: selectedLocation.id,
                    selectedCoordinate: selectedLocation.coordinate,
                    selectedTitle: showsPinTitles
                        ? ui(selectedLocation.name.withoutEmoji.replacingOccurrences(of: "SMART-", with: ""))
                        : "",
                    pinTint: washTo,
                    pulses: pulses && !autoRotates,
                    washFrom: washFrom,
                    washTo: washTo,
                    waveProgress: waveProgress,
                    zoom: zoom,
                    focus: selectedLocation.coordinate,
                    routeFrom: routeFrom,
                    routeTo: routeTo,
                    routeProgress: routeProgress,
                    routeOpacity: routeOpacity,
                    parallax: reduceMotion ? .zero : parallax
                )
                .allowsHitTesting(false)

                if showsEdgeFade {
                    fade
                        .allowsHitTesting(false)
                }
                if scrimBottomIntoWash {
                    LinearGradient(
                        stops: [
                            .init(color: washTo.opacity(0), location: 0.28),
                            .init(color: washTo.opacity(0.94), location: 0.52),
                            .init(color: washTo, location: 0.68),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .modifier(DottedMapInteraction(
                isInteractive: isInteractive,
                onDragChanged: { translation in
                    guard pinchOrigin == nil else { return }
                    let origin = dragOrigin ?? frame
                    if dragOrigin == nil {
                        dragOrigin = origin
                    }
                    dragMoved = hypot(translation.width, translation.height) > 8
                    let travel = resisted(translation)
                    frame = origin.translated(by: travel, in: size)
                },
                onDragEnded: { translation, predicted in
                    guard pinchOrigin == nil else {
                        dragOrigin = nil
                        return
                    }
                    let origin = dragOrigin ?? frame
                    dragOrigin = nil
                    let extra = CGSize(
                        width: (predicted.width - translation.width) * 0.12,
                        height: (predicted.height - translation.height) * 0.12
                    )
                    let settled = resisted(
                        CGSize(
                            width: translation.width + extra.width,
                            height: translation.height + extra.height
                        )
                    )
                    withAnimation(VelvetMotion.mapPanEnd(reduceMotion: reduceMotion)) {
                        frame = origin.translated(by: settled, in: size)
                    }
                    dragMoved = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(50))
                        dragMoved = false
                    }
                },
                onMagnifyChanged: { magnification, start, current in
                    let origin = pinchOrigin ?? frame
                    if pinchOrigin == nil {
                        pinchOrigin = origin
                    }
                    let focus = origin.coordinate(at: start, in: size)
                    frame = origin.scaled(
                        by: magnification,
                        keeping: focus,
                        at: current,
                        in: size
                    )
                },
                onMagnifyEnded: {
                    pinchOrigin = nil
                },
                onTap: { point in
                    guard !dragMoved else { return }
                    onPickCoordinate(frame.coordinate(at: point, in: size))
                }
            ))
        }
        .modifier(MapSafeAreaFill(extends: extendsIntoSafeArea))
        .onAppear {
            let tint = mapTint
            washFrom = tint
            washTo = tint
            waveProgress = 1
            applyCameraMode(animated: false)
            pulses = showsPinPulse && !reduceMotion && !autoRotates
        }
        .onDisappear {
            stopDrift()
            zoomTask?.cancel()
        }
        .onChange(of: selectedLocation) { previous, location in
            guard !autoRotates else { return }
            dragOrigin = nil
            pinchOrigin = nil
            beginRoute(from: previous.coordinate, to: location.coordinate)
            withAnimation(VelvetMotion.mapCamera(reduceMotion: reduceMotion)) {
                frame = DottedMapFrame.framing(for: location)
            }
        }
        .onChange(of: connectionState) { previous, next in
            beginColorWave(from: previous, to: next)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: waveToken) { _, _ in
            !reduceMotion
        }
        .sensoryFeedback(.selection, trigger: routeToken) { _, _ in
            !reduceMotion
        }
        .onChange(of: autoRotates) { _, rotates in
            applyCameraMode(animated: !reduceMotion)
            pulses = showsPinPulse && !reduceMotion && !rotates
        }
        .accessibilityHidden(true)
    }

    private var mapTint: Color {
        tint(for: connectionState)
    }

    /// Finger travels farther than the land. The globe is heavy, not slippery.
    private func resisted(_ translation: CGSize) -> CGSize {
        CGSize(width: translation.width * 0.55, height: translation.height * 0.55)
    }

    private func sameWash(_ previous: VPNConnectionState, _ next: VPNConnectionState) -> Bool {
        washIdentity(previous) == washIdentity(next)
    }

    private func washIdentity(_ state: VPNConnectionState) -> Int {
        switch state {
        case .connecting: 1
        case .connected: 2
        case .disconnected, .failed: 0
        }
    }

    private func tint(for state: VPNConnectionState) -> Color {
        switch state {
        case .connecting:
            VelvetTheme.mapConnecting
        case .connected:
            VelvetTheme.mapConnected
        case .disconnected, .failed:
            VelvetTheme.mapDisconnected
        }
    }

    /// New color spreads from the chosen city as a ring.
    private func beginColorWave(from previous: VPNConnectionState, to next: VPNConnectionState) {
        zoomTask?.cancel()
        let previousTint = tint(for: previous)
        let nextTint = tint(for: next)
        if case .connecting = next, case .connected = previous {
            washFrom = tint(for: .connected)
            washTo = tint(for: .connected)
            waveProgress = 1
            return
        }
        guard !reduceMotion, !sameWash(previous, next) else {
            washFrom = nextTint
            washTo = nextTint
            waveProgress = 1
            zoom = 1
            return
        }

        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            washFrom = previousTint
            washTo = nextTint
            waveProgress = 0
        }
        waveToken += 1
        withAnimation(VelvetMotion.mapWave(reduceMotion: false)) {
            waveProgress = 1
        }
        withAnimation(VelvetMotion.mapZoomIn(reduceMotion: false)) {
            zoom = 1.06
        }
        zoomTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            withAnimation(VelvetMotion.mapZoomOut(reduceMotion: false)) {
                zoom = 1
            }
        }
    }

    /// A track draws from the place you left to the place you picked and stays.
    private func beginRoute(from: GeoCoordinate?, to: GeoCoordinate?) {
        guard let from, let to, from != to else { return }

        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            routeFrom = from
            routeTo = to
            routeProgress = reduceMotion ? 1 : 0
            routeOpacity = 1
        }
        routeToken += 1
        guard !reduceMotion else { return }
        withAnimation(VelvetMotion.mapCamera(reduceMotion: false)) {
            routeProgress = 1
        }
    }

    /// Cities that can sit on the field, plus the one currently chosen.
    private var mapPins: [VPNLocation] {
        guard !autoRotates else { return [] }
        var pins = VPNLocation.samples.filter { $0.coordinate != nil }
        if selectedLocation.coordinate != nil,
           !pins.contains(where: { isSamePlace($0, selectedLocation) }) {
            pins.append(selectedLocation)
        }
        return pins
    }

    private func isSamePlace(_ lhs: VPNLocation, _ rhs: VPNLocation) -> Bool {
        if lhs.id == rhs.id { return true }
        guard let a = lhs.coordinate, let b = rhs.coordinate else { return false }
        return a.distance(to: b) < 40_000
    }

    /// Same wash as the Figma backdrop: solid color, then white from clear at
    /// the top to solid at the bottom.
    private var fade: some View {
        LinearGradient(
            colors: [
                .white.opacity(0),
                .white,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func applyCameraMode(animated: Bool) {
        if autoRotates {
            let overview = DottedMapFrame.overview
            if animated {
                withAnimation(VelvetMotion.easeInOut(duration: VelvetMotion.globeIntroDuration)) {
                    frame = overview
                }
            } else {
                frame = overview
            }
            startDrift(afterIntro: animated)
        } else {
            stopDrift()
            let next = DottedMapFrame.framing(for: selectedLocation)
            if animated {
                withAnimation(VelvetMotion.mapCamera(reduceMotion: reduceMotion)) {
                    frame = next
                }
            } else {
                frame = next
            }
        }
    }

    private func startDrift(afterIntro: Bool) {
        stopDrift()
        guard autoRotates, !reduceMotion else { return }

        driftTask = Task { @MainActor in
            let delay = afterIntro ? VelvetMotion.globeIntroDuration : 0.35
            try? await Task.sleep(for: .seconds(delay))
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(32))
                frame.centerLongitude = DottedMapFrame.normalize(frame.centerLongitude + 0.18)
            }
        }
    }

    private func stopDrift() {
        driftTask?.cancel()
        driftTask = nil
    }
}

private struct MapSafeAreaFill: ViewModifier {
    var extends: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if extends {
            content.ignoresSafeArea()
        } else {
            content
        }
    }
}

/// Where the dotted map is looking, and how to turn a place into a point.
struct DottedMapFrame: Equatable {
    var centerLatitude: Double
    var centerLongitude: Double
    var pointsPerDegree: Double
    /// Vertical position of the center latitude, as a fraction of the height.
    /// Keeps the land in the upper band, above the panel.
    var anchorYFraction: Double

    static let maxPointsPerDegree = 16.0
    static let minLatitude = -62.0
    static let maxLatitude = 76.0
    static let targetDotPitch = 8.0

    /// Eastern hemisphere, wide enough to read Europe through East Asia.
    static let overview = DottedMapFrame(
        centerLatitude: 18,
        centerLongitude: 50,
        pointsPerDegree: 2.5,
        anchorYFraction: 0.36
    )

    static func framing(for location: VPNLocation) -> DottedMapFrame {
        guard let coordinate = location.coordinate else { return overview }
        return DottedMapFrame(
            centerLatitude: coordinate.latitude,
            centerLongitude: coordinate.longitude,
            pointsPerDegree: 7.4,
            anchorYFraction: 0.32
        )
    }

    var dotStep: Double {
        let raw = Self.targetDotPitch / pointsPerDegree
        let cells = max(1, Int((raw / WorldLandMask.degreesPerCell).rounded()))
        return WorldLandMask.degreesPerCell * Double(cells)
    }

    var dotDiameter: Double {
        let pitch = pointsPerDegree * dotStep
        return min(10, max(3.2, pitch * 0.86))
    }

    func point(for coordinate: GeoCoordinate, in size: CGSize) -> CGPoint {
        point(latitude: coordinate.latitude, longitude: coordinate.longitude, in: size)
    }

    func point(latitude: Double, longitude: Double, in size: CGSize) -> CGPoint {
        let anchor = anchorPoint(in: size)
        return CGPoint(
            x: anchor.x + longitudeDelta(longitude) * pointsPerDegree,
            y: anchor.y - (latitude - centerLatitude) * pointsPerDegree
        )
    }

    func coordinate(at point: CGPoint, in size: CGSize) -> GeoCoordinate {
        let anchor = anchorPoint(in: size)
        return GeoCoordinate(
            latitude: centerLatitude - Double(point.y - anchor.y) / pointsPerDegree,
            longitude: Self.normalize(
                centerLongitude + Double(point.x - anchor.x) / pointsPerDegree
            )
        )
    }

    func translated(by translation: CGSize, in size: CGSize) -> DottedMapFrame {
        var next = self
        guard pointsPerDegree > 0 else { return next }
        next.centerLongitude = Self.normalize(
            centerLongitude - Double(translation.width) / pointsPerDegree
        )
        next.centerLatitude = Self.clampLatitude(
            centerLatitude + Double(translation.height) / pointsPerDegree
        )
        return next
    }

    /// Zooms around a place and keeps that place under `point` after the fingers move.
    func scaled(
        by magnification: CGFloat,
        keeping focus: GeoCoordinate,
        at point: CGPoint,
        in size: CGSize
    ) -> DottedMapFrame {
        var next = self
        next.pointsPerDegree = clampedPointsPerDegree(pointsPerDegree * Double(magnification), in: size)
        let anchor = anchorPoint(in: size)
        let longitudeOffset = Double(point.x - anchor.x) / next.pointsPerDegree
        let latitudeOffset = Double(anchor.y - point.y) / next.pointsPerDegree
        next.centerLongitude = Self.normalize(focus.longitude - longitudeOffset)
        next.centerLatitude = Self.clampLatitude(focus.latitude - latitudeOffset)
        return next
    }

    func landDotPath(in size: CGSize) -> Path {
        var path = Path()
        guard size.width > 1, size.height > 1, pointsPerDegree > 0 else { return path }

        let step = dotStep
        let radius = dotDiameter / 2
        let minLatitude = latitude(atY: size.height + step * pointsPerDegree, in: size)
        let maxLatitude = latitude(atY: -step * pointsPerDegree, in: size)
        let longitudeSpan = Double(size.width) / pointsPerDegree + step * 2
        let minLongitude = centerLongitude - longitudeSpan / 2
        let maxLongitude = minLongitude + longitudeSpan
        let halfSpan = step * 0.45

        // Antarctica reads as a solid bar across the portrait frame. Keep the
        // southern continents and leave the ice sheet out of the artwork.
        let southernLimit = -50.0
        let northernLimit = 78.0
        var latitudeCursor = floor(max(minLatitude, southernLimit) / step) * step
        let latitudeLimit = min(maxLatitude, northernLimit)
        while latitudeCursor <= latitudeLimit {
            let row = Int(floor(latitudeCursor / step))
            let shift = row.magnitude % 2 == 0 ? 0 : step * 0.5
            var longitudeCursor = floor((minLongitude - shift) / step) * step + shift
            while longitudeCursor <= maxLongitude {
                if WorldLandMask.coversLand(
                    latitude: latitudeCursor,
                    longitude: longitudeCursor,
                    halfSpan: halfSpan
                ) {
                    let dot = point(latitude: latitudeCursor, longitude: longitudeCursor, in: size)
                    path.addEllipse(in: CGRect(
                        x: dot.x - radius,
                        y: dot.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                }
                longitudeCursor += step
            }
            latitudeCursor += step
        }
        return path
    }

    static func normalize(_ longitude: Double) -> Double {
        var value = longitude
        while value >= 180 { value -= 360 }
        while value < -180 { value += 360 }
        return value
    }

    static func clampLatitude(_ latitude: Double) -> Double {
        min(max(latitude, minLatitude), maxLatitude)
    }

    private func latitude(atY y: CGFloat, in size: CGSize) -> Double {
        let anchorY = size.height * anchorYFraction
        return centerLatitude + Double(anchorY - y) / pointsPerDegree
    }

    private func longitudeDelta(_ longitude: Double) -> Double {
        var delta = longitude - centerLongitude
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    private func anchorPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height * anchorYFraction)
    }

    private func clampedPointsPerDegree(_ value: Double, in size: CGSize) -> Double {
        let minimum = max(1.8, Double(size.width) / 190)
        return min(max(value, minimum), Self.maxPointsPerDegree)
    }
}

/// Camera, zoom, color wave, and route share one clock so they stay locked together.
private struct DottedMapPose: VectorArithmetic {
    var latitude = 0.0
    var longitude = 0.0
    var pointsPerDegree = 0.0
    var anchorY = 0.0
    var zoom = 1.0
    var wave = 1.0
    var route = 0.0
    var routeOpacity = 0.0
    var parallaxX = 0.0
    var parallaxY = 0.0

    static var zero: DottedMapPose { DottedMapPose() }

    static func + (lhs: DottedMapPose, rhs: DottedMapPose) -> DottedMapPose {
        DottedMapPose(
            latitude: lhs.latitude + rhs.latitude,
            longitude: lhs.longitude + rhs.longitude,
            pointsPerDegree: lhs.pointsPerDegree + rhs.pointsPerDegree,
            anchorY: lhs.anchorY + rhs.anchorY,
            zoom: lhs.zoom + rhs.zoom,
            wave: lhs.wave + rhs.wave,
            route: lhs.route + rhs.route,
            routeOpacity: lhs.routeOpacity + rhs.routeOpacity,
            parallaxX: lhs.parallaxX + rhs.parallaxX,
            parallaxY: lhs.parallaxY + rhs.parallaxY
        )
    }

    static func - (lhs: DottedMapPose, rhs: DottedMapPose) -> DottedMapPose {
        DottedMapPose(
            latitude: lhs.latitude - rhs.latitude,
            longitude: lhs.longitude - rhs.longitude,
            pointsPerDegree: lhs.pointsPerDegree - rhs.pointsPerDegree,
            anchorY: lhs.anchorY - rhs.anchorY,
            zoom: lhs.zoom - rhs.zoom,
            wave: lhs.wave - rhs.wave,
            route: lhs.route - rhs.route,
            routeOpacity: lhs.routeOpacity - rhs.routeOpacity,
            parallaxX: lhs.parallaxX - rhs.parallaxX,
            parallaxY: lhs.parallaxY - rhs.parallaxY
        )
    }

    mutating func scale(by rhs: Double) {
        latitude *= rhs
        longitude *= rhs
        pointsPerDegree *= rhs
        anchorY *= rhs
        zoom *= rhs
        wave *= rhs
        route *= rhs
        routeOpacity *= rhs
        parallaxX *= rhs
        parallaxY *= rhs
    }

    var magnitudeSquared: Double {
        latitude * latitude
            + longitude * longitude
            + pointsPerDegree * pointsPerDegree
            + anchorY * anchorY
            + zoom * zoom
            + wave * wave
            + route * route
            + routeOpacity * routeOpacity
            + parallaxX * parallaxX
            + parallaxY * parallaxY
    }
}

/// Dots and server marks follow the camera. The frame is animatable so a city
/// change eases the field instead of cutting to the new place.
private struct DottedMapScene: View, Animatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var frame: DottedMapFrame
    var locations: [VPNLocation]
    var selectedLocationID: UUID
    var selectedCoordinate: GeoCoordinate?
    var selectedTitle: String
    var pinTint: Color
    var pulses: Bool
    var washFrom: Color
    var washTo: Color
    var waveProgress: Double
    var zoom: Double
    var focus: GeoCoordinate?
    var routeFrom: GeoCoordinate?
    var routeTo: GeoCoordinate?
    var routeProgress: Double
    var routeOpacity: Double
    var parallax: CGSize

    var animatableData: DottedMapPose {
        get {
            DottedMapPose(
                latitude: frame.centerLatitude,
                longitude: frame.centerLongitude,
                pointsPerDegree: frame.pointsPerDegree,
                anchorY: frame.anchorYFraction,
                zoom: zoom,
                wave: waveProgress,
                route: routeProgress,
                routeOpacity: routeOpacity,
                parallaxX: parallax.width,
                parallaxY: parallax.height
            )
        }
        set {
            frame.centerLatitude = newValue.latitude
            frame.centerLongitude = newValue.longitude
            frame.pointsPerDegree = newValue.pointsPerDegree
            frame.anchorYFraction = newValue.anchorY
            zoom = newValue.zoom
            waveProgress = newValue.wave
            routeProgress = newValue.route
            routeOpacity = newValue.routeOpacity
            parallax = CGSize(width: newValue.parallaxX, height: newValue.parallaxY)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let origin = focusPoint(in: size)
            let anchor = UnitPoint(
                x: origin.x / max(size.width, 1),
                y: origin.y / max(size.height, 1)
            )

            ZStack {
                washFrom
                washTo
                    .mask {
                        Circle()
                            .frame(
                                width: waveDiameter(in: size),
                                height: waveDiameter(in: size)
                            )
                            .position(origin)
                    }

                ZStack {
                    Canvas { context, canvasSize in
                        let path = frame.landDotPath(in: canvasSize)
                        context.fill(path, with: .color(.white))
                    }
                    .mask { DottedMapFadeMask() }
                    .opacity(0.28)
                    .blendMode(.softLight)
                    .offset(depthOffset)

                    Canvas { context, canvasSize in
                        let path = frame.landDotPath(in: canvasSize)
                        context.fill(path, with: .color(.white))
                    }
                    .mask { DottedMapFadeMask() }
                    .opacity(0.6)
                    .blendMode(.softLight)
                    .offset(landOffset)

                    routeLayer(in: size)
                        .offset(pinOffset)

                    ZStack {
                        ForEach(locations) { location in
                            if let coordinate = location.coordinate {
                                pin(
                                    isSelected: isActive(location),
                                    title: isActive(location) ? pinTitle(for: location) : nil as String?
                                )
                                .position(frame.point(for: coordinate, in: size))
                            }
                        }
                    }
                    .offset(pinOffset)
                }
                .scaleEffect(zoom, anchor: anchor)
            }
        }
    }

    private func focusPoint(in size: CGSize) -> CGPoint {
        if let focus {
            return frame.point(for: focus, in: size)
        }
        return CGPoint(x: size.width / 2, y: size.height * frame.anchorYFraction)
    }

    private func waveDiameter(in size: CGSize) -> CGFloat {
        hypot(size.width, size.height) * 2.6 * waveProgress
    }

    @ViewBuilder
    private func routeLayer(in size: CGSize) -> some View {
        if let routeFrom, let routeTo, routeOpacity > 0.01 {
            Canvas { context, _ in
                let path = trackDots(from: routeFrom, to: routeTo, in: size)
                context.fill(path, with: .color(.white))
            }
            .opacity(routeOpacity)
            .allowsHitTesting(false)
        }
    }

    /// Evenly spaced marks along the trip, revealed as the camera travels.
    private func trackDots(from: GeoCoordinate, to: GeoCoordinate, in size: CGSize) -> Path {
        let samples = 48
        var points: [CGPoint] = []
        points.reserveCapacity(samples + 1)
        for index in 0...samples {
            let t = Double(index) / Double(samples)
            var delta = to.longitude - from.longitude
            while delta > 180 { delta -= 360 }
            while delta < -180 { delta += 360 }
            let coordinate = GeoCoordinate(
                latitude: from.latitude + (to.latitude - from.latitude) * t,
                longitude: from.longitude + delta * t
            )
            points.append(frame.point(for: coordinate, in: size))
        }

        var length: CGFloat = 0
        for index in 1..<points.count {
            length += hypot(points[index].x - points[index - 1].x, points[index].y - points[index - 1].y)
        }
        let visible = length * routeProgress
        let spacing: CGFloat = 14
        var path = Path()
        var walked: CGFloat = 0
        var nextMark: CGFloat = 0
        guard points.count > 1 else { return path }

        var cursor = points[0]
        for index in 1..<points.count {
            let end = points[index]
            let segment = hypot(end.x - cursor.x, end.y - cursor.y)
            if segment < 0.001 {
                cursor = end
                continue
            }
            while nextMark <= walked + segment, nextMark <= visible {
                let local = (nextMark - walked) / segment
                let mark = CGPoint(
                    x: cursor.x + (end.x - cursor.x) * local,
                    y: cursor.y + (end.y - cursor.y) * local
                )
                path.addEllipse(in: CGRect(x: mark.x - 2.2, y: mark.y - 2.2, width: 4.4, height: 4.4))
                nextMark += spacing
            }
            walked += segment
            cursor = end
            if walked >= visible { break }
        }
        return path
    }

    private var depthOffset: CGSize { .zero }

    private var landOffset: CGSize { .zero }

    private var pinOffset: CGSize { .zero }

    private func isActive(_ location: VPNLocation) -> Bool {
        if location.id == selectedLocationID { return true }
        guard let here = location.coordinate, let selected = selectedCoordinate else { return false }
        return here.distance(to: selected) < 40_000
    }

    private func pinTitle(for location: VPNLocation) -> String? {
        selectedTitle.isEmpty ? nil : selectedTitle
    }

    private func pin(isSelected: Bool, title: String?) -> some View {
        Group {
            if isSelected {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(pinTint.opacity(0.55), lineWidth: 2)
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
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .overlay {
                                Circle().stroke(pinTint, lineWidth: 3)
                            }
                            .shadow(color: .black.opacity(0.28), radius: 4, y: 1)
                    }

                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                            .lineLimit(1)
                    }
                }
            } else {
                Circle()
                    .fill(pinTint.opacity(0.55))
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle().stroke(.white.opacity(0.9), lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            }
        }
    }
}

/// Screen-fixed dissolve. Dots melt into the color under the status bar and
/// again before the wash turns white.
private struct DottedMapFadeMask: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.2), location: 0.05),
                .init(color: .white, location: 0.14),
                .init(color: .white, location: 0.46),
                .init(color: .white.opacity(0.55), location: 0.62),
                .init(color: .white.opacity(0.16), location: 0.74),
                .init(color: .clear, location: 0.84),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct DottedMapInteraction: ViewModifier {
    let isInteractive: Bool
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize, CGSize) -> Void
    let onMagnifyChanged: (CGFloat, CGPoint, CGPoint) -> Void
    let onMagnifyEnded: () -> Void
    let onTap: (CGPoint) -> Void

    func body(content: Content) -> some View {
        if isInteractive {
            content
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            onDragChanged(value.translation)
                        }
                        .onEnded { value in
                            onDragEnded(value.translation, value.predictedEndTranslation)
                        }
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            onMagnifyChanged(value.magnification, value.startLocation, value.startLocation)
                        }
                        .onEnded { _ in
                            onMagnifyEnded()
                        }
                )
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            onTap(value.location)
                        }
                )
        } else {
            content
        }
    }
}





