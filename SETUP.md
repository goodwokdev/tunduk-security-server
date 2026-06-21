# Tunduk Security Server — Setup & Provisioning Runbook

End-to-end path from a fresh VM to a **registered** Tunduk security server with a
**registered subsystem** ready for СМЭВ data exchange.

The Docker stack (see [README.md](README.md)) provides a running but
*unconfigured* server. Bringing it to `registered` is the sequence below. Some
steps depend on **external parties with lead time** — start §0 immediately, in
parallel with everything else.

---

## 0. External dependencies — start these first (they gate everything)

These are the real long-poles. Kick them off on day one:

1. **Global configuration anchor** — request the anchor file from the Tunduk /
   СМЭВ administrators. You will verify its hash against their published value.
2. **Member details** — obtain from Tunduk admins:
   - Member **class**: `GOV` (government) or `COM` (commercial).
   - Member **code** (your organization's code).
3. **CA agreement with ГУ «Кызмат»** — conclude the PKI agreement at
   <https://gukyzmat.gov.kg/pki>. Document packet for legal entities:
   - Соглашение о присоединении к Регламенту УЦ ГУ «Кызмат»
   - Доверенность пользователя УЦ (для представителей юр. лиц)
   - Копия паспорта пользователя УЦ
   - Копия приказа о назначении уполномоченного лица
   - Копия приказа о назначении руководителя организации
   - Копия свидетельства о госрегистрации/перерегистрации юр. лица
   - Сопроводительное письмо в адрес ГУ «Кызмат»

You also choose, ahead of time:
- **Security server code** — Latin letters only, must include the org name, unique
  within the Tunduk instance. **Cyrillic here = the signed certificate is rejected.**
- **SoftToken PIN** — min 15 chars, mixed case + digits + symbols. Store it safely;
  losing it forces reissuing all certificates. This must equal `XROAD_TOKEN_PIN`.

---

## 1. Host prerequisites

- VM physically in Kyrgyzstan, Docker Engine + Compose v2 installed.
- Dedicated to X-Road (it owns the published ports — no other web server).
- 4 GB RAM min, 100 GB free disk.

### Firewall / ports

| Dir | Port(s) | Purpose |
|---|---|---|
| in | `5500`, `5577` /tcp | message exchange + OCSP between security servers (from other SS) |
| in | `4000` /tcp | admin UI (keep to admin subnet / SSH tunnel) |
| in | `8080`, `8443` /tcp | information-system access points (from your internal IS only) |
| in | `80` /tcp | ACME (only if using ACME-issued certs) |
| out | `5500`, `5577` /tcp | to other security servers |
| out | `80`, `443`, `4001` /tcp | central server + global conf |
| out | `62301`, `62302` /tcp | CA OCSP + timestamping |
| out | `123` /udp | NTP |

Restrict `4000`/`8080`/`8443` to trusted sources. `5500`/`5577` must be reachable
from the wider X-Road network.

---

## 2. Bring up the stack

```bash
cp .env.example .env
# Edit .env: XROAD_TOKEN_PIN (== your chosen SoftToken PIN), admin creds, DB password.
docker compose up -d
docker compose ps        # wait for both services -> healthy
docker compose logs -f security-server
```

On first start the entrypoint creates `/etc/xroad/db.properties`, connects to
Postgres as superuser, and auto-creates the `serverconf` / `messagelog` /
`op-monitor` databases and roles. No manual DB setup needed.

Tunnel to the UI and log in (self-signed TLS):

```bash
ssh -L 4000:127.0.0.1:4000 <vm-host>
# https://localhost:4000  — credentials = XROAD_ADMIN_USER / XROAD_ADMIN_PASSWORD
```

---

## 3. Initial configuration (admin UI)

1. **Upload the anchor** (§0.1). Verify the displayed hash matches the published value.
2. Enter, when prompted:
   - Member **class** (`GOV`/`COM`) and member **code** (§0.2).
   - **Security server code** (Latin, §0).
   - **SoftToken PIN** — must equal `XROAD_TOKEN_PIN` in `.env`.
3. The UI shows the owner name registered on the central server — confirm it's correct.

---

## 4. Timestamping service

`SETTINGS → System Parameters → Timestamping Services → ADD` → select the Tunduk TSP.
(Required; the security server signs message logs against it.)

---

## 5. Keys & certificate signing requests

In **Keys and Certificates**, open the SoftToken (enter PIN), **Add key** twice:

| Key | Label | Notes |
|---|---|---|
| AUTH | authentication | `Generate CSR`, **Country Code (C) = KG** → `Done` → download `auth_csr_*.der` |
| SIGN | signing | `Generate CSR`, **Country Code (C) = KG** → `Done` → download `sign_csr_*.der` |

Email **both** `.der` files to the Certification Authority: **kuc@infocom.kg**.
(This requires the ГУ «Кызмат» agreement from §0.3 to be in place.)

Wait for the CA to return the two signed certificates.

---

## 6. Import, register, activate

1. **Import cert** — import **both** returned certificates (auth + sign) on the
   Keys and Certificates page.
2. Next to the **auth** certificate click **Register**; enter the server's DNS name
   or external IP. Status: `saved` → `registration in progress`.
3. Wait ~10–15 min for the Tunduk electronic-interaction center to approve.
4. After approval, click the certificate → **Activate** (activate on your side too).

> OCSP status stuck on `Unknown` instead of `Good`?
> `docker compose restart security-server`, or check Diagnostics for the next OCSP
> refresh (default interval ~48 min without manual requests).

The security server is now registered.

---

## 7. Register the subsystem (СМЭВ data exchange)

1. Pick a **Subsystem Code** — ASCII / Latin only.
2. **Clients → Add subsystem** → enter the Subsystem Code → **OK**.
3. Click **Register** to submit the request.
4. **Notify ОАО «Тундук»** that you registered the subsystem (this step is manual —
   they don't see it automatically).
5. State: `registration in progress` → ~10 min → `registered`.

Connection protocol defaults to **HTTPS**. To use HTTP, toggle it in the subsystem
properties. For HTTPS client certs see the Tunduk article
"Настройка HTTPS-сертификатов подсистемы".

Migrating an existing subsystem from an old 6.21.1 server? Enter the previous
subsystem name, notify the Tunduk admin that you're migrating, and re-create
services manually.

---

## 8. Backup & restore

**Backup** (schedule via cron — copy output off-box for 3-year retention):

```bash
backup/backup.sh
# produces backup/out/{db,etc-xroad,var-lib-xroad}-<stamp>.{sql.gz,tar.gz}
```

**Restore** onto a fresh stack (same image version, Postgres 12):

```bash
docker compose up -d db                       # start DB only
gunzip -c backup/out/db-<stamp>.sql.gz | \
  docker compose exec -T -e PGPASSWORD="$XROAD_DB_PWD" db psql -U postgres
docker compose up -d                          # start SS
# restore /etc/xroad and /var/lib/xroad into their volumes, e.g.:
docker compose exec -T security-server tar -C / -xzf - < backup/out/etc-xroad-<stamp>.tar.gz
docker compose exec -T security-server tar -C / -xzf - < backup/out/var-lib-xroad-<stamp>.tar.gz
docker compose restart security-server
```

> Restore requires the **same PostgreSQL major (12)** — cross-version restore fails.

---

## Reference

- Tunduk install guide: <https://wiki.tunduk.kg/doku.php?id=install-security-server-742>
- Tunduk subsystem registration: <https://wiki.tunduk.kg/doku.php?id=registration-on-security-server-742-ubuntu2204>
- NIIS Sidecar user guide: <https://github.com/nordic-institute/X-Road/tree/master/doc/Sidecar>
- CA (ГУ «Кызмат»): <https://gukyzmat.gov.kg/pki> — CSRs to **kuc@infocom.kg**
