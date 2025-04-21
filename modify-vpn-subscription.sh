#!/bin/bash
set -e

# Проверяем, передан ли URL подписки
if [ -z "$1" ]; then
    echo "Не указан URL подписки, пропускаем модификацию"
    exit 0
fi

SUBSCRIPTION_URL="$1"
echo "Добавляем URL подписки: $SUBSCRIPTION_URL"

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
    sed -i "s|<string name=\"vpn_subscription_url\".*|<string name=\"vpn_subscription_url\" translatable=\"false\">$SUBSCRIPTION_URL</string>|" "$STRINGS_FILE"
else
    echo "Добавляем новую строку vpn_subscription_url"
    sed -i "/<\/resources>/i \    <string name=\"vpn_subscription_url\" translatable=\"false\">$SUBSCRIPTION_URL</string>" "$STRINGS_FILE"
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
        // Автоматический импорт подписки при старте
        try {
            // Получаем URL подписки
            val subUrl = try {
                getString(R.string.vpn_subscription_url)
            } catch (e: Exception) {
                try {
                    val inputStream = assets.open("subscription_url.txt")
                    val reader = java.io.BufferedReader(java.io.InputStreamReader(inputStream))
                    val url = reader.readLine() ?: ""
                    reader.close()
                    url
                } catch (e2: Exception) {
                    ""
                }
            }
            
            if (subUrl.isNotEmpty()) {
                // Проверяем, не импортировали ли мы уже эту подписку
                val prefs = getSharedPreferences("app_prefs", android.content.Context.MODE_PRIVATE)
                val importedKey = "subscription_imported_${subUrl.hashCode()}"
                if (!prefs.getBoolean(importedKey, false)) {
                    // Выполняем импорт подписки в фоновом потоке через 3 секунды
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        try {
                            // Создаем объект подписки
                            val subItem = com.v2ray.ang.dto.SubscriptionItem()
                            subItem.remarks = "Auto Imported Subscription"
                            subItem.url = subUrl
                            subItem.enabled = true
                            
                            // Генерируем ID подписки
                            val subId = "SUB_" + com.v2ray.ang.util.Utils.getUuid()
                            
                            // Сохраняем подписку в основном потоке
                            com.v2ray.ang.handler.MmkvManager.encodeSubscription(subId, subItem)
                            
                            // Отмечаем, что подписка добавлена
                            prefs.edit().putBoolean(importedKey, true).apply()
                            
                            // Показываем уведомление о добавлении подписки
                            android.widget.Toast.makeText(
                                this,
                                "Подписка добавлена. Обновление серверов...",
                                android.widget.Toast.LENGTH_LONG
                            ).show()
                            
                            // Запускаем обновление конфигурации в фоновом потоке через дополнительную задержку
                            kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.IO) {
                                try {
                                    // Даем дополнительное время на инициализацию сети
                                    kotlinx.coroutines.delay(5000)
                                    
                                    // Обновляем конфигурацию по подписке
                                    val count = com.v2ray.ang.handler.AngConfigManager.updateConfigViaSub(Pair(subId, subItem))
                                    
                                    // Показываем результат в UI потоке
                                    kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                                        if (count > 0) {
                                            android.widget.Toast.makeText(
                                                this@MainActivity,
                                                "Подписка успешно обновлена. Добавлено $count серверов.",
                                                android.widget.Toast.LENGTH_LONG
                                            ).show()
                                            
                                            // Принудительно обновляем список серверов
                                            mainViewModel.reloadServerList()
                                            
                                            // Попытка переключиться на вкладку серверов
                                            try {
                                                val serversId = resources.getIdentifier("servers", "id", packageName)
                                                if (serversId != 0) {
                                                    // Переключаемся в зависимости от доступных view
                                                    if (binding.navView != null) {
                                                        val menuItem = binding.navView.menu.findItem(serversId)
                                                        if (menuItem != null) {
                                                            menuItem.isChecked = true
                                                            onNavigationItemSelected(menuItem)
                                                        }
                                                    }
                                                    
                                                    // Дополнительно обновляем список после перехода на вкладку серверов
                                                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                                        mainViewModel.reloadServerList()
                                                        adapter.notifyDataSetChanged()
                                                    }, 500)
                                                }
                                            } catch (e: Exception) {
                                                e.printStackTrace()
                                            }
                                        } else {
                                            android.widget.Toast.makeText(
                                                this@MainActivity,
                                                "Не удалось обновить серверы. Попробуйте обновить подписку вручную.",
                                                android.widget.Toast.LENGTH_LONG
                                            ).show()
                                        }
                                    }
                                } catch (e: Exception) {
                                    // Обработка ошибки в UI потоке
                                    kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                                        e.printStackTrace()
                                        android.widget.Toast.makeText(
                                            this@MainActivity,
                                            "Ошибка при обновлении подписки: ${e.message}",
                                            android.widget.Toast.LENGTH_LONG
                                        ).show()
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            android.widget.Toast.makeText(
                                this,
                                "Ошибка при добавлении подписки: ${e.message}",
                                android.widget.Toast.LENGTH_LONG
                            ).show()
                        }
                    }, 3000) // Увеличиваем задержку до 3 секунд
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
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