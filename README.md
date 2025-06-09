# v2rayNG with Automatic Subscription Import / v2rayNG с автоматическим импортом подписки

---

## English

### Overview
Docker image for building v2rayNG with automatic subscription URL import. On first launch, the subscription is imported and activated.

### Features
- Builds v2rayNG from upstream
- Adds subscription URL at build time
- Automatic import on first app launch
- Multi-arch support (arm64-v8a, armeabi-v7a, x86_64, x86)

### Usage
**Recommended:** Use prebuilt image from GitHub Container Registry.

```bash
docker run --rm -v $(pwd)/output:/output ghcr.io/momai/v2rayng-dockerfile:latest -PmyArgument=https://example.com/s/your-subscription-url
```
- Replace the URL with your subscription link.
- APKs will appear in `output/`.

**Build locally:**
```bash
docker build --no-cache -t v2rayng-custom .
docker run --rm -v $(pwd)/output:/output v2rayng-custom -PmyArgument=https://example.com/s/your-subscription-url
```

**Extra Gradle args:**
```bash
docker run --rm -v $(pwd)/output:/output v2rayng-custom -PmyArgument=https://example.com/s/your-subscription-url --stacktrace --info
```

### How it works
- Clones upstream v2rayNG
- Injects subscription URL (string resource and asset file)
- Modifies MainActivity for auto-import
- Builds APKs and copies to `output/`

### Troubleshooting
- For Go/gomobile errors, use: Go 1.20.14 + gomobile v0.0.0-20231108080712-20b9621131a5
- "toolchain not available": check Go/gomobile versions in Dockerfile

---

## Русский

### Описание
Docker-образ для сборки v2rayNG с автоматическим импортом URL подписки. При первом запуске подписка импортируется и активируется.

### Особенности
- Сборка v2rayNG из апстрима
- Добавление URL подписки на этапе сборки
- Автоматический импорт при первом запуске
- Поддержка всех архитектур (arm64-v8a, armeabi-v7a, x86_64, x86)

### Использование
**Рекомендуется:** использовать готовый образ из GitHub Container Registry.

```bash
docker run --rm -v $(pwd)/output:/output ghcr.io/momai/v2rayng-dockerfile:latest -PmyArgument=https://example.com/s/your-subscription-url
```
- Замените URL на ссылку вашей подписки.
- APK-файлы появятся в папке `output/`.

**Собрать локально:**
```bash
docker build --no-cache -t v2rayng-custom .
docker run --rm -v $(pwd)/output:/output v2rayng-custom -PmyArgument=https://example.com/s/your-subscription-url
```

**Доп. параметры Gradle:**
```bash
docker run --rm -v $(pwd)/output:/output v2rayng-custom -PmyArgument=https://example.com/s/your-subscription-url --stacktrace --info
```

### Как работает
- Клонирует апстрим v2rayNG
- Вставляет URL подписки (строковый ресурс и файл в assets)
- Модифицирует MainActivity для автоимпорта
- Собирает APK и копирует в `output/`

### Решение проблем
- Для ошибок Go/gomobile: используйте Go 1.20.14 + gomobile v0.0.0-20231108080712-20b9621131a5
- "toolchain not available": проверьте версии Go/gomobile в Dockerfile
