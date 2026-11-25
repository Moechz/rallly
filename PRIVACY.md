# Privacy policy — Rallly for TerraMaster TOS (`rallydocker`)

**Last updated:** 2026-11-25
**Applies to:** Rallly package version `4.17.2-1` and later, published by Moechz
in the TerraMaster App Center.
**Upstream project:** <https://github.com/lukevella/rallly> (Rallly 4.17.2)
**Contact / data requests:** <https://github.com/Moechz/rallly/issues>

This policy explains what the Rallly application package stores, where it is
stored, how long it is kept, when anything leaves your NAS, which third-party
services are contacted, and how you and the users of your instance can access,
correct or delete that data.

Rallly is a **self-hosted** application. It runs entirely on your TerraMaster
NAS in two Docker containers (Rallly and PostgreSQL). The packager does not
operate a server for this app, does not receive your polls, participants,
e-mail addresses or logs, and has no way to access your NAS. The "data
controller" for everything you put into Rallly is **you**, the owner or
administrator of the NAS. Rallly's own cloud service (rallly.co) is a separate
product and its privacy policy does not apply to this self-hosted instance.

---

## 1. What the application stores

### 1.1 PostgreSQL database (system of record)

All structured data lives in the PostgreSQL cluster under
`/Volume1/DockerAppData/rallydocker/db/pgdata` (container path
`/var/lib/postgresql/data/pgdata`).

