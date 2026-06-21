# tunduk-security-server (Helm-чарт)

Сервер безопасности Тундук (X-Road 7.4.2) для Kubernetes. Это второй флавор
развёртывания. Опорный, эталонный флавор - docker-compose в корне репозитория;
по нему проще всего понять устройство. Чарт повторяет тот же контракт: официальный
образ niis/xroad-security-server-sidecar:7.4.2, PostgreSQL 12, безопасные по
умолчанию порты, постоянные тома.

## Что разворачивается

- StatefulSet сервера безопасности, ровно одна реплика (см. "Почему replicas=1").
  Тома /etc/xroad и /var/lib/xroad - постоянные.
- StatefulSet PostgreSQL 12 (по умолчанию встроенный) с постоянным томом.
- Service-ы: админ-панель (4000), точки доступа ИС (8080/8443), обмен между
  серверами (5500/5577).
- Secret с PIN токена, учёткой панели и паролем БД.

## Установка

```bash
helm install tunduk ./helm-charts/tunduk-security-server \
  --namespace tunduk --create-namespace \
  --set auth.tokenPin='ВашPIN-минимум-15-символов' \
  --set auth.adminPassword='сильный-пароль-панели' \
  --set postgresql.password='пароль-суперпользователя-БД'
```

Для prod вместо паролей в командной строке задай готовый Secret:

```bash
kubectl -n tunduk create secret generic tunduk-creds \
  --from-literal=XROAD_TOKEN_PIN='...' \
  --from-literal=XROAD_ADMIN_USER='xrd-admin' \
  --from-literal=XROAD_ADMIN_PASSWORD='...' \
  --from-literal=XROAD_DB_PWD='...'

helm install tunduk ./helm-charts/tunduk-security-server \
  --namespace tunduk \
  --set auth.existingSecret=tunduk-creds
```

После установки следуй подсказкам из вывода (NOTES) и регистрируй сервер по SETUP.md.

## Доступ к панели

Панель по умолчанию не торчит наружу. Достаётся через port-forward:

```bash
kubectl -n tunduk port-forward svc/tunduk-tunduk-security-server-ss-admin 4000:4000
# браузер: https://localhost:4000 (сертификат самоподписанный)
```

## Почему replicas=1

У сервера безопасности уникальная криптографическая личность: свои ключи AUTH/SIGN
и зарегистрированный код сервера (server code). Две реплики с одной личностью - это
одна личность с нескольких адресов, и Тундук отклонит это как конфликт. Поэтому чарт
падает при securityServer.replicaCount > 1. Настоящая отказоустойчивость в X-Road -
это отдельная HA-топология (общая БД + primary/secondary), она вне рамок этого чарта.

## Почему PostgreSQL именно 12

Образ сервера несёт внутри PostgreSQL 12. Бэкап и восстановление в X-Road ломаются
между мажорными версиями PostgreSQL, поэтому внешняя БД обязана быть версии 12.
PG12 уже снят с поддержки (EOL); риск снижаем тем, что БД живёт внутри кластера и
не торчит наружу.

## Внешняя БД

```bash
helm install tunduk ./helm-charts/tunduk-security-server \
  --namespace tunduk \
  --set postgresql.embedded=false \
  --set externalDatabase.host=mydb.internal \
  --set externalDatabase.port=5432 \
  --set postgresql.password='пароль-суперпользователя'
```

Мажор внешней БД обязан быть 12.

## Открыть порты обмена наружу

```bash
helm upgrade tunduk ./helm-charts/tunduk-security-server -n tunduk \
  --reuse-values \
  --set service.xroad.type=LoadBalancer
```

Наружу осознанно выходят только 5500/5577 (там mTLS). Админ-панель и точки доступа
ИС держи внутри кластера.

## Основные значения

| Значение | По умолчанию | Назначение |
|---|---|---|
| securityServer.image.tag | 7.4.2 | Тег образа (full, не slim) |
| securityServer.replicaCount | 1 | Жёстко 1, иначе чарт падает |
| securityServer.persistence.etcXroad.size | 1Gi | Том /etc/xroad (ключи, сертификаты) |
| securityServer.persistence.varXroad.size | 20Gi | Том /var/lib/xroad (журнал, 3 года) |
| postgresql.embedded | true | Встроенный PG12 или внешняя БД |
| postgresql.image.tag | 12 | Мажор обязан быть 12 |
| postgresql.persistence.size | 10Gi | Том данных БД |
| auth.tokenPin | (заглушка) | PIN токена, минимум 15 символов |
| auth.adminUser / adminPassword | (заглушки) | Учётка панели |
| auth.existingSecret | "" | Готовый Secret вместо паролей в values |
| service.xroad.type | ClusterIP | LoadBalancer/NodePort для выхода наружу |
| ingress.enabled | false | Ingress для панели (иначе port-forward) |

## Проверка чарта

```bash
helm lint ./helm-charts/tunduk-security-server
helm template tunduk ./helm-charts/tunduk-security-server
```
