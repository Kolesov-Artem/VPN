# TestFlight: Velvet VPN

Пошаговая инструкция, чтобы расшарить прототип с друзьями через TestFlight.

## Что уже настроено в проекте

- Bundle ID: `com.artem.velvetvpn`
- Отображаемое имя: **Velvet**
- Team ID: `6YXVWZL243`
- Иконка приложения (1024×1024)
- Скрипт загрузки: `scripts/upload-testflight.sh`
- Export options: `ExportOptions.plist`

## Разовая настройка (≈15 минут)

### 1. Apple Developer Program

Нужна платная подписка Apple Developer ($99/год) на аккаунте `tema_cofe@mail.ru`.
Без неё TestFlight недоступен.

### 2. Войти в Xcode

1. Открой **Xcode → Settings → Accounts**
2. Нажми **+** → **Apple ID** → войди как `tema_cofe@mail.ru`
3. Выбери команду **6YXVWZL243** и нажми **Manage Certificates**
4. Убедись, что есть сертификат **Apple Distribution** (Xcode создаст автоматически при первой загрузке)

### 3. Зарегистрировать Bundle ID

1. Открой [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. **+** → **App IDs** → **App**
3. Bundle ID: `com.artem.velvetvpn`
4. Description: `Velvet VPN`
5. Capabilities для прототипа не нужны (это UI-прототип без реального VPN-туннеля)

### 4. Создать приложение в App Store Connect

1. Открой [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **Apps** → **+** → **New App**
3. Заполни:
   - **Platform:** iOS
   - **Name:** Velvet (или другое, если занято)
   - **Primary Language:** Russian или English
   - **Bundle ID:** `com.artem.velvetvpn`
   - **SKU:** `velvetvpn` (любой уникальный идентификатор)
4. Сохрани

## Загрузка билда

### Вариант A — через скрипт (рекомендуется)

```bash
chmod +x scripts/upload-testflight.sh
./scripts/upload-testflight.sh
```

При первом запуске Xcode может попросить войти в Apple ID или подтвердить доступ к App Store Connect.

### Вариант B — через Xcode GUI

1. Открой `VPN.xcodeproj` в Xcode
2. Выбери устройство **Any iOS Device (arm64)**
3. **Product → Archive**
4. В Organizer: **Distribute App → App Store Connect → Upload**
5. Следуй мастеру (Automatic signing, Upload)

## Пригласить друзей

### Внутренние тестеры (быстро, без ревью Apple)

- До 100 человек из вашей команды в App Store Connect
- Билд доступен сразу после обработки (5–15 мин)
- **Users and Access → Internal Testing** → добавь email друзей как **App Store Connect Users** (роль Developer или выше)

### Внешние тестеры (для друзей вне команды)

1. App Store Connect → **Velvet** → **TestFlight**
2. Дождись, пока билд пройдёт **Processing**
3. Заполни **Test Information** (что тестировать, контакты)
4. **External Testing** → **+** → создай группу (например «Друзья»)
5. Добавь email друзей или включи **Public Link**
6. Первый внешний билд проходит **Beta App Review** (обычно 24–48 ч)

Друзья получат письмо или ссылку → установят приложение **TestFlight** из App Store → откроют приглашение.

## Обновление прототипа

Перед каждой новой загрузкой увеличь **Build** в Xcode:

- Target **VPN** → **General** → **Build** (сейчас `1` → поставь `2`, `3`, …)
- Или в `project.pbxproj`: `CURRENT_PROJECT_VERSION`

Затем снова запусти `./scripts/upload-testflight.sh`.

## Частые проблемы

| Ошибка | Решение |
|--------|---------|
| `No Accounts with App Store Connect Access` | Войди в Apple ID в Xcode Settings → Accounts |
| `No suitable application records were found` | Создай приложение в App Store Connect (шаг 4) |
| `Bundle ID is not available` | Зарегистрируй `com.artem.velvetvpn` в Developer Portal |
| Билд «Processing» долго | Подожди до 30 мин; при ошибке придёт email от Apple |
| Друзья не видят билд | Для внешних тестеров нужен Beta App Review |

## Важно

Это **UI-прототип** — реальный VPN-туннель не поднимается. Для продакшн-VPN понадобятся Network Extension, отдельные entitlements и ревью Apple по правилам VPN-приложений.
