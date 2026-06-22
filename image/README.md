# Патч-образ Тундука (image/)

Тонкий образ `FROM niis/xroad-security-server-sidecar:7.4.2`, который накладывает поверх
официального образа NIIS Тундуковский патч: KG-специфичный класс профиля сертификата
`KgSkKlass3CertificateProfileInfoProvider` (для УЦ "Кызмат"). Без него сервер не
сгенерирует CSR в формате, который примет УЦ.

## Почему это нужно

Официальный образ NIIS 7.4.2 - ванильный X-Road. Тундук добавляет ровно 3 Java-класса
(KgSk-провайдер + 2 inner) в `proxy.jar`. Пакеты `xroad-proxy` и `xroad-proxy-ui-api` в
репозитории Тундука имеют `Architecture: all` (чистая Java), поэтому их jar безопасно
накладываются на focal-образ NIIS. Подробности и сравнение - в
`docs/superpowers/specs/2026-06-22-tunduk-patched-image-design.md`.

## Сборка

```bash
docker build -t tunduk-security-server:7.4.2 image/
```

Сборка скачивает два пакета с `deb.tunduk.kg`, сверяет их sha256 (пиннинг в Dockerfile),
заменяет два jar и в конце проверяет, что KG-класс действительно оказался в образе
(иначе падает).

## Проверка

```bash
# класс KgSk должен присутствовать в собранном образе:
docker run --rm --entrypoint bash tunduk-security-server:7.4.2 -c \
  'grep -al KgSkKlass3CertificateProfileInfoProvider /usr/share/xroad/jlib/proxy-1.0.jar'
```

## Использование

- docker-compose: `docker compose up --build` (см. `docker-compose/`) соберёт образ локально.
- Helm: собрать образ, запушить в свой реестр, указать `image.repository` (см. README чарта).

## Граница

Локально доказывается, что KG-класс попал в образ. Что CSR реально принимается УЦ "Кызмат" -
проверяется только на зарегистрированной личности с настоящим якорем, на стороне развёртывания.
