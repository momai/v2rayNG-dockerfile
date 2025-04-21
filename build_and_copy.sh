#!/bin/bash
set -e

echo "====================== v2rayNG Builder ======================"
echo "Дата и время: $(date)"
echo "Версия Go: $(go version)"
echo "Версия Java: $(java -version 2>&1 | head -n 1)"
echo "============================================================="

# Проверяем, передан ли аргумент myArgument
MY_ARGUMENT=""
if echo "$@" | grep -q -- "-PmyArgument="; then
    # Извлекаем значение myArgument
    MY_ARGUMENT=$(echo "$@" | sed -n 's/.*-PmyArgument=\([^ ]*\).*/\1/p')
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

# Увеличиваем память для Gradle
echo "org.gradle.jvmargs=-Xmx4608m" >> gradle.properties
echo "Добавлены настройки памяти для Gradle"

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
        ./gradlew assemble${BUILD_VARIANT^}Release -PmyArgument="$MY_ARGUMENT" $@ --stacktrace
    else
        ./gradlew assembleRelease -PmyArgument="$MY_ARGUMENT" $@ --stacktrace
    fi
else
    echo "Сборка без URL подписки"
    if [ -n "$BUILD_VARIANT" ]; then
        ./gradlew assemble${BUILD_VARIANT^}Release $@ --stacktrace
    else
        ./gradlew assembleRelease $@ --stacktrace
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
