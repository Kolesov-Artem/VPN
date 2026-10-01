import CoreGraphics
import Testing
@testable import VPN

struct DottedMapGeometryTests {
    private let size = CGSize(width: 390, height: 844)

    @Test
    func centerOfTheFrameSitsOnTheAnchor() {
        let frame = DottedMapFrame.overview
        let point = frame.point(
            for: GeoCoordinate(latitude: frame.centerLatitude, longitude: frame.centerLongitude),
            in: size
        )

        #expect(abs(point.x - size.width / 2) < 0.01)
        #expect(abs(point.y - size.height * frame.anchorYFraction) < 0.01)
    }

    @Test
    func screenPointConvertsBackToTheSamePlace() {
        let frame = DottedMapFrame.overview
        let place = GeoCoordinate(latitude: 48.86, longitude: 2.35)
        let back = frame.coordinate(at: frame.point(for: place, in: size), in: size)

        #expect(abs(back.latitude - place.latitude) < 0.001)
        #expect(abs(back.longitude - place.longitude) < 0.001)
    }

    @Test
    func draggingRightRevealsTheWest() {
        let moved = DottedMapFrame.overview.translated(by: CGSize(width: 80, height: 0), in: size)

        #expect(moved.centerLongitude < DottedMapFrame.overview.centerLongitude)
    }

    @Test
    func pinchKeepsThePlaceUnderTheFingers() {
        let origin = DottedMapFrame.overview
        let point = CGPoint(x: 120, y: 260)
        let focus = origin.coordinate(at: point, in: size)
        let zoomed = origin.scaled(by: 2.2, keeping: focus, at: point, in: size)
        let back = zoomed.coordinate(at: point, in: size)

        #expect(abs(back.latitude - focus.latitude) < 0.01)
        #expect(abs(back.longitude - focus.longitude) < 0.01)
        #expect(zoomed.pointsPerDegree > origin.pointsPerDegree)
    }

    @Test
    func zoomStaysInsideAReadableRange() {
        let wide = DottedMapFrame.overview
        var close = wide
        close.pointsPerDegree = 14

        #expect(wide.dotStep > close.dotStep)
        #expect(wide.dotDiameter >= 3.2)
        #expect(wide.dotDiameter <= 10)
        #expect(close.dotDiameter >= 3.2)
        #expect(close.dotDiameter <= 10)
    }

    @Test
    func landMaskKnowsCitiesFromOpenWater() {
        #expect(WorldLandMask.contains(latitude: 48.86, longitude: 2.35))
        #expect(WorldLandMask.contains(latitude: 55.76, longitude: 37.62))
        #expect(WorldLandMask.contains(latitude: 1.35, longitude: 103.82))
        #expect(!WorldLandMask.contains(latitude: 30, longitude: -40))
    }

    @Test
    func cityFramingLooksAtThatCity() throws {
        let moscow = try #require(VPNLocation.samples.first { $0.city == "Moscow" })
        let frame = DottedMapFrame.framing(for: moscow)

        #expect(abs(frame.centerLatitude - 55.7558) < 0.001)
        #expect(abs(frame.centerLongitude - 37.6173) < 0.001)
        #expect(frame.pointsPerDegree > DottedMapFrame.overview.pointsPerDegree)
    }
}
