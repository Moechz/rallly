# Changelog

All notable user-visible changes to the Rallly TOS application package.

## 4.17.2-1 — 2026-11-25

Remediation of the App Center review findings for `4.17.0-1` (x86_64 on-hold:
`C10 C3 C4 C5 C6 C7 C8 C9 T1` plus `F3 F5 F7 S11`). Both architectures are
built and resubmitted together — the previous release incorrectly claimed that
upstream publishes no arm64 image; `lukevella/rallly` is a multi-arch OCI index
(`linux/amd64` + `linux/arm64`).

### Privacy and compliance (C3 / C4 / C5 / C7 / C8)

- Added `PRIVACY.md`: what is stored (accounts, scrypt password hashes,
  sessions with IP/user-agent, polls, options, participants incl. optional
  e-mail, votes, comments, spaces, invitations, calendar/conferencing OAuth
  tokens, queued e-mails, licences, instance UUID), the PostgreSQL cluster and
  data-folder paths, the package's own secret/credential files, log contents,
  browser cookies, retention, user rights (access / correction / account
  deletion / full deletion / export) and the deletion channels.
- Documented every real outbound endpoint: the Rallly update check
  (`https://api.rallly.co/api/updates`, version + random instance UUID), the
  licensing service (`https://licensing.rallly.co`, only when a licence is
  activated), the SMTP server the administrator configures, Docker Hub (image
  pull by the NAS daemon), optional OIDC/Google/Microsoft/Zoom/Webex
  integrations, and explicitly that PostHog, OpenAI moderation, S3 and Stripe
  are not configured/disabled.
- `config.ini.help` and `tosapp.json.help` now point to the public policy:
  <https://github.com/Moechz/rallly/blob/main/PRIVACY.md>.
- `NOTICE.md` records the real upstream licence (AGPL-3.0-or-later), the
  multi-arch image digests, the PostgreSQL 16.16 licence/digest, trademark
  attribution and the non-affiliation statement.

### Descriptions and repository (C6 / C9 / C10)

- **C9** — rewrote the English description and the 23-language file. The
  `zh-cn` / `zh-hk` sections described a habit tracker (beaverhabits) with
  streak statistics and a `beaverhabitsdocker` data path; all 23 sections now
  describe the delivered Rallly features. Removed the false claims "iCal export"
  (Rallly has no iCal export; it only attaches `.ics` invites to e-mails) and
  "only x86_64 is built because upstream has no arm64 image".
- **C6** — the description now matches runtime behaviour: e-mail invitations,
  sign-in codes and notifications require SMTP (not configured by default),
  image uploads require S3 (not configured), and polls/voting/comments work
  without either. `REGISTRATION_ENABLED=false` by default so an unconfigured
  instance does not advertise a sign-up whose code cannot be delivered.
- **C10** — rewrote `README.md` (features, two-service design, first start,
  repository layout, privacy, notices, build, verification, upgrade notes,
  data/uninstall, limitations) and added `NOTICE.md`. Removed the stale `probe`
  block copied from beaverhabits (`daya0576`, `start.sh prd`, port 8080) and the
  stale `entrypoint_file` path that pointed outside the repository.

### Usability and clean shutdown (F3 / F5 / F7 / S11)

- **F5** — the first start on an empty database now creates one `admin` account
  with a random 20-character password (scrypt, Better Auth credential format)
  and writes the credentials to `data/admin-credentials.txt` (mode `0600`).
  Without this, upstream's e-mailed one-time-code sign-in left the instance
  impossible to enter when no SMTP server is configured.
- **F7** — the public base URL is now learned from the first non-local `Host`
  header before the app starts (with a `data/public-url` override). Previously
  it was hard-coded to `http://localhost:8143`, so Better Auth rejected every
  login POST from the NAS address with `403 INVALID_ORIGIN` and absolute links
  pointed at the visitor's own machine. Also added a writable
  `cache/` volume for Next.js image/fetch caching.
- **F3** — the entrypoint now runs the Prisma migrations itself and then
  `exec`s `node apps/web/server.js`, so Node is PID 1 and receives SIGTERM;
  `init: true` adds a reaper. Previously a shell was PID 1 and never forwarded
  SIGTERM, so every stop ended in SIGKILL/zombie processes.
- **S11** — the generated secret and the credentials file are written with
  `umask 077` and mode `0600`; both containers run as `1000:1000` with no added
  capabilities.
- Healthcheck now probes the application's `/api/status` instead of `/`, with a
  180 s start period, so a slow first-run migration is not reported as a failed
  install. PostgreSQL is pinned to `16.16-alpine` (existing cluster preserved).

### Upstream (T1)

- Upgraded `lukevella/rallly:4.17.0` → `4.17.2` (multi-arch). 4.17.1 fixes the
  November Next.js 16.4.6 and Hono 4.13.16 advisories; 4.17.2 fixes an
  uploaded-image deletion issue in S3-backed instances
  (`GHSA-fc7p-4gcr-fr5f`). No configuration change is needed; the container
  applies the normal Prisma migrations at start.
- Added the missing **aarch64** package: upstream publishes both
  `linux/amd64` and `linux/arm64` manifests for the same tag.

## 4.17.0-1 — 2026-11-14

### Added
- First release. Rallly (`lukevella/rallly:4.17.0`, Docker Hub official image,
  unmodified) packaged as a TOS 7 Docker application, published on port 8143 and
  running as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/rallydocker/`.
