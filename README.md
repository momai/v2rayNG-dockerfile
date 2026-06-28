# v2rayNG Subscription Builder

[Перейти к русской версии](#русский)

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
- **Replace** the URL with your **subscription link**.
- APKs will appear in `output/`.

**Build locally:**
```bash
docker build --no-cache -t v2rayng-custom .
docker run --rm -v $(pwd)/output:/output v2rayng-custom -PmyArgument=https://example.com/s/your-subscription-url
```

### How it works
- Clones upstream v2rayNG
- Injects subscription URL (string resource and asset file)
- Modifies MainActivity for auto-import
- Builds APKs and copies to `output/`

### Troubleshooting
- Go/gomobile is not required: the image downloads a prebuilt `libv2ray.aar`.
- If Gradle fails with `Cannot parse project property android.newDsl`, rebuild the Docker image so `gradle.properties` is patched with a proper newline.
- If Android SDK errors mention `compileSdk`, update the installed platform in `Dockerfile` to match upstream v2rayNG.

---

## <a name="русский"></a>Русский

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

### Как работает
- Клонирует апстрим v2rayNG
- Вставляет URL подписки (строковый ресурс и файл в assets)
- Модифицирует MainActivity для автоимпорта
- Собирает APK и копирует в `output/`

### Решение проблем
- Go/gomobile больше не нужен: образ скачивает готовый `libv2ray.aar`.
- Если Gradle падает с `Cannot parse project property android.newDsl`, пересоберите Docker-образ, чтобы `gradle.properties` патчился с корректным переводом строки.
- Если Android SDK ругается на `compileSdk`, обновите платформу в `Dockerfile` под текущий upstream v2rayNG.
