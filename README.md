# rallly-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [Rallly](https://github.com/lukevella/rallly) 4.17.2.

Rallly is a self-hosted scheduling tool: create a date/time poll, share the
link, and let participants vote without an account. Polls support comments,
optional participant e-mail collection, and e-mail invitations/notifications
once an SMTP server is configured.

## What this is

A TOS Docker application archive (`rallydocker.tar.gz`) that installs Rallly on
TOS 7 through the App Center. Two architectures are published:

| Package | Architecture | Submitted as |
|---|---|---|
| `rallydocker_x86_64.tar.gz` | x86_64 | App record `rallydocker` (platform `x86_64`) |
| `rallydocker_aarch64.tar.gz` | aarch64 | App record `rallydocker` (platform `aarch64`) |

The upstream image `lukevella/rallly:4.17.2` is a multi-arch OCI index
(`linux/amd64` + `linux/arm64`), so both packages pull the same upstream
release; only the `config.ini` platform field differs.

## How it works

| | |
|---|---|
| Containers | `rallydocker` (Rallly, port 3000) + `rallydocker-db` (PostgreSQL 16.16, internal only) |
| Container image | `lukevella/rallly:4.17.2` (Docker Hub, used unmodified) |
| Open | `http://<NAS-IP>:8143/` |
| Runs as | non-root, `user: "1000:1000"`, no capabilities, no Docker socket |
| Persistent data | `/Volume1/DockerAppData/rallydocker/data`, `.../db`, `.../cache` |
| Logs | `docker logs rallydocker` (stdout/stderr) |

## First start

1. **Administrator account.** On a fresh database the container creates one
   account with the `admin` role and a random 20-character password, and writes
   it to:

   ```
   /Volume1/DockerAppData/rallydocker/data/admin-credentials.txt
   ```

   Read the e-mail and password there, sign in at `/login`, then change the
   password under **Settings → Security** and delete the file.

   This exists because upstream's sign-in is an e-mailed one-time code; without
   an SMTP server the instance would otherwise be impossible to enter. On an
   existing installation (database already has users) no account is created.

2. **Public address.** The NAS LAN address is not known inside the container,
   while Rallly needs an absolute base URL (it builds links from it and rejects
   login POSTs whose browser `Origin` differs). On first start the entrypoint
   serves a short "starting" page, records the first non-local `Host` header in
   `data/public-url.state`, and then starts the app with that address. Open the
   app once from the address you normally use and it is remembered. To change
   it later (new IP, DNS name, TLS proxy), create `data/public-url` containing
   one line, e.g. `https://rallly.example.com`, and restart the container.

3. **E-mail (optional).** Sign-in codes, invitations and notifications need
   SMTP. Create `data/smtp.env`:

   ```ini
   SMTP_HOST=smtp.example.com
   SMTP_PORT=587
   SMTP_SECURE=false
   SMTP_USER=rally@example.com
   SMTP_PWD=your-app-password
   NOREPLY_EMAIL=rally@example.com
   REGISTRATION_ENABLED=true
   ```

   Then restart the container. Registration is disabled by default so that an
   unconfigured instance does not offer a sign-up that cannot deliver its code;
   set `REGISTRATION_ENABLED=true` only after SMTP works. Without SMTP, polls
   are still fully usable: the owner signs in with the generated password,
   shares the poll link, and participants vote and comment without accounts.

## Repository layout

```
.
├── CHANGELOG.md              # user-visible changes per package version
├── LICENSE                   # MIT licence of the packaging files
├── NOTICE.md                 # upstream licence, image provenance, trademarks
├── PRIVACY.md                # what is stored, where it goes, retention, rights
├── README.md                 # this file
├── tosapp.json               # build spec (version, image, volumes, 23-language text)
├── src/
│   ├── config.ini            # TOS application metadata
│   ├── rallydocker.lang      # 23-language text (generated from tosapp.json)
│   ├── rallydocker.svg       # application icon
│   ├── docker-compose.yml    # two services, non-root, healthchecks
│   └── entrypoint.sh         # secret/base-URL/migrations/admin bootstrap
├── scripts/
│   ├── build.sh              # build one architecture -> out/rallydocker.tar.gz
│   └── build-dual.sh         # build both architectures + official self-test
├── test/
│   └── install-and-verify.sh # on-device end-to-end verification (needs root)
├── tools/
│   └── verify.py             # review-standards self-check (build gate)
└── TOSAppSelfTestingTool     # official TerraMaster package checker
```

## Privacy

