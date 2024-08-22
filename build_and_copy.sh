#!/bin/sh

# Проверяем, передан ли аргумент myArgument
if echo "$@" | grep -q -- "-PmyArgument="; then
    # Извлекаем значение myArgument
    MY_ARGUMENT=$(echo "$@" | sed -n 's/.*-PmyArgument=\([^ ]*\).*/\1/p')
    
    # Заменяем VAS3K_SUB_URL в файле конфигурации
    sed -i "s|VAS3K_SUB_URL|$MY_ARGUMENT|g" app/src/main/res/values/strings.xml
fi

# Выполняем сборку с переданными аргументами
./gradlew "$@"

# Копируем результаты сборки
mkdir -p /output
cp -r /workspace/v2rayNG/V2rayNG/app/build/outputs/apk/release/* /output/
echo "Build completed. APK files copied to /output/"
