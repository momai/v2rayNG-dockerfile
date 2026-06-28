# Используем образ с Android SDK
FROM thyrlian/android-sdk:latest

ARG ANDROID_LIBXRAY_LITE_VERSION=v26.6.27

# Устанавливаем необходимые инструменты
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    unzip \
    openjdk-17-jdk \
    binutils-x86-64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем стабильные версии SDK, доступные через sdkmanager
RUN yes | sdkmanager --licenses
RUN sdkmanager "platforms;android-36" "build-tools;36.0.0"

# Устанавливаем переменные окружения для сборки
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_COMPILE_SDK=36
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin:$ANDROID_HOME/build-tools/36.0.0

# Клонируем репозиторий v2rayNG
WORKDIR /workspace
RUN git clone https://github.com/2dust/v2rayNG.git

# Скачиваем готовую библиотеку AndroidLibXrayLite из релизов
WORKDIR /workspace
RUN mkdir -p /workspace/v2rayNG/V2rayNG/app/libs && \
    cd /workspace/v2rayNG/V2rayNG/app/libs && \
    curl -L -o libv2ray.aar "https://github.com/2dust/AndroidLibXrayLite/releases/download/${ANDROID_LIBXRAY_LITE_VERSION}/libv2ray.aar"

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
