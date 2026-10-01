import Foundation
import Network
import Observation

struct ServiceProbeSite: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var link: String
}

struct ServiceProbeReading: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var latencyMs: Int

    var isSlow: Bool { latencyMs >= Self.slowThreshold }

    static let slowThreshold = 500
}

/// Simulated reachability for the current connection.
///
/// Without a VPN the list matches the blocked design: YouTube and ChatGPT stay
/// at 530 ms. Connecting the VPN clears every site.
@Observable
@MainActor
final class ServiceAvailabilityModel {
    private static let storageKey = "velvet.serviceAvailabilitySites.v1"

    private struct LatencyProfile {
        var cellular: Int
        var open: Int
    }

    var sites: [ServiceProbeSite]
    private(set) var hasPath = false
    private(set) var isOnWiFi = false
    var updatedAt = Date()

    private var jitterSeed = 0
    @ObservationIgnored private var monitor = NWPathMonitor()
    @ObservationIgnored private let monitorQueue = DispatchQueue(label: "velvet.service-availability")

    init() {
        sites = Self.loadSites()
        monitor.pathUpdateHandler = { [weak self] path in
            let onWiFi = Self.broadband(path)
            Task { @MainActor in
                self?.applyPath(onWiFi: onWiFi)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }

    func readings(isVPNConnected: Bool) -> [ServiceProbeReading] {
        Self.projectedReadings(
            sites: sites,
            isVPNConnected: isVPNConnected,
            jitterSeed: jitterSeed
        )
    }

    func updatedLabel(at now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(updatedAt)))
        if seconds < 5 { return ui("Updated just now") }
        if seconds < 60 { return uiFormat("Updated %lld sec ago", seconds) }
        let minutes = seconds / 60
        if minutes < 60 {
            return minutes == 1 ? ui("Updated 1 min ago") : uiFormat("Updated %lld min ago", minutes)
        }
        let hours = minutes / 60
        return hours == 1 ? ui("Updated 1 hr ago") : uiFormat("Updated %lld hr ago", hours)
    }

    func refresh() {
        jitterSeed += 1
        updatedAt = .now
    }

    /// `nil` when the site was added.
    func addSite(name: String, link: String) -> String? {
        if let error = Self.additionError(name: name, link: link, existing: sites) {
            return error
        }
        guard let canonical = Self.canonicalLink(from: link) else { return ui("Enter a link like youtube.com") }
        sites.append(
            ServiceProbeSite(
                id: UUID(),
                name: Self.displayName(name: name, link: canonical),
                link: canonical
            )
        )
        updatedAt = .now
        persist()
        return nil
    }

    /// `nil` when the site was updated. The site keeps its own link, so saving it again is not a duplicate.
    func updateSite(id: UUID, name: String, link: String) -> String? {
        guard let index = sites.firstIndex(where: { $0.id == id }) else {
            return ui("This site is no longer in the list")
        }
        let others = sites.filter { $0.id != id }
        if let error = Self.additionError(name: name, link: link, existing: others) {
            return error
        }
        guard let canonical = Self.canonicalLink(from: link) else {
            return ui("Enter a link like youtube.com")
        }
        sites[index].name = Self.displayName(name: name, link: canonical)
        sites[index].link = canonical
        updatedAt = .now
        persist()
        return nil
    }

    func remove(at offsets: IndexSet) {
        sites.remove(atOffsets: offsets)
        updatedAt = .now
        persist()
    }

    func remove(id: UUID) {
        sites.removeAll { $0.id == id }
        updatedAt = .now
        persist()
    }

    static func projectedReadings(
        sites: [ServiceProbeSite],
        isVPNConnected: Bool,
        jitterSeed: Int
    ) -> [ServiceProbeReading] {
        return sites.map { site in
            let profile = profile(for: site)
            let base = isVPNConnected ? profile.open : profile.cellular
            return ServiceProbeReading(
                id: site.id,
                name: site.name,
                latencyMs: applyJitter(base, seed: jitterSeed, id: site.id)
            )
        }
    }

    static func additionError(
        name: String,
        link: String,
        existing: [ServiceProbeSite]
    ) -> String? {
        guard let canonical = canonicalLink(from: link) else {
            return ui("Enter a link like youtube.com")
        }
        let addedHost = host(of: canonical) ?? canonical
        if existing.contains(where: { host(of: $0.link) == addedHost }) {
            return ui("This site is already in the list")
        }
        _ = name
        return nil
    }

