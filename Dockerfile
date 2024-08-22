# Используем образ с Android SDK
FROM thyrlian/android-sdk:latest

# Устанавливаем необходимые инструменты
RUN apt-get update && apt-get install -y \
    git \
    wget \
    unzip \
    openjdk-17-jdk \
    binutils-x86-64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем Go 1.22.2
RUN wget https://golang.org/dl/go1.22.2.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
ENV PATH $PATH:/usr/local/go/bin

# Устанавливаем gomobile
RUN go install golang.org/x/mobile/cmd/gomobile@latest
ENV PATH $PATH:/root/go/bin

# Устанавливаем специфичные версии SDK и Build Tools
RUN yes | sdkmanager --licenses
RUN sdkmanager "platforms;android-33" "build-tools;33.0.2" "ndk;25.2.9519653"

# Устанавливаем переменные окружения для сборки
ENV ANDROID_HOME /opt/android-sdk
ENV ANDROID_NDK_HOME $ANDROID_HOME/ndk/25.2.9519653
ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk-amd64
ENV PATH $PATH:$JAVA_HOME/bin

# Клонируем репозиторий v2rayNG с кастомными изменениями
WORKDIR /workspace
RUN git clone https://github.com/momai/v2rayNG.git

# Собираем зависимости
RUN mkdir build && cd build && \
    git clone --depth=1 -b main https://github.com/2dust/AndroidLibXrayLite.git && \
    cd AndroidLibXrayLite && \
    go get github.com/xtls/xray-core || true && \
    gomobile init && \
    go mod tidy -v && \
    gomobile bind -v -androidapi 21 -ldflags='-s -w' ./ && \
    cp *.aar /workspace/v2rayNG/V2rayNG/app/libs/

# Подготовка рабочей директории
WORKDIR /workspace/v2rayNG/V2rayNG
RUN chmod +x ./gradlew

# Создаем скрипт для сборки и копирования
COPY build_and_copy.sh /build_and_copy.sh
RUN chmod +x /build_and_copy.sh

# Устанавливаем ENTRYPOINT
ENTRYPOINT ["/build_and_copy.sh"]
