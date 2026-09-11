import CoreGraphics
import Foundation
import Testing
@testable import VPN

struct BottomPanelStateTests {
    private let detents = BottomPanelDetents(
        expandedHeight: 650,
        intermediateHeight: 420,
        islandHeight: VelvetCollapsedIslandLayout.islandHeight(
            showsSessionStats: false,
            isAccessibilitySize: false
        ),
        bottomMargin: 34,
        topMargin: 0
    )

    @Test
    func positionsMoveThroughAllThreeDetents() {
        #expect(BottomPanelPosition.island.nextHigher == .intermediate)
        #expect(BottomPanelPosition.intermediate.nextHigher == .expanded)
        #expect(BottomPanelPosition.expanded.nextLower == .intermediate)
        #expect(BottomPanelPosition.intermediate.nextLower == .island)
    }

    @Test
    func activeSearchExpandsIntermediateDetentOnly() {
        #expect(
            BottomPanelPosition.intermediate.expandedForActiveSearch(
                isFocused: true,
                queryText: ""
            ) == .expanded
        )
        #expect(
            BottomPanelPosition.intermediate.expandedForActiveSearch(
                isFocused: false,
                queryText: "berlin"
            ) == .expanded
        )
        #expect(
            BottomPanelPosition.intermediate.expandedForActiveSearch(
                isFocused: false,
                queryText: "   "
            ) == nil
        )
        #expect(
            BottomPanelPosition.island.expandedForActiveSearch(
                isFocused: true,
                queryText: "berlin"
            ) == nil
        )
        #expect(
            BottomPanelPosition.expanded.expandedForActiveSearch(
                isFocused: true,
                queryText: "berlin"
            ) == nil
        )
    }

    @Test
    func activeSearchExpandsFromIslandInDirectMode() {
        #expect(
            BottomPanelPosition.island.expandedForActiveSearch(
                isFocused: true,
                queryText: "",
                detentMode: .direct
            ) == .expanded
        )
    }

    @Test
    func detentsIncreaseInHeight() {
        #expect(detents.height(for: .island) < detents.height(for: .intermediate))
        #expect(detents.height(for: .intermediate) < detents.height(for: .expanded))
    }

    @Test
    func upwardFlickFromIslandMovesToIntermediate() {
        let result = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -24,
            predictedEndTranslation: -400,
            detents: detents
        )

        #expect(result == .intermediate)
    }

    @Test
    func upwardFlickFromIntermediateExpandsPanel() {
        let result = BottomPanelSnapResolver.resolve(
            current: .intermediate,
            translation: -24,
            predictedEndTranslation: -400,
            detents: detents
        )

        #expect(result == .expanded)
    }

    @Test
    func smallDragKeepsCurrentPosition() {
        let result = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -12,
            predictedEndTranslation: -28,
            detents: detents
        )

        #expect(result == .island)
    }

    @Test
    func downwardFlickFromExpandedMovesToIntermediate() {
        let result = BottomPanelSnapResolver.resolve(
            current: .expanded,
            translation: 32,
            predictedEndTranslation: 400,
            detents: detents
        )

        #expect(result == .intermediate)
    }

    @Test
    func downwardFlickFromIntermediateCollapsesToIsland() {
        let result = BottomPanelSnapResolver.resolve(
            current: .intermediate,
            translation: 32,
            predictedEndTranslation: 400,
            detents: detents
        )

        #expect(result == .island)
    }

    @Test
    func curtainDragSnapUsesDirectModeForWeakAndStrongSwipes() {
        let liftToHalf = detents.intermediateHeight - detents.islandHeight
        let weakFromIsland = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -liftToHalf * 0.55,
            predictedEndTranslation: -liftToHalf * 0.5,
            detents: detents,
            mode: .direct
        )
        #expect(weakFromIsland == .intermediate)

        let strongFromIsland = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -24,
            predictedEndTranslation: -400,
            detents: detents,
            mode: .direct
        )
        #expect(strongFromIsland == .expanded)
    }

    @Test
    func directFlingFromIslandExpandsToFull() {
        let result = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -24,
            predictedEndTranslation: -400,
            detents: detents,
            mode: .direct
        )

        #expect(result == .expanded)
    }

    @Test
    func directFlickFromExpandedCollapsesToIsland() {
        let result = BottomPanelSnapResolver.resolve(
            current: .expanded,
            translation: 32,
            predictedEndTranslation: 400,
            detents: detents,
            mode: .direct
        )

        #expect(result == .island)
    }

    @Test
    func directReleaseBelowMidpointStaysCollapsed() {
        let lift = detents.intermediateHeight - detents.islandHeight
        let result = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -lift * 0.3,
            predictedEndTranslation: -lift * 0.25,
            detents: detents,
            mode: .direct
        )

        #expect(result == .island)
    }

    @Test
    func directReleaseAboveMidpointSnapsToIntermediate() {
        let lift = detents.intermediateHeight - detents.islandHeight
        let result = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -lift,
            predictedEndTranslation: -lift * 0.95,
            detents: detents,
            mode: .direct
        )

        #expect(result == .intermediate)
    }

    @Test
    func directReleaseNearExpandedSnapsToFull() {
        let lift = detents.expandedHeight - detents.islandHeight
        let result = BottomPanelSnapResolver.resolve(
            current: .island,
            translation: -lift * 0.92,
            predictedEndTranslation: -lift * 0.9,
            detents: detents,
            mode: .direct
        )

        #expect(result == .expanded)
    }

    @Test
    func collapsedLayoutIsAVisibleFloatingIsland() {
        let layout = BottomPanelInterpolator.layout(
            detents: detents,
            position: .island,
            dragTranslation: 0
        )

        #expect(layout.panelHeight == detents.islandHeight)
        #expect(layout.horizontalInset == VelvetTheme.islandHorizontalInset)
        #expect(layout.bottomInset == detents.bottomMargin)
        #expect(layout.bottomCornerRadius == VelvetTheme.panelRadius)
    }

    @Test
    func expandedLayoutBecomesFullWidthSheet() {
        let layout = BottomPanelInterpolator.layout(
            detents: detents,
            position: .expanded,
            dragTranslation: 0
        )

        #expect(layout.panelHeight == detents.expandedHeight)
        #expect(layout.horizontalInset == 0)
        #expect(layout.bottomInset == 0)
        #expect(layout.listProgress == 1)
        #expect(layout.sheetMorphProgress == 1)
    }

    @Test
    func intermediateLayoutShowsFullyOpaqueList() {
        let layout = BottomPanelInterpolator.layout(
            detents: detents,
            position: .intermediate,
            dragTranslation: 0
        )

        #expect(layout.panelHeight == detents.intermediateHeight)
        #expect(layout.listProgress == 1)
        #expect(layout.collapsedContentOpacity == 0)
        #expect(layout.horizontalInset == VelvetTheme.islandHalfMargin)
        #expect(layout.bottomInset == VelvetTheme.islandHalfMargin)
        #expect(layout.bottomCornerRadius == VelvetTheme.panelRadius)
        #expect(layout.sheetMorphProgress == 0)
    }

    @Test
    func islandDetentsExpandToFullScreen() {
        let islandDetents = BottomPanelDetents.makeIsland(
            screenHeight: 852,
            safeAreaBottom: 34,
            safeAreaTop: 59,
            isAccessibilitySize: false
        )

        #expect(islandDetents.expandedHeight == CGFloat(852 - 59 + 16))
        #expect(islandDetents.topMargin == CGFloat(59 - 16))
        #expect(islandDetents.intermediateHeight == CGFloat(852 * 0.50))
        #expect(islandDetents.islandHeight == VelvetCollapsedIslandLayout.islandHeight(
            showsSessionStats: false,
            isAccessibilitySize: false
        ))
        #expect(islandDetents.intermediateHeight < islandDetents.expandedHeight)
    }

    @Test
    func intermediateDetentUsesMoreThanHalfTheScreen() {
        let detents = BottomPanelDetents.make(
            screenHeight: 852,
            safeAreaBottom: 34,
            isAccessibilitySize: false
        )

        #expect(detents.intermediateHeight == 852 * 0.56)
        #expect(detents.expandedHeight > detents.intermediateHeight)
    }

    @Test
    func islandMarginNeverDropsBelowTheMinimumLayoutMargin() {
        let detents = BottomPanelDetents.make(
            screenHeight: 852,
            safeAreaBottom: 0,
            isAccessibilitySize: false
        )

        #expect(detents.bottomMargin == VelvetTheme.minimumBottomMargin)
    }

    @Test
    func islandMarginClearsTheHomeIndicator() {
        let detents = BottomPanelDetents.make(
            screenHeight: 852,
            safeAreaBottom: 34,
            isAccessibilitySize: false
        )

        #expect(detents.bottomMargin == 34)
        #expect(detents.contentBottomInset > detents.bottomMargin)
    }

    @Test
    func connectedIslandDetentStaysBelowIntermediateOnShortViewports() {
        let detents = BottomPanelDetents.makeIsland(
            screenHeight: 320,
            safeAreaBottom: 0,
            safeAreaTop: 43,
            isAccessibilitySize: false,
            showsSessionStats: true
        )

        #expect(detents.height(for: .island) < detents.height(for: .intermediate))
        #expect(detents.height(for: .intermediate) < detents.height(for: .expanded))
    }

    @Test
    func sheetIslandDetentMatchesComputedCollapsedHeight() {
        let collapsedHeight = VelvetCollapsedIslandLayout.islandHeight(
            showsSessionStats: false,
            isAccessibilitySize: false
        )

        #expect(collapsedHeight == 163)
    }

    @Test
    func dragLiteLayoutFreezesExpensiveMorphWhileTrackingHeight() {
        let live = BottomPanelInterpolator.layout(
            detents: detents,
            position: .intermediate,
            dragTranslation: -80
        )
        let dragLite = BottomPanelInterpolator.displayLayout(
            detents: detents,
            position: .intermediate,
            dragTranslation: -80,
            isDragLite: true
        )

        #expect(dragLite.panelHeight == live.panelHeight)
        #expect(dragLite.horizontalInset == live.horizontalInset)
        #expect(dragLite.bottomCornerRadius == live.bottomCornerRadius)
        #expect(dragLite.sheetMorphProgress == live.sheetMorphProgress)
        #expect(dragLite.shadowRadius == 20)
        #expect(dragLite.shadowOpacity == VelvetTheme.islandShadowOpacity)
    }

    @Test
    func connectionStateFollowsPrimaryActionFlow() {
        var state = VPNConnectionState.disconnected

        state.handlePrimaryAction()
        #expect(state == .connecting)

        state.completeConnection()
        #expect(state == .connected)

        state.handlePrimaryAction()
        #expect(state == .disconnected)

        state = .failed(.network(message: "Test"))
        state.handlePrimaryAction()
        #expect(state == .connecting)
    }
}

