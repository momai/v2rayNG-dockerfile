#!/bin/bash
set -e

echo "====================== v2rayNG Builder ======================"
echo "Дата и время: $(date)"
if command -v go >/dev/null 2>&1; then
    echo "Версия Go: $(go version)"
else
    echo "Версия Go: не установлен (не требуется при использовании готового libv2ray.aar)"
fi
echo "Версия Java: $(java -version 2>&1 | head -n 1)"
echo "============================================================="

# Проверяем, передан ли аргумент myArgument
MY_ARGUMENT=""
GRADLE_ARGS=()
for arg in "$@"; do
    if [[ "$arg" == -PmyArgument=* ]]; then
        MY_ARGUMENT="${arg#-PmyArgument=}"
    else
        GRADLE_ARGS+=("$arg")
    fi
done

if [ -n "$MY_ARGUMENT" ]; then
    # Извлекаем значение myArgument
    echo "URL подписки: $MY_ARGUMENT"
    
    # Применяем модификацию для добавления URL подписки
    echo "Модифицирую исходный код для добавления URL подписки..."
    /workspace/modify-vpn-subscription.sh "$MY_ARGUMENT"
    if [ $? -ne 0 ]; then
        echo "ОШИБКА: Не удалось модифицировать исходный код!"
        exit 1
    fi
    echo "Модификация исходного кода завершена успешно"
fi

# Удаляем все файлы .bak, которые могут помешать сборке
echo "Очистка всех .bak файлов перед сборкой..."
find /workspace/v2rayNG -name "*.bak" -type f -delete
echo "Очистка завершена"

# Выбираем вариант сборки
cd /workspace/v2rayNG/V2rayNG
echo "Рабочая директория: $(pwd)"

# Увеличиваем память для Gradle, не ломая последнюю строку upstream gradle.properties
ensure_gradle_property() {
    local key="$1"
    local value="$2"
    local file="gradle.properties"

    touch "$file"
    if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then
        printf '\n' >> "$file"
    fi

    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$file"
    fi
}

ensure_gradle_property "org.gradle.jvmargs" "-Xmx4608m -Dfile.encoding=UTF-8"
echo "Настройки памяти для Gradle обновлены"

# Upstream v2rayNG может поднять compileSdk раньше, чем пакет появится в sdkmanager.
if [ -n "${ANDROID_COMPILE_SDK:-}" ] && [ -f "app/build.gradle.kts" ]; then
    sed -i -E "s/(compileSdk = )[0-9]+/\1${ANDROID_COMPILE_SDK}/" app/build.gradle.kts
    sed -i -E "s/(targetSdk = )[0-9]+/\1${ANDROID_COMPILE_SDK}/" app/build.gradle.kts
    echo "compileSdk/targetSdk установлены в ${ANDROID_COMPILE_SDK}"
fi

# Проверяем структуру проекта
echo "Проверка структуры проекта..."
ls -la
echo "Содержимое app/build.gradle.kts:"
if [ -f "app/build.gradle.kts" ]; then
    cat app/build.gradle.kts | grep -i "playstore" || echo "Вариант сборки playstore не найден"
else
    echo "Файл app/build.gradle.kts не найден!"
    find . -name "build.gradle.kts" | xargs -I{} echo "Найден: {}"
fi

# Проверяем существование варианта сборки playstore
BUILD_VARIANT=""
if grep -q "playstore" app/build.gradle.kts 2>/dev/null; then
    BUILD_VARIANT="playstore"
    echo "Используем вариант сборки: $BUILD_VARIANT"
else
    echo "Используем стандартный вариант сборки"
fi

# Выполняем сборку с переданными аргументами
echo "Запуск сборки..."
if [ -n "$MY_ARGUMENT" ]; then
    echo "Сборка с аргументом URL подписки"
    if [ -n "$BUILD_VARIANT" ]; then
        ./gradlew assemble${BUILD_VARIANT^}Release -PmyArgument="$MY_ARGUMENT" "${GRADLE_ARGS[@]}" --stacktrace
    else
        ./gradlew assembleRelease -PmyArgument="$MY_ARGUMENT" "${GRADLE_ARGS[@]}" --stacktrace
    fi
else
    echo "Сборка без URL подписки"
    if [ -n "$BUILD_VARIANT" ]; then
        ./gradlew assemble${BUILD_VARIANT^}Release "${GRADLE_ARGS[@]}" --stacktrace
    else
        ./gradlew assembleRelease "${GRADLE_ARGS[@]}" --stacktrace
    fi
fi

# Проверяем результаты сборки
echo "Проверка результатов сборки..."
find app/build/outputs -type f -name "*.apk" | sort

# Копируем результаты сборки
echo "Копирование результатов сборки..."
mkdir -p /output

# Создаем ключ для подписания, если его нет
if [ ! -f "/keystore.jks" ]; then
    echo "Создаем ключ для подписания APK..."
    keytool -genkey -v -keystore /keystore.jks -alias v2ray -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=V2rayNG, OU=V2rayNG, O=V2rayNG, L=Москва, ST=Москва, C=RU"
fi

# Находим и обрабатываем все APK файлы
echo "Обрабатываем APK файлы..."
APK_FILES=$(find /workspace/v2rayNG/V2rayNG/app/build/outputs -name "*.apk")

if [ -n "$APK_FILES" ]; then
    for apk in $APK_FILES; do
        base_name=$(basename "$apk")
        output_apk="/output/${base_name}"
        
        echo "Обрабатываем: $apk -> $output_apk"
        
        # Проверяем, нужно ли подписывать APK (если это неподписанный APK)
        if [[ "$apk" == *"unsigned"* ]] || ! apksigner verify --verbose "$apk" &>/dev/null; then
            echo "Подписываем APK..."
            cp "$apk" "/tmp/app.apk"
            zipalign -v -p 4 "/tmp/app.apk" "/tmp/aligned.apk"
            apksigner sign --ks /keystore.jks --ks-pass pass:android --ks-key-alias v2ray --key-pass pass:android "/tmp/aligned.apk"
            cp "/tmp/aligned.apk" "$output_apk"
            rm -f "/tmp/app.apk" "/tmp/aligned.apk"
        else
            echo "APK уже подписан, просто копируем"
            cp "$apk" "$output_apk"
        fi
    done
else
    echo "ОШИБКА: APK файлы не найдены в каталоге сборки!"
    find /workspace/v2rayNG/V2rayNG/app/build -type f -name "*.apk" || echo "APK файлы не найдены!"
    exit 1
fi

echo "Сборка завершена. APK файлы скопированы в /output/"

# Показываем список скопированных файлов
echo "Список файлов в /output:"
ls -la /output/

echo "============================================================="
echo "Сборка завершена успешно"
echo "============================================================="
