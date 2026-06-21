# Сервер безопасности Тундук (X-Road 7.4.2) - Docker Compose

Развёртывание сервера безопасности Тундук (СМЭВ "Түндүк") для одной виртуалки,
на официальном, поддерживаемом для production образе NIIS X-Road Security Server Sidecar.

## Два флавора

Один и тот же сервер, два способа его запустить. У обоих общий контракт: образ
`niis/xroad-security-server-sidecar:7.4.2`, PostgreSQL 12, безопасные по умолчанию
порты, постоянное состояние. Процесс регистрации в [SETUP.md](SETUP.md) одинаковый.

| Флавор | Где | Для чего |
|---|---|---|
| **docker-compose** ([docker-compose/](docker-compose)) | одна виртуалка | опорный флавор - проще всего читать и поднимать |
| **Helm-чарт** ([helm-charts/tunduk-security-server](helm-charts/tunduk-security-server)) | Kubernetes | одиночный production-faithful инстанс в кластере |

Руководство для новичков: [docs/guide-for-newcomers.md](docs/guide-for-newcomers.md).

## Почему нет своего образа

Репозиторий пакетов Тундука (`deb.tunduk.kg/ubuntu22.04-7.4.2`) отдаёт байт-в-байт
те же пакеты NIIS - тот же maintainer (`NIIS <info@niis.org>`) и тот же git-хэш
(`gita30be58`) во всех 28 пакетах. Никакого пакета `tunduk-*` нет.

Сервер становится "тундуковским" только через конфигурацию в рантайме - глобальный
якорь конфигурации (anchor), который указывает на центральный сервер Тундука, а не
через бинарник. Поэтому мы берём `niis/xroad-security-server-sidecar:7.4.2` как есть
и грузим якорь при настройке. Меньше своего кода, нечего поддерживать в маппинге
служб, обновления безопасности приходят простым `docker pull`.

> ВНИМАНИЕ: используй full-образ с тегом `7.4.2`, никогда не `-slim`. slim не умеет
> журналирование сообщений, а оно для Тундука обязательно (3-летнее хранение журнала
> требуется по закону).

## Стек

| Сервис | Образ | Назначение |
|---|---|---|
| `security-server` | `niis/xroad-security-server-sidecar:7.4.2` | X-Road SS (supervisord запускает proxy, signer, confclient, proxy-ui-api, monitor, opmonitor, messagelog) |
| `db` | `postgres:12` | базы serverconf + messagelog. **PG 12** - обязан совпадать с мажором внутри образа, иначе ломается бэкап/восстановление. |

Состояние живёт в трёх именованных томах: `xroad-config` (`/etc/xroad`),
`xroad-archive` (`/var/lib/xroad`), `pgdata`.

## Быстрый старт

Файлы compose-флавора лежат в каталоге `docker-compose/`, команды запускай оттуда:

```bash
cd docker-compose
cp .env.example .env        # затем впиши: PIN, учётку панели, пароль БД
docker compose up -d
docker compose ps           # дождись, пока оба сервиса healthy
```

Затем открой админ-панель и заверши настройку - **см. [SETUP.md](SETUP.md)**.
Compose-стек даёт *запущенный, но ненастроенный* сервер; регистрация
(якорь, ключи, сертификаты от УЦ, подсистема) - это пошаговая последовательность
в SETUP.md.

Панель по умолчанию привязана к loopback. Доступ через SSH-туннель:

```bash
ssh -L 4000:127.0.0.1:4000 <vm-host>
# открой https://localhost:4000  (сертификат самоподписанный)
```

## Файлы

```
docker-compose/docker-compose.yml   стек из двух сервисов (SS + Postgres 12)
docker-compose/.env.example         шаблон секретов/портов -> скопировать в .env
helm-charts/tunduk-security-server/ Helm-чарт (флавор для Kubernetes)
backup/backup.sh                    pg_dumpall + tar обоих томов xroad (удобно для cron)
SETUP.md                            пошаговый runbook по настройке от начала до конца
```

## Требования (хост)

- Linux-виртуалка **физически в Кыргызстане** (требование Тундука).
- Выделена под X-Road - владеет опубликованными портами; не ставь рядом другой веб-сервер.
- Docker Engine + Compose v2.
- Минимум 4 GB RAM, 100 GB свободного диска (журнал сообщений растёт).
- Сеть: см. раздел "Фаервол / порты" в SETUP.md.

## Эксплуатация

Команды `docker compose` запускай из каталога `docker-compose/`.

- **Логи:** `docker compose logs -f security-server`
- **Перезапуск служб X-Road:** `docker compose restart security-server`
  (он же лечит ситуацию, когда статус OCSP застрял на `Unknown`)
- **Бэкап:** `backup/backup.sh` (по расписанию через cron) - копию уноси с машины.
- **Обновление образа:** меняешь тег, `docker compose pull && up -d`. Энтрипоинт
  мигрирует конфигурацию на старте. Сначала сделай бэкап.