struct VPNLocationCatalogTests {
    @Test
    func catalogOffersTwentyServersWithFlags() {
        #expect(VPNLocation.samples.count == 20)
        #expect(VPNLocation.samples.allSatisfy { !$0.flag.isEmpty })
    }

    @Test
    func everyManualServerCarriesMapCoordinates() {
        let manualServers = VPNLocation.samples.filter { $0.kind != .smart }

        #expect(manualServers.allSatisfy { $0.coordinate != nil })
        #expect(VPNLocation.samples.first(where: { $0.kind == .smart })?.coordinate == nil)
    }

    @Test(arguments: [
        (GeoCoordinate(latitude: 43.1, longitude: 76.9), "Almaty"),
        (GeoCoordinate(latitude: 48.9, longitude: 2.4), "Paris"),
        (GeoCoordinate(latitude: 1.0, longitude: 104.2), "Singapore"),
    ])
    func mapTapResolvesToTheClosestServer(coordinate: GeoCoordinate, expectedCity: String) {
        #expect(VPNLocation.nearest(to: coordinate)?.city == expectedCity)
    }

    @Test
    func mapTapOverOpenWaterStillResolvesToAServer() {
        let midAtlantic = GeoCoordinate(latitude: 30, longitude: -40)

        #expect(VPNLocation.nearest(to: midAtlantic)?.city == "New York")
    }

