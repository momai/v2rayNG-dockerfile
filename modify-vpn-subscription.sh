#!/bin/bash
set -e

# Проверяем, передан ли URL подписки
if [ -z "$1" ]; then
    echo "Не указан URL подписки, пропускаем модификацию"
    exit 0
fi

SUBSCRIPTION_URL="$1"
echo "Добавляем URL подписки: $SUBSCRIPTION_URL"

XML_SUBSCRIPTION_URL=$(printf '%s' "$SUBSCRIPTION_URL" \
    | sed -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g")
SED_XML_SUBSCRIPTION_URL=$(printf '%s' "$XML_SUBSCRIPTION_URL" | sed -e 's/[\/&|\\]/\\&/g')

# Проверяем существование директорий и файлов
SRC_DIR="/workspace/v2rayNG/V2rayNG/app/src/main"
STRINGS_FILE="${SRC_DIR}/res/values/strings.xml"

# Удаляем все .bak файлы, которые могут остаться от предыдущих сборок
echo "Удаляем все существующие .bak файлы..."
find "/workspace/v2rayNG" -name "*.bak" -delete
echo "Файлы .bak удалены"

echo "Поиск ключевых файлов..."

# Ищем strings.xml
if [ ! -f "$STRINGS_FILE" ]; then
    echo "ОШИБКА: Файл strings.xml не найден по пути $STRINGS_FILE"
    # Ищем файл strings.xml в проекте
    FOUND_STRINGS=$(find /workspace/v2rayNG -name "strings.xml" -type f)
    if [ -n "$FOUND_STRINGS" ]; then
        echo "Найдены файлы strings.xml:"
        echo "$FOUND_STRINGS"
        # Используем первый найденный файл
        STRINGS_FILE=$(echo "$FOUND_STRINGS" | head -n 1)
        echo "Используем файл: $STRINGS_FILE"
    else
        echo "Файл strings.xml не найден в проекте"
        exit 1
    fi
fi

# Добавляем строку для URL подписки в strings.xml
echo "Модифицируем strings.xml"

# Проверяем, существует ли уже строка с vpn_subscription_url
if grep -q "vpn_subscription_url" "$STRINGS_FILE"; then
    echo "Строка vpn_subscription_url уже существует, заменяем значение"
    sed -i "s|<string name=\"vpn_subscription_url\".*|<string name=\"vpn_subscription_url\" translatable=\"false\">$SED_XML_SUBSCRIPTION_URL</string>|" "$STRINGS_FILE"
else
    echo "Добавляем новую строку vpn_subscription_url"
    sed -i "/<\/resources>/i \    <string name=\"vpn_subscription_url\" translatable=\"false\">$SED_XML_SUBSCRIPTION_URL</string>" "$STRINGS_FILE"
fi

# Минимальная модификация - создаем файл с URL подписки
echo "Создаем файл с URL подписки для использования во время первого запуска"
mkdir -p /workspace/v2rayNG/V2rayNG/app/src/main/assets/
echo "$SUBSCRIPTION_URL" > /workspace/v2rayNG/V2rayNG/app/src/main/assets/subscription_url.txt
echo "Файл subscription_url.txt создан в директории assets"

# Ищем файл MainActivity.kt и делаем модификацию
MAIN_ACTIVITY=$(find /workspace/v2rayNG -name "MainActivity.kt" -type f | head -n 1)
if [ -n "$MAIN_ACTIVITY" ]; then
    echo "Найден файл MainActivity.kt: $MAIN_ACTIVITY"
    
    # Проверяем, содержит ли файл уже нашу модификацию
    if ! grep -q "subscription_url.txt" "$MAIN_ACTIVITY"; then
        echo "Создаем модификацию MainActivity.kt для автоматического импорта подписки"
        
        # Создаем временный файл с кодом для вставки
        cat > /tmp/subscription_code.txt << 'EOF'
        // Автоматический импорт подписки при первом старте.
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val subUrl = try {
                    getString(R.string.vpn_subscription_url)
                } catch (e: Exception) {
                    try {
                        assets.open("subscription_url.txt").bufferedReader().use { it.readLine() ?: "" }
                    } catch (e2: Exception) {
                        ""
                    }
                }.trim()

                if (subUrl.isNotEmpty()) {
                    val prefs = getSharedPreferences("app_prefs", android.content.Context.MODE_PRIVATE)
                    val importedKey = "subscription_imported_${subUrl.hashCode()}"

                    if (!prefs.getBoolean(importedKey, false)) {
                        delay(1000)
                        val (_, importedSubscriptions) =
                            AngConfigManager.importBatchConfig(subUrl, mainViewModel.subscriptionId, true)

                        val subscriptionExists = MmkvManager.decodeSubscriptions()
                            .any { it.subscription.url == subUrl }

                        if (importedSubscriptions > 0 || subscriptionExists) {
                            prefs.edit().putBoolean(importedKey, true).apply()
                        }

                        withContext(Dispatchers.Main) {
                            setupGroupTab()
                            mainViewModel.reloadServerList()
                            if (importedSubscriptions > 0 || subscriptionExists) {
                                android.widget.Toast.makeText(
                                    this@MainActivity,
                                    "Подписка добавлена. Серверы обновлены.",
                                    android.widget.Toast.LENGTH_LONG
                                ).show()
                            } else {
                                android.widget.Toast.makeText(
                                    this@MainActivity,
                                    "Не удалось импортировать подписку. Попробуйте добавить её вручную.",
                                    android.widget.Toast.LENGTH_LONG
                                ).show()
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    e.printStackTrace()
                    android.widget.Toast.makeText(
                        this@MainActivity,
                        "Ошибка при импорте подписки: ${e.message}",
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                }
            }
        }
EOF
        
        # Находим подходящее место для вставки в onCreate
        if grep -q "override fun onCreate" "$MAIN_ACTIVITY"; then
            # Вставляем наш код после super.onCreate
            sed -i '/super\.onCreate/ r /tmp/subscription_code.txt' "$MAIN_ACTIVITY"
            echo "Код для автоматического импорта подписки добавлен в MainActivity.kt"
        else
            echo "Не найден метод onCreate в файле MainActivity.kt"
        fi
        
        # Удаляем временный файл
        rm /tmp/subscription_code.txt
    else
        echo "Файл MainActivity.kt уже содержит нашу модификацию"
    fi
else
    echo "Файл MainActivity.kt не найден"
fi

# Финальная проверка и удаление всех .bak файлов
echo "Выполняем финальную проверку на наличие .bak файлов..."
find /workspace/v2rayNG -name "*.bak" -type f -delete
echo "Все .bak файлы удалены"

echo "Модификация завершена успешно" 