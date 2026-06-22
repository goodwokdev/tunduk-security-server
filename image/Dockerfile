# Тонкий патч-образ Тундука поверх официального NIIS sidecar.
#
# Тундук = ванильный X-Road 7.4.2 ПЛЮС один KG-специфичный класс профиля сертификата
# (KgSkKlass3CertificateProfileInfoProvider) для УЦ "Кызмат". Этот класс есть в пакетах
# deb.tunduk.kg, но отсутствует в официальном образе NIIS. Без него не сгенерировать CSR
# в формате, который примет УЦ.
#
# Патч аддитивный и затрагивает ровно 2 jar (оба из пакетов Architecture: all, чистая Java):
#   proxy-1.0.jar         (+3 класса: KgSkKlass3 провайдер + 2 inner)
#   proxy-ui-api-1.0.jar  (по составу идентичен официальному; обновляем для консистентности версий)
# Поэтому накладываем именно jar, а НЕ ставим пакеты Тундука через apt: образ NIIS собран
# на ubuntu20.04 (focal), пакеты Тундука - ubuntu22.04 (jammy), и apt потянул бы несовместимые
# native-зависимости. Overlay чистой Java этого избегает.

FROM niis/xroad-security-server-sidecar:7.4.2

# Репозиторий и точные имена файлов пакетов (несут версию + git-хэш сборки).
ARG TUNDUK_REPO=https://deb.tunduk.kg/ubuntu22.04-7.4.2
ARG PROXY_DEB=xroad-proxy_7.4.2-1.gita30be58.ubuntu22.04_all.deb
ARG PROXY_UI_DEB=xroad-proxy-ui-api_7.4.2-1.gita30be58.ubuntu22.04_all.deb

# sha256 скачиваемых пакетов - пиннинг ради воспроизводимости и для отлова тихой
# подмены апстрима. При несовпадении сборка падает.
ARG PROXY_SHA256=70a7f30ad6ff09e3813ae64c81573fda18fed266a2d15df8c0c5392077ef3b3c
ARG PROXY_UI_SHA256=806706aaab34bec3e60f8fed1e0b8acadfedb8c32d8b7b1fa74aa846078853fe

USER root
RUN set -eux; \
    tmp="$(mktemp -d)"; cd "$tmp"; \
    curl -fsSL -o proxy.deb     "${TUNDUK_REPO}/${PROXY_DEB}"; \
    curl -fsSL -o proxy-ui.deb  "${TUNDUK_REPO}/${PROXY_UI_DEB}"; \
    echo "${PROXY_SHA256}  proxy.deb"       | sha256sum -c -; \
    echo "${PROXY_UI_SHA256}  proxy-ui.deb" | sha256sum -c -; \
    # Распаковать пакеты и наложить их jar поверх файлов официального образа.
    # Симлинки proxy.jar / proxy-ui-api.jar указывают на эти *-1.0.jar, трогать их не нужно.
    dpkg-deb -x proxy.deb     ext-proxy; \
    dpkg-deb -x proxy-ui.deb  ext-proxy-ui; \
    install -m 0644 ext-proxy/usr/share/xroad/jlib/proxy-1.0.jar \
        /usr/share/xroad/jlib/proxy-1.0.jar; \
    install -m 0644 ext-proxy-ui/usr/share/xroad/jlib/proxy-ui-api-1.0.jar \
        /usr/share/xroad/jlib/proxy-ui-api-1.0.jar; \
    # Доказательство, что патч лёг: KG-класс теперь присутствует. Иначе сборка падает.
    grep -al "KgSkKlass3CertificateProfileInfoProvider" /usr/share/xroad/jlib/proxy-1.0.jar; \
    cd /; rm -rf "$tmp"

# Энтрипоинт, supervisord, порты, тома - всё унаследовано от базового образа без изменений.
