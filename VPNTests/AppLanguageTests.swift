import Foundation
import Testing
@testable import VPN

struct AppLanguageTests {
    @Test func languageSwitchChangesCompactCopy() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppLanguage.storageKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppLanguage.storageKey)
            } else {
                defaults.removeObject(forKey: AppLanguage.storageKey)
            }
        }

        defaults.set(AppLanguage.ru, forKey: AppLanguage.storageKey)
        #expect(ui("Settings") == "Настройки")
        #expect(ui("One page") == "Страница")
        #expect(ui("Bottom menu") == "Меню")
        #expect(ui("Dashboard") == "Обзор")
        #expect(ui("Hide sites") == "Скрыть")
        #expect(ui("All sites well") == "Сайты ок")
        #expect(uiFormat("%lld slow", 2) == "2 медленно")
        #expect(VPNLocation.Kind.standard.storageTitle == "Standard")
        #expect(VPNLocation.Kind.standard.title == "Обычный")
        #expect(VPNHomeChrome.hero.title == "Герой")

        defaults.set(AppLanguage.en, forKey: AppLanguage.storageKey)
        #expect(ui("Settings") == "Settings")
        #expect(ui("Через Москву") == "Via Moscow")
        #expect(ui("Нидерланды") == "Netherlands")
        #expect(VPNHomeChrome.tabs.title == "Bottom menu")
        #expect(VPNLocation.Kind.standard.storageTitle == "Standard")
    }
}