    static let defaultSites: [ServiceProbeSite] = [
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000001")!, name: "YouTube", link: "https://youtube.com"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000002")!, name: "Google", link: "https://google.com"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000003")!, name: "Yandex", link: "https://yandex.ru"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000004")!, name: "Avito", link: "https://avito.ru"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000005")!, name: "Wikipedia", link: "https://wikipedia.org"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000006")!, name: "VK", link: "https://vk.com"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000007")!, name: "Instagram", link: "https://instagram.com"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000008")!, name: "ChatGPT", link: "https://chatgpt.com"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-000000000009")!, name: "WhatsApp", link: "https://whatsapp.com"),
        ServiceProbeSite(id: UUID(uuidString: "A1B1C1D1-0000-4000-8000-00000000000A")!, name: "Telegram", link: "https://telegram.org"),
    ]

    private func applyPath(onWiFi: Bool) {
        let changed = !hasPath || isOnWiFi != onWiFi
        hasPath = true
        isOnWiFi = onWiFi
        if changed {
            updatedAt = .now
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sites) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadSites() -> [ServiceProbeSite] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([ServiceProbeSite].self, from: data)
        else { return defaultSites }
        return stored
    }

    nonisolated private static func broadband(_ path: NWPath) -> Bool {
        guard path.status == .satisfied, !path.isExpensive else { return false }
        return path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
    }

    private static func profile(for site: ServiceProbeSite) -> LatencyProfile {
        let host = host(of: site.link) ?? site.link
        if let known = knownBaselines[host] { return known }
        if let label = host.split(separator: ".").first, let known = knownBaselines[String(label)] {
            return known
        }
        return customBaseline(for: host)
    }

    private static func applyJitter(_ base: Int, seed: Int, id: UUID) -> Int {
        let value = base + jitter(seed: seed, id: id)
        if base >= ServiceProbeReading.slowThreshold {
            return max(ServiceProbeReading.slowThreshold, value)
        }
        return min(ServiceProbeReading.slowThreshold - 1, max(40, value))
    }

    private static func jitter(seed: Int, id: UUID) -> Int {
        guard seed > 0 else { return 0 }
        let mixed = id.uuidString.utf8.reduce(seed) { ($0 &* 33) &+ Int($1) }
        let magnitude = mixed == Int.min ? 0 : abs(mixed)
        let span = (magnitude % 31) - 15
        return span == 0 ? 1 : span
    }

    static func canonicalLink(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: withScheme),
              let host = components.host,
              host.contains("."),
              !host.hasPrefix("."),
              host.split(separator: ".").count >= 2
        else { return nil }
        var stored = components
        stored.scheme = components.scheme ?? "https"
        stored.query = nil
        stored.fragment = nil
        return stored.string
    }

    static func host(of link: String) -> String? {
        guard let host = URLComponents(string: link)?.host else { return nil }
        let stripped = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return stripped.lowercased()
    }

    static func displayName(name: String, link: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = host(of: link), let brand = brandNames[host] { return brand }
        guard let host = host(of: link), let label = host.split(separator: ".").first else {
            return link
        }
        return label.prefix(1).uppercased() + label.dropFirst()
    }

    private static func customBaseline(for host: String) -> LatencyProfile {
        let hash = host.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
        let cellular = 140 + Int(hash % 420)
        let open = max(48, cellular * 2 / 3)
        return LatencyProfile(cellular: cellular, open: open)
    }

    /// Without a VPN, YouTube and ChatGPT are slow. `open` is the connected tunnel.
    private static let knownBaselines: [String: LatencyProfile] = [
        "youtube.com": LatencyProfile(cellular: 530, open: 412),
        "google.com": LatencyProfile(cellular: 61, open: 61),
        "yandex.ru": LatencyProfile(cellular: 412, open: 412),
        "avito.ru": LatencyProfile(cellular: 412, open: 412),
        "wikipedia.org": LatencyProfile(cellular: 421, open: 421),
        "vk.com": LatencyProfile(cellular: 412, open: 412),
        "instagram.com": LatencyProfile(cellular: 362, open: 362),
        "chatgpt.com": LatencyProfile(cellular: 530, open: 362),
        "whatsapp.com": LatencyProfile(cellular: 223, open: 223),
        "telegram.org": LatencyProfile(cellular: 199, open: 199),
    ]

    private static let brandNames: [String: String] = [
        "youtube.com": "YouTube",
        "google.com": "Google",
        "yandex.ru": "Yandex",
        "ya.ru": "Yandex",
        "avito.ru": "Avito",
        "wikipedia.org": "Wikipedia",
        "vk.com": "VK",
        "instagram.com": "Instagram",
        "chatgpt.com": "ChatGPT",
        "whatsapp.com": "WhatsApp",
        "telegram.org": "Telegram",
    ]
}