    @Test
    func automaticServerIsNeverTheResultOfAMapTap() {
        let coordinates = VPNLocation.samples.compactMap(\.coordinate)

        #expect(coordinates.allSatisfy { VPNLocation.nearest(to: $0)?.kind != .smart })
    }

    @Test
    func catalogMixesMobileAndStandardServers() {
        let kinds = Set(VPNLocation.samples.map(\.kind))

        #expect(kinds.contains(.lte))
        #expect(kinds.contains(.standard))
        #expect(kinds.contains(.smart))
    }

    @Test
    func countryGroupsCollapseMultipleServersIntoOneCountry() throws {
        let groups = VPNLocation.countryGroups(from: VPNLocation.samples)
        let russia = try #require(groups.first(where: { $0.name == "Russia" }))

        #expect(groups.count == 16)
        #expect(russia.locations.count == 3)
        #expect(russia.locations.map(\.city) == ["Moscow", "Saint Petersburg", "Yekaterinburg"])
    }

    @Test
    func countryGroupsExcludeAutomaticLocation() {
        let groups = VPNLocation.countryGroups(from: VPNLocation.samples)

        #expect(groups.allSatisfy { group in
            group.locations.allSatisfy { $0.kind != .smart }
        })
    }

    @Test
    func locationPersistenceKeysAreUnique() {
        let keys = VPNLocation.samples.map(\.persistenceKey)

        #expect(Set(keys).count == keys.count)
    }

    @Test
    func automaticServerIsPinnedAheadOfTheFastestManualOne() {
        let results = VPNLocation.matching(VPNLocationQuery())

        #expect(results.first?.kind == .smart)
    }

    @Test
    func resultsAreOrderedByLatency() {
        var query = VPNLocationQuery()
        query.filter = .standard

        let pings = VPNLocation.matching(query).map(\.ping)

        #expect(pings == pings.sorted())
    }

    @Test(arguments: [
        ("moscow", 1),
        ("Germany", 2),
        ("lte", 9),
    ])
    func searchMatchesCountryCityAndType(text: String, expectedCount: Int) {
        var query = VPNLocationQuery()
        query.text = text

        #expect(VPNLocation.matching(query).count == expectedCount)
    }

    @Test
    func filterNarrowsResultsToOneServerType() {
        var query = VPNLocationQuery()
        query.filter = .lte

        let results = VPNLocation.matching(query)

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.kind == .lte })
    }

    @Test
    func unknownQueryReturnsNoResults() {
        var query = VPNLocationQuery()
        query.text = "Atlantis"

        #expect(VPNLocation.matching(query).isEmpty)
    }

    @Test
    func latencyCutOffKeepsOnlyFastServers() {
        var query = VPNLocationQuery()
        query.fastOnly = true

        let results = VPNLocation.matching(query)

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.ping < VPNLocation.fastPingThreshold })
    }

    @Test
    func alphabeticalSortStillPinsTheAutomaticServer() {
        var query = VPNLocationQuery()
        query.sort = .country

        let results = VPNLocation.matching(query)
        let manualNames = results.filter { $0.kind != .smart }.map(\.name)

        #expect(results.first?.kind == .smart)
        #expect(manualNames == manualNames.sorted())
    }
}