See [PRIVACY.md](PRIVACY.md). It lists every stored field group, the retention
period, the user-rights/deletion channels and every third-party endpoint
(Rallly update check at `api.rallly.co`, licensing at `licensing.rallly.co`,
your SMTP server, Docker Hub, optional SSO/calendar providers). The policy is
also linked from the App Center via `config.ini`'s `help` field.

## Notices

See [NOTICE.md](NOTICE.md). Rallly is licensed under **AGPL-3.0-or-later**;
the official Docker Hub image is used unmodified and is not redistributed here.
The packaging files are MIT.

## Build

```bash
scripts/build.sh                    # current version + tosapp.json platform
scripts/build.sh 4.17.2-1 x86_64    # explicit
scripts/build-dual.sh 4.17.2-1      # both architectures + official -c check
```

`build.sh` stages the four package files, substitutes the version/platform
placeholders, embeds `src/entrypoint.sh` into the compose block (escaping every
`$` as `$$`), strips CRLF/BOM/AppleDouble, runs `tools/verify.py` (a
review-standards self-check: archive layout, JSON validity, required fields,
14+ languages, version consistency, Docker-Hub-only images, fixed tag,
non-root user, per-service healthcheck/TZ/restart, data paths below the
application data root, `x-app-meta` position, no literal secrets, icon limits),
and produces a deterministic tar.gz + `.sha256`.

## Local verification

```bash
./TOSAppSelfTestingTool -c out/rallydocker_x86_64.tar.gz
./TOSAppSelfTestingTool -c out/rallydocker_aarch64.tar.gz
bash test/install-and-verify.sh          # on-device; needs root, not for CI
```

Docker applications cannot be side-loaded through the App Center's manual
install page (it accepts `.deb` only); the official tool's `-i` mode or
`docker compose` are the ways to install one for testing.

## Upgrade notes (4.17.0-1 → 4.17.2-1)

- Upstream 4.17.0 → 4.17.2: 4.17.1 upgrades Next.js (seven moderate advisories)
  and Hono; 4.17.2 fixes an uploaded-image deletion issue (S3 only). No
  configuration change or extra migration is required beyond the normal Prisma
  migrations the container applies at start.
- PostgreSQL stays on **16.16**: the existing `db/` cluster keeps working. A
  major-version jump needs `pg_upgrade`/dump-restore and is not done silently.
- New volumes `cache/` (Next.js cache) and new files in `data/`
  (`public-url.state`, `admin-credentials.txt`) are created automatically.
- Port **8143 is unchanged**. TOS has thousands of apps and host-port collisions
  are normal; if 8143 is taken, install only one of the conflicting apps.

## Data and uninstall

- Everything persistent is under `/Volume1/DockerAppData/rallydocker/`:
  `data/` (secret, learned URL, admin credentials, optional `smtp.env`), `db/`
  (PostgreSQL cluster) and `cache/` (derived, safe to delete).
- Removing the app from the App Center **keeps** that folder. Deleting it (with
  the app stopped) removes every poll, participant, comment and account; this
  cannot be undone. Back it up first:
  `tar czf rallly-backup.tgz -C /Volume1/DockerAppData rallydocker`.
- There is no uninstall hook in a TOS Docker package; the folder is the only
  thing to remove.

## Limitations and security notes

- **Plain HTTP on the LAN.** Put a TLS reverse proxy in front before exposing
  the app to the internet; otherwise cookies and poll content are visible on the
  network. Set `data/public-url` to the `https://` address when you do.
- **No S3 storage configured.** Rallly stores profile pictures, space icons and
  instance logos in S3-compatible storage. Without `S3_*` variables the upload
  buttons return an error; polls, voting, comments and e-mail invitations are
  unaffected. Configure S3 only if you want image uploads — data then goes to
  the endpoint you choose.
- **No SSO/calendar/conferencing configured.** OIDC, Google, Microsoft, Zoom and
  Webex integrations are supported upstream but off; enabling them sends data to
  the provider you choose (see PRIVACY.md §3).
- **No automatic update.** Install App Center updates yourself; the container
  never updates its own image.
- **Data at rest is not encrypted by the app.** Use NAS volume encryption and
  restrict access to `/Volume1/DockerAppData/rallydocker/`.

## Store submission checklist

1. Public GitHub repo (code + README + PRIVACY + NOTICE only).
2. Release tag `v4.17.2-1` with assets `rallydocker_x86_64.tar.gz`,
   `rallydocker_x86_64.tar.gz.sha256`, `rallydocker_aarch64.tar.gz`,
   `rallydocker_aarch64.tar.gz.sha256`.
3. Developer platform → Add Application: ID `rallydocker`, package type Docker,
   repository URL, architectures `x86_64` **and** `aarch64`.
4. Version `4.17.2-1` → automated validation → review. Submission remarks:
   “Rectified per review comments.”