| Data | Table(s) | Why |
|---|---|---|
| **User accounts** — display name, **e-mail address** (case-insensitive), **scrypt password hash**, optional avatar URL, role (`admin`/`user`), locale, time zone, week start, time format, last login method, last-seen time, banned/deleted flags | `users` | Sign-in and attribution. The initial administrator account is created on first start (see 1.4). |
| **Credential account** — provider `credential`, the scrypt password hash, timestamps | `accounts` | Password sign-in (Better Auth). |
| **Sessions** — session id, token, **IP address**, **user agent**, expiry, created/updated time, optional impersonation reference | `sessions` | Keep users signed in and let them review/revoke sessions. |
| **Polls** — title, description, location, time zone, kind (date/time), status, deadline, conferencing metadata, privacy flags (hide participants/scores, disable comments, require participant e-mail), owner id, space id, creation/update time | `polls` | The poll itself. |
| **Poll options** — start time, duration, order | `options` | The dates/times participants vote on. |
| **Participants** — display name, **optional e-mail address**, optional note, access token, locale, time zone, guest-account reference | `participants` | Identify who responded; e-mail is only collected when the poll owner enables it or the participant chooses to add it. |
| **Votes** — participant, option, vote type (`yes` / `maybe` / `no`) | `votes` | The availability grid. |
| **Comments** — text, author name, author account, poll, timestamps, deletion state | `comments` | Discussions on a poll (comments are disabled by default and must be enabled per poll). |
| **Poll activity / invites** — activity events, invitation e-mail addresses, inviter | `poll_activities`, `poll_invites` | History and e-mail invitations. |
| **Spaces and members** — space name, image URL, owner, tier/type, memberships, roles, last selected space | `spaces`, `space_members`, `space_member_invites` | The workspace that groups polls; invitations store the invited **e-mail address**. |
| **Scheduled events, event types, sheets** — event details, invitees, availability sheets | `scheduled_events`, `scheduled_event_invites`, `event_types`, `sheets` | Optional scheduling/booking features. |
| **Calendar and conferencing connections** — provider, provider account id, **connection e-mail**, display name, OAuth **access/refresh tokens and scopes**, calendar list | `credentials`, `calendar_connections`, `provider_calendars`, `conferencing_connections` | Only populated if an administrator configures Google/Microsoft/Zoom/Webex integrations and a user connects an account. Empty by default. |
| **Notifications and e-mail queue** — notification preferences; queued e-mail kind, status, attempts, send-after, last error, recipient user | `user_notification_preferences`, `queued_emails` | Deliver notifications. The queue stores no message body; the body is rendered when it is sent. |
| **Licence** — licence key, licensee name/**, e-mail**, seats, type, issue/expiry dates, validation records (IP address, user agent, fingerprint) | `licenses`, `license_validations`, `instance_license` | Only populated if an administrator activates a commercial Rallly licence. Empty by default. |
| **Instance settings** — a random **instance UUID** (`gen_random_uuid()`), branding (app name, colours, logo URLs), registration toggle, footer links | `instance_settings` | Instance identity and branding. |
| **Billing/subscription records** | `subscriptions`, `payment_methods`, `nonprofit_applications` | Only meaningful on the hosted Rallly cloud; on a self-hosted instance these tables stay empty unless the (unconfigured) Stripe integration is used. |

The package disables registration by default (`REGISTRATION_ENABLED=false`),
does not configure S3 object storage, and does not configure any OAuth/SSO
provider, so the corresponding tables stay empty until an administrator opts in
(see §4 and §5).

### 1.2 Files created by the package itself

Everything below is inside the application data folder and is created on first
start; none of it is shipped in the public package:

| File | Content | Permission |
|---|---|---|
| `/Volume1/DockerAppData/rallydocker/data/app_secrets` | 32 random characters (`SECRET_PASSWORD`; signs sessions and upload tokens) | `0600` |
| `/Volume1/DockerAppData/rallydocker/data/public-url.state` | The public base URL learned from the first browser request | `0600` |
| `/Volume1/DockerAppData/rallydocker/data/public-url` | Optional administrator override of the public URL (never overwritten) | administrator-created |
| `/Volume1/DockerAppData/rallydocker/data/admin-credentials.txt` | E-mail address and random password of the initial administrator account | `0600` |
| `/Volume1/DockerAppData/rallydocker/data/smtp.env` | Optional SMTP settings (host, port, user, **password**) written by the administrator | administrator-created |
| `/Volume1/DockerAppData/rallydocker/data/.admin-seeded` | Empty marker: the initial account was created | `0600` |
| `/Volume1/DockerAppData/rallydocker/cache/` | Next.js fetch cache and optimised images (derived data, safe to delete) | app user |

There are **no uploads on disk**: Rallly stores profile pictures, space icons
and instance logos in S3-compatible object storage, and this package does not
configure S3. The corresponding upload buttons return an error instead of
writing files.

### 1.3 Logs

Both containers log to **stdout/stderr**, which Docker stores as the container
log (`docker logs rallydocker`, `docker logs rallydocker-db`). Those logs can
contain:

- HTTP request metadata: client IP, timestamp, method, path, status, user agent;
- application errors and stack traces that may quote a poll title, an e-mail
  address or a participant name;
- migration output and the public URL learned at start-up;
- **the one-time e-mail sign-in code is never logged** by the package; it is
  only sent to the SMTP server when one is configured.

The package does not write application log files into the data directories.
PostgreSQL logs connection and statement errors to its own stdout. Docker log
rotation is controlled by the NAS Docker configuration.

### 1.4 The initial administrator account

On a **fresh, empty database** the entrypoint creates one account
(`admin@rallydocker.local`) with a random 20-character password and the `admin`
role, and writes the credentials to `admin-credentials.txt` (mode `0600`). This
exists so the instance is usable without an external SMTP server: upstream's
e-mail one-time-code sign-in needs one. The file is readable by the NAS
administrator only; delete it after changing the password under **Settings →
Security**.

On an existing installation (database already contains users) no account is
created and the file is not written.

### 1.5 Browser storage and cookies

| Item | Where | Purpose / lifetime |
|---|---|---|
| Better Auth session cookie (`better-auth.session_token`) | Browser cookie, `HttpOnly`, `SameSite=Lax`, host-only | Keeps the user signed in; expires with the session (60 days by default) or on sign-out. |
| Locale cookie | Browser cookie | Remembers the interface language. |
| Login verification cookie | Browser cookie, short-lived | Carries the e-mail verification state between the login and code pages. |
| Last-login-method cookie | Browser cookie | Shows "last used" next to the sign-in method. |
| Theme / UI preferences | Browser `localStorage` | Convenience only; stays in the browser. |

The package sets no advertising, analytics or tracking cookies.

---

## 2. How long data is kept

| Data | Retention |
|---|---|
| Accounts, polls, options, participants, votes, comments, spaces, invitations | Until the owner deletes them, the account is deleted, or the data folder is removed. There is no automatic expiry. |
| Sessions | Until sign-out, revocation or expiry (60 days); expired rows are removed by upstream housekeeping. |
| Queued e-mails | Until sent, abandoned after repeated failures, or purged by upstream housekeeping. |
| Calendar/conferencing OAuth tokens | Until the user disconnects the integration or deletes the account. |
| Container logs | According to the Docker log driver/rotation configured on the NAS (not by this package). |
| `app_secrets`, `admin-credentials.txt` | Until you delete them; the secret must stay for existing sessions to remain valid. |
| `public-url.state`, cache | Until you delete them; both are safe to remove (the address is re-learned, the cache is rebuilt). |
| Database backups you create | Until you delete the backup files. |

Deleting the app from the App Center **keeps** `/Volume1/DockerAppData/rallydocker/`
unless you also choose to delete the data. Removing that folder is irreversible.

---

## 3. When data leaves the NAS (third-party endpoints)

The application itself only makes outbound connections in the situations listed
below. All of them are optional or triggered by an administrator, except the
update check.

| # | Endpoint | When | Data sent | Destination / region |
|---|---|---|---|---|
| 1 | `https://api.rallly.co/api/updates` | Version/update check from the administration area (the home tile and the control panel), cached for 1 hour | The running Rallly version and the random **instance UUID** from `instance_settings` — no e-mail address, poll content, IP address or account data | Rallly project's hosted service, outside your NAS (operated in the United States) |
| 2 | `https://licensing.rallly.co/api/licensing/v1/licenses/actions/validate-key` | Only when an administrator enters, refreshes or removes a commercial licence key | The licence key, optional device fingerprint, **IP address** and **user agent** of the administrator | Rallly project's licensing service, outside your NAS (United States) |
| 3 | Your SMTP server (`SMTP_HOST`/`SMTP_PORT` in `data/smtp.env`) | Only after an administrator configures SMTP; used for sign-in codes, invitations, comment/response notifications and password resets | Recipient e-mail address and name, poll title/link, invitation text, one-time code or reset link | The SMTP server **you** configure (your provider, your region) |
| 4 | `docker.io` / `registry-1.docker.io` (Docker Hub) | When the NAS Docker daemon installs or updates the app | Image name and tag only (`lukevella/rallly:4.17.2`, `postgres:16.16-alpine`); no application data | Docker Hub (Docker, Inc., United States) — pulled by your NAS, not by the app |
| 5 | Your OIDC provider (`OIDC_DISCOVERY_URL`) | Only if an administrator configures single sign-on | Standard OpenID Connect claims (e-mail, name, picture) and the authorisation code | The provider **you** configure |
| 6 | Google (`accounts.google.com`, `www.googleapis.com`, `oauth2.googleapis.com`) | Only if Google sign-in or Google Calendar/Meet is configured and a user connects it | OAuth scopes for e-mail/profile and, if enabled, calendar events | Google LLC (United States) |
| 7 | Microsoft (`login.microsoftonline.com`, `graph.microsoft.com`) | Only if Microsoft sign-in or Microsoft 365/Teams is configured and a user connects it | OAuth scopes for e-mail/profile and calendar/Teams data | Microsoft Corporation (United States/EEA) |
| 8 | Zoom (`zoom.us`, `api.zoom.us`) / Webex (`webexapis.com`) | Only if the corresponding conferencing integration is configured and a user connects it | OAuth scopes and meeting metadata | Zoom Communications, Inc. / Cisco Systems, Inc. (United States) |
| 9 | `https://github.com/...` links in the UI and documentation | When a user clicks a link | Nothing until the browser opens the link; then standard web request metadata | GitHub, Inc. (United States) |

**Not contacted by this package** (no configuration shipped):

- **PostHog** product analytics — disabled; no `NEXT_PUBLIC_POSTHOG_API_KEY` is set.
- **OpenAI** content moderation — disabled; no `OPENAI_API_KEY` is set.
- **AWS S3 / any object storage** — not configured; image uploads are unavailable.
- **Stripe** billing — not configured; no payment data is processed.
- **Next.js telemetry** — disabled in the upstream image (`NEXT_TELEMETRY_DISABLED=1`).

The update check (#1) is the only call that can happen without an administrator
doing anything explicit. It sends no personal data and can be blocked by
firewalling `api.rallly.co`; the app keeps working (it only loses the
"update available" hint).

---

## 4. User rights: access, correction and deletion

| Right | How |
|---|---|
| **Access** | Every signed-in user can see their profile, sessions, notification preferences, polls, votes and comments in the web UI. The instance administrator can inspect users, spaces, polls and licences in the Control Panel (`/control-panel`). Database-level access is available to the NAS administrator, who owns the data folder. |
| **Correction** | Users change their name, e-mail address, locale, time zone and password under **Settings → Profile / Security**. Poll owners edit or close their polls; participants can change their responses until the poll is closed. |
| **Deletion of an account** | **Settings → Profile → Delete account** (upstream feature). An administrator can also delete any user from the Control Panel → Users. Deleting an account cascades to that user's sessions, polls, participations, votes and comments as implemented upstream. |
| **Deletion of individual content** | Poll owners delete polls, comments and participants in the poll UI; space owners manage members and spaces. |
| **Deletion of everything** | Stop the app in the App Center, then delete `/Volume1/DockerAppData/rallydocker/`. This removes the database, the generated secret, the credentials file and the cache. |
| **Data export** | Rallly does not provide a bulk export endpoint. The NAS administrator can export the PostgreSQL database with `pg_dump` (from the `rallydocker-db` container) or copy the data folder. |
| **Questions / complaints** | Open an issue at <https://github.com/Moechz/rallly/issues>; the packager responds there. The upstream project is at <https://github.com/lukevella/rallly>. |

---

## 5. Security measures

- **Non-root containers.** Both services run as `1000:1000` with no added
  capabilities, no `privileged`, no host network and no Docker socket.
- **Secrets are generated, never shipped.** The application secret is 32 random
  characters, created on first start, stored with mode `0600`; the initial
  administrator password is random, shown once in a `0600` file.
- **Password hashing.** Better Auth stores passwords as scrypt hashes
  (`N=16384, r=16, p=1`, 64-byte key, random 16-byte salt); passwords are never
  stored or logged in clear text.
- **Session cookies** are `HttpOnly`, `SameSite=Lax`, host-only, and signed with
  the application secret.
- **No telemetry.** Next.js telemetry, PostHog and OpenAI moderation are off.
- **Database isolation.** PostgreSQL is not published to the host; it is only
  reachable on the private Compose network with `trust` authentication inside
  that network. The data directory is owned by the application user.
- **Plain HTTP on the LAN.** The App Center opens `http://<NAS-IP>:8143`. Put a
  TLS-terminating reverse proxy in front before exposing the app to the
  internet; otherwise cookies, poll content and SMTP credentials typed into the
  UI are visible on the network.
- **SMTP credentials** are stored in clear text in `data/smtp.env` (mode `0600`
  when created via the documented procedure). Use a dedicated app password and
  restrict access to the data folder.
- **No automatic update.** The app does not update itself; install App Center
  updates yourself and back up first.

---

## 6. Changes to this policy

This policy is versioned with the package in the public repository
(<https://github.com/Moechz/rallly>); the changelog records every change. The
"Last updated" date above refers to the most recent revision.