struct VPNLocationQueryTests {
    @Test
    func freshQueryHidesTheChipStrip() {
        let query = VPNLocationQuery()

        #expect(query.isDefault)
        #expect(query.activeChips.isEmpty)
    }

    @Test
    func freeTextAloneDoesNotCountAsAFilter() {
        var query = VPNLocationQuery()
        query.text = "berlin"

        #expect(query.isDefault)
        #expect(query.activeChips.isEmpty)
    }

    @Test
    func everyNonDefaultChoiceGetsItsOwnChip() {
        var query = VPNLocationQuery()
        query.filter = .lte
        query.fastOnly = true
        query.sort = .country

        #expect(!query.isDefault)
        #expect(query.activeChips.count == 3)
    }

    @Test
    func clearingAChipRestoresOnlyThatChoice() {
        var query = VPNLocationQuery()
        query.filter = .lte
        query.fastOnly = true

        query.clear(.fastOnly)

        #expect(query.filter == .lte)
        #expect(!query.fastOnly)
        #expect(query.activeChips.count == 1)
    }

    @Test
    func resettingFiltersKeepsTheTypedQuery() {
        var query = VPNLocationQuery()
        query.text = "tokyo"
        query.filter = .standard
        query.sort = .country
        query.fastOnly = true

        query.resetFilters()

        #expect(query.isDefault)
        #expect(query.text == "tokyo")
    }
}

struct VPNConnectionPlannerTests {
    private func surfsharkOnly() -> [VPNProvider] {
        let template = VPNProvider.samples[2]
        return [
            VPNProvider(
                id: UUID(),
                name: template.name,
                iconSymbol: template.iconSymbol,
                kind: .imported,
                status: template.status,
                servers: template.servers,
                subscriptionURL: template.subscriptionURL,
                lastUpdated: .now,
                expiresAt: template.expiresAt,
                includedInSmartAuto: template.includedInSmartAuto
            )
        ]
    }

    @Test
    func reconcileSelectionClearsStaleVelvetScope() {
        let providers = surfsharkOnly()
        let surfsharkID = providers[0].id
        let velvetID = UUID()
        let staleSelection = VPNLocationSelection.smartJob(
            .streaming,
            scope: .provider(velvetID)
        )

        let reconciled = VPNConnectionPlanner.reconcileSelection(
            staleSelection,
            providers: providers,
            storeScope: .allNetworks
        )

        #expect(reconciled == .smartJob(.streaming, scope: .provider(surfsharkID)))
        #expect(VPNConnectionPlanner.resolve(providers: providers, selection: reconciled) != nil)
    }

    @Test
    func smartAutoFallbackFindsSurfsharkServer() {
        let providers = surfsharkOnly()
        let selection = VPNLocationSelection.smartJob(.mobileLTE, scope: .allNetworks)

        let fallback = VPNConnectionPlanner.smartAutoFallbackSelection(
            providers: providers,
            preferredScope: selection.scope,
            storeScope: .allNetworks
        )

        #expect(fallback != nil)
        #expect(VPNConnectionPlanner.resolve(providers: providers, selection: fallback!) != nil)
    }

    @Test
    func diagnoseMobileLTEMismatchOnSurfshark() {
        let providers = surfsharkOnly()
        let selection = VPNLocationSelection.smartJob(.mobileLTE, scope: .allNetworks)

        let mismatch = VPNConnectionPlanner.diagnoseSelectionFailure(
            providers: providers,
            selection: selection
        )

        #expect(mismatch?.reason == .presetUnavailable(job: .mobileLTE))
        #expect(mismatch?.suggestsVelvet == true)
    }
}
