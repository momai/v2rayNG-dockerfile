# Используем образ с Android SDK
FROM thyrlian/android-sdk:latest

# Устанавливаем необходимые инструменты
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    unzip \
    openjdk-17-jdk \
    binutils-x86-64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем специфичные версии SDK и Build Tools
RUN yes | sdkmanager --licenses
RUN sdkmanager "platforms;android-33" "build-tools;33.0.2" "ndk;25.2.9519653"

# Устанавливаем переменные окружения для сборки
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin:$ANDROID_HOME/build-tools/33.0.2

# Клонируем репозиторий v2rayNG
WORKDIR /workspace
RUN git clone https://github.com/2dust/v2rayNG.git

# Скачиваем готовую библиотеку AndroidLibXrayLite из релизов
WORKDIR /workspace
RUN mkdir -p /workspace/v2rayNG/V2rayNG/app/libs && \
    cd /workspace/v2rayNG/V2rayNG/app/libs && \
    curl -L -o libv2ray.aar https://github.com/2dust/AndroidLibXrayLite/releases/download/v25.4.18/libv2ray.aar

# Подготовка рабочей директории
WORKDIR /workspace/v2rayNG/V2rayNG
RUN chmod +x ./gradlew

# Добавляем модификацию для VPN подписки при сборке
COPY modify-vpn-subscription.sh /workspace/modify-vpn-subscription.sh
RUN chmod +x /workspace/modify-vpn-subscription.sh

# Создаем скрипт для сборки и копирования
COPY build_and_copy.sh /build_and_copy.sh
RUN chmod +x /build_and_copy.sh

# Устанавливаем ENTRYPOINT
ENTRYPOINT ["/build_and_copy.sh"]
