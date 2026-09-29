import Foundation

enum VPNLocationListFamily: Int, CaseIterable, Equatable {
    case smart
    case bridge
    case torrent
    case lte
    case country

    var sectionTitle: String? {
        switch self {
        case .smart: "Страны"
        case .bridge: "Через Москву"
        case .torrent: "Загрузки"
        case .lte: "Мобильный интернет"
        case .country: nil
        }
    }

    var sectionExplanation: String? {
        switch self {
        case .smart: nil
        case .bridge: "Если обычный сервер не открывается"
        case .torrent: "Фильмы, игры, торренты и большие файлы"
        case .lte: "Когда режут или глушат сеть. Сначала Smart"
        case .country: nil
        }
    }

    var isCatalogFamily: Bool { self != .country }

    /// Countries sit last so typed catalogs (bridge, torrent, LTE) stay on top.
    static let listOrder: [VPNLocationListFamily] = [.bridge, .torrent, .lte, .smart, .country]
}

struct VPNLocationListIdentity: Equatable {
    let family: VPNLocationListFamily
    let groupingKey: String
    let groupTitle: String
    let groupFlag: String
    let nestedTitle: String
    let nestedSubtitle: String
    let isPinned: Bool
    let variantRank: Int
}

struct VPNLocationListSection: Identifiable, Equatable {
    var id: String { "\(family.rawValue)" }

    let family: VPNLocationListFamily
    let title: String?
    let explanation: String?
    let groups: [VPNCountryLocationGroup]
}

enum VPNLocationListCatalog {
    static func identity(for location: VPNLocation) -> VPNLocationListIdentity {
        LocationIdentityCache.shared.identity(for: location) {
            parse(location)
        }
    }

    static func searchText(for location: VPNLocation) -> String {
        let identity = identity(for: location)
        return [
            location.name,
            location.city,
            location.kind.title,
            identity.groupTitle,
            identity.nestedTitle,
            identity.nestedSubtitle,
            identity.family.sectionTitle,
            identity.family.sectionExplanation,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

private extension VPNLocationListCatalog {
    static func parse(_ location: VPNLocation) -> VPNLocationListIdentity {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if name == "LTE-Авто" {
            return pinned(
                family: .lte,
                title: "Smart LTE",
                flag: "✨",
                key: "lte|auto",
                subtitle: "Сам подберёт лучший LTE и переключит, если этот не возьмётся"
            )
        }

        if name == "SMART-Авто" {
            return pinned(
                family: .smart,
                title: "Smart",
                flag: "✨",
                key: "smart|auto",
                subtitle: "Сам найдёт лучший, решит сбои и будет переключать автоматически"
            )
        }

        if let lte = parseLTEUniversal(name) {
            return lte
        }

        if let typed = parseTypedCountry(name, caption: location.city, flag: location.flag) {
            return typed
        }

        if location.city == "Для временного доступа" {
            return VPNLocationListIdentity(
                family: .smart,
                groupingKey: "smart|\(name)",
                groupTitle: name,
                groupFlag: location.flag,
                nestedTitle: "Разовый доступ",
                nestedSubtitle: "Другой вход, если основные не открываются",
                isPinned: false,
                variantRank: 5
            )
        }

        return VPNLocationListIdentity(
            family: .country,
            groupingKey: "country|\(location.name)",
            groupTitle: location.name,
            groupFlag: location.flag,
            nestedTitle: location.city,
            nestedSubtitle: location.city,
            isPinned: false,
            variantRank: 0
        )
    }

    static func pinned(
        family: VPNLocationListFamily,
        title: String,
        flag: String,
        key: String,
        subtitle: String
    ) -> VPNLocationListIdentity {
        VPNLocationListIdentity(
            family: family,
            groupingKey: key,
            groupTitle: title,
            groupFlag: flag,
            nestedTitle: title,
            nestedSubtitle: subtitle,
            isPinned: true,
            variantRank: -1
        )
    }

    static func parseLTEUniversal(_ name: String) -> VPNLocationListIdentity? {
        let pattern = /^#(\S+) LTE Универсальный(?: \[([^\]]+)\])?$/
        guard let match = name.wholeMatch(of: pattern) else { return nil }

        let number = String(match.1)
        let tag = match.2.map(String.init)
        let isFallback = tag != nil

        return VPNLocationListIdentity(
            family: .lte,
            groupingKey: isFallback ? "lte|hys2" : "lte|universal",
            groupTitle: isFallback ? "Запасной протокол" : "Универсальный",
            groupFlag: "📶",
            nestedTitle: "#\(number)",
            nestedSubtitle: isFallback
                ? "Если универсальные не берутся"
                : "Почти все операторы и регионы",
            isPinned: false,
            variantRank: lteRank(number: number, tag: tag)
        )
    }

    static func parseTypedCountry(
        _ name: String,
        caption: String,
        flag: String
    ) -> VPNLocationListIdentity? {
        let pattern = /^(SMART|BRIDGE|TORRENT)-(.+?)(?: \[([^\]]+)\])?$/
        let searchable: String
        if let torrent = name.range(of: "TORRENT-") {
            searchable = String(name[torrent.lowerBound...])
        } else {
            searchable = name
        }

        guard let match = searchable.wholeMatch(of: pattern) else { return nil }

        let familyName = String(match.1)
        let country = String(match.2)
        let tag = match.3.map(String.init)
        let resolvedFlag = countryFlags[country] ?? flag
        let family: VPNLocationListFamily = switch familyName {
        case "SMART": .smart
        case "BRIDGE": .bridge
        case "TORRENT": .torrent
        default: .country
        }
        let copy = variantCopy(familyName: familyName, tag: tag, caption: caption)

        return VPNLocationListIdentity(
            family: family,
            groupingKey: "\(familyName.lowercased())|\(country)",
            groupTitle: country,
            groupFlag: resolvedFlag,
            nestedTitle: copy.title,
            nestedSubtitle: copy.subtitle,
            isPinned: false,
            variantRank: copy.rank
        )
    }

    static func variantCopy(
        familyName: String,
        tag: String?,
        caption: String
    ) -> (title: String, subtitle: String, rank: Int) {
        switch familyName {
        case "BRIDGE":
            return ("Через Москву", humanCaption(caption), 3)
        case "TORRENT":
            return ("Для загрузок", humanCaption(caption), 4)
        default:
            switch tag {
            case "S+":
                return ("Эксперимент", humanCaption(caption), 1)
            case "HYS2":
                return ("Запасной", humanCaption(caption), 2)
            default:
                return ("Smart", humanCaption(caption), 0)
            }
        }
    }

    static func humanCaption(_ caption: String) -> String {
        switch caption {
        case "Быстрый. Без рекламы":
            "Быстрый, без рекламы"
        case "Hysteria2. Экспериментальный":
            "Другой протокол, если обычный не открывается"
        case "Экспериментальная конфигурация":
            "Новая сборка — попробуй, если обычная не зашла"
        case "Восточным регионам":
            "Ближе к Азии"
        case "Через Москву. Работает всё":
            "Через Москву — обычно открывается всё"
        case "Франкфурт через Москву":
            "Заход в Германию через Москву"
        case "Стокгольм через Москву":
            "Заход в Швецию через Москву"
        case "Амстердам через Москву":
            "Заход в Нидерланды через Москву"
        case "Разрешен torrent. Быстрый.":
            "Фильмы, игры, торренты и большие файлы"
        case "Автовыбор доступного сервера":
            "Сам найдёт лучший, решит сбои и будет переключать автоматически"
        case "Автовыбор: SMART/LTE-Авто":
            "Сам подберёт лучший LTE и переключит, если этот не возьмётся"
        case "Почти все операторы и регионы":
            "Почти все операторы и регионы"
        case "Для временного доступа":
            "Разовый доступ"
        default:
            caption
        }
    }

    static func lteRank(number: String, tag: String?) -> Int {
        let base = Int(number.filter(\.isNumber)) ?? 0
        return 10 + base + (tag == nil ? 0 : 1000)
    }

    static let countryFlags: [String: String] = [
        "Нидерланды": "🇳🇱",
        "Швеция": "🇸🇪",
        "Россия": "🇷🇺",
        "Германия": "🇩🇪",
        "Италия": "🇮🇹",
        "Литва": "🇱🇹",
        "Франция": "🇫🇷",
        "Англия": "🇬🇧",
        "Канада": "🇨🇦",
        "США": "🇺🇸",
        "Сингапур": "🇸🇬",
        "Япония": "🇯🇵",
        "Бразилия": "🇧🇷",
        "Египет": "🇪🇬",
        "Индия": "🇮🇳",
        "Казахстан": "🇰🇿",
        "ОАЭ": "🇦🇪",
        "Таиланд": "🇹🇭",
        "Турция": "🇹🇷",
    ]
}

extension VPNLocation {
    var listIdentity: VPNLocationListIdentity {
        VPNLocationListCatalog.identity(for: self)
    }
}

/// Names repeat across providers, and each identity runs several regexes.
/// The list is rebuilt often, so the parse result is kept.
private final class LocationIdentityCache {
    static let shared = LocationIdentityCache()

    private struct Key: Hashable {
        let name: String
        let city: String
        let flag: String
        let kind: VPNLocation.Kind
    }

    private var storage: [Key: VPNLocationListIdentity] = [:]

    func identity(
        for location: VPNLocation,
        make: () -> VPNLocationListIdentity
    ) -> VPNLocationListIdentity {
        let key = Key(
            name: location.name,
            city: location.city,
            flag: location.flag,
            kind: location.kind
        )
        if let cached = storage[key] {
            return cached
        }
        let made = make()
        storage[key] = made
        return made
    }
}
