#!/bin/sh
# ===========================================================================
# Rallly for TerraMaster TOS 7 - container entrypoint
# ===========================================================================
# The upstream image (lukevella/rallly) is used unmodified. This wrapper only
# prepares state that must not be baked into the public package:
#
#   1. a stable 32+ character application secret (generated on first start and
#      kept in the data volume) - Rallly refuses to boot without it;
#   2. the public base URL. Rallly builds absolute links and validates the
#      browser Origin against the configured base URL, and the NAS address is
#      only known to the browser. A short "learn the address" listener records
#      the first non-local Host header before the app starts;
#   3. an initial administrator account, so the instance is usable without an
#      external SMTP server (upstream's e-mail OTP sign-in needs one);
#   4. optional SMTP / sign-up settings from a user-editable file;
#   5. database migrations, then the app as PID 1 so SIGTERM stops it cleanly.
# ===========================================================================
set -u
set -e

DATA_DIR=/data
HOST_PORT="${TOS_HOST_PORT:-8143}"
LEARN_TIMEOUT="${LEARN_TIMEOUT:-90}"
STATE_FILE="$DATA_DIR/public-url.state"
OVERRIDE_FILE="$DATA_DIR/public-url"
CRED_FILE="$DATA_DIR/admin-credentials.txt"
SEED_MARKER="$DATA_DIR/.admin-seeded"

log() { echo "[rallydocker] $*" >&2; }

umask 077
mkdir -p "$DATA_DIR"

# ---------------------------------------------------------------------------
# 1. Application secret (SECRET_PASSWORD must be at least 32 characters)
# ---------------------------------------------------------------------------
SECRET_FILE="$DATA_DIR/app_secrets"
if [ ! -s "$SECRET_FILE" ]; then
  head -c 32 /dev/urandom | base64 | tr -d '\n/+=' | cut -c1-32 > "$SECRET_FILE.tmp"
  mv "$SECRET_FILE.tmp" "$SECRET_FILE"
fi
chmod 600 "$SECRET_FILE" 2>/dev/null || true
APP_SECRET="$(cat "$SECRET_FILE")"
if [ "${#APP_SECRET}" -lt 32 ]; then
  log "FATAL: $SECRET_FILE holds a secret shorter than 32 characters."
  log "Delete it and restart the container to generate a new one."
  exit 1
fi
export SECRET_PASSWORD="$APP_SECRET"
export NEXTAUTH_SECRET="$APP_SECRET"

# ---------------------------------------------------------------------------
# 2. Optional SMTP / registration overrides (user-editable, never overwritten)
#    File: /Volume1/DockerAppData/rallydocker/data/smtp.env
# ---------------------------------------------------------------------------
if [ -f "$DATA_DIR/smtp.env" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    key=${line%%=*}
    val=${line#*=}
    case "$key" in
      SMTP_HOST|SMTP_PORT|SMTP_USER|SMTP_PWD|SMTP_SECURE|SMTP_REJECT_UNAUTHORIZED|SMTP_TLS_SERVERNAME|EMAIL_PROVIDER|NOREPLY_EMAIL|NOREPLY_EMAIL_NAME|SUPPORT_EMAIL|ALLOWED_EMAILS|REGISTRATION_ENABLED|EMAIL_LOGIN_ENABLED|INITIAL_ADMIN_EMAIL) ;;
      *) continue ;;
    esac
    case "$val" in
      \"*\") val=${val#\"}; val=${val%\"} ;;
      \'*\') val=${val#\'}; val=${val%\'} ;;
    esac
    export "$key=$val"
  done < "$DATA_DIR/smtp.env"
fi
export APP_NAME="${APP_NAME:-Rallly}"

# ---------------------------------------------------------------------------
# 3. Public base URL:
#      user override  >  previously learned address  >  learn it now  >
#      http://localhost:<host port>
# ---------------------------------------------------------------------------
read_url() {
  [ -s "$1" ] || return 1
  while IFS= read -r candidate || [ -n "$candidate" ]; do
    case "$candidate" in ''|'#'*) continue ;; esac
    case "$candidate" in
      http://*|https://*) printf '%s' "${candidate%/}" ; return 0 ;;
    esac
  done < "$1"
  return 1
}

PUBLIC_URL=""
PUBLIC_URL="$(read_url "$OVERRIDE_FILE" 2>/dev/null || true)"
if [ -z "$PUBLIC_URL" ]; then
  PUBLIC_URL="$(read_url "$STATE_FILE" 2>/dev/null || true)"
fi

if [ -z "$PUBLIC_URL" ]; then
  log "learning the public address from the first browser request (max ${LEARN_TIMEOUT}s)"
  cat > /tmp/tos-learn-url.js <<'TOSLEARN'
const http = require("http");
const fs = require("fs");
const os = require("os");

const port = 3000;
const stateFile = process.env.LEARN_STATE;
const timeoutMs = Math.max(10, Number(process.env.LEARN_TIMEOUT || "90")) * 1000;
const own = new Set(["localhost", "127.0.0.1", "::1", "0.0.0.0"]);
for (const ifaces of Object.values(os.networkInterfaces() || {})) {
  for (const addr of ifaces || []) own.add(String(addr.address).toLowerCase());
}

const page = (headline, body) => `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="3">
<title>Rallly - starting</title>
<style>
body{font-family:system-ui,-apple-system,"Segoe UI",sans-serif;background:#0f172a;color:#e2e8f0;
display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}
.box{max-width:34rem;padding:2rem 2.5rem;background:#1e293b;border-radius:1rem;line-height:1.6}
h1{margin:0 0 .75rem;font-size:1.4rem}
p{margin:.4rem 0;color:#cbd5e1}
</style></head><body><div class="box">
<h1>${headline}</h1><p>${body}</p>
<p>This page refreshes itself every 3 seconds / 此页面每 3 秒自动刷新。</p>
</div></body></html>`;

const server = http.createServer((req, res) => {
  if (req.url === "/api/status") {
    res.writeHead(503, { "content-type": "application/json" });
    res.end('{"status":"starting"}');
    return;
  }
  const host = String(req.headers.host || "").trim();
  const hostname = host.replace(/:\d+$/, "").replace(/^\[|\]$/g, "").toLowerCase();
  const external = host && hostname && !own.has(hostname) && !hostname.startsWith("127.");
  if (external) {
    try {
      fs.writeFileSync(stateFile, "http://" + host + "\n", { mode: 0o600 });
      console.log("[rallydocker] learned public address " + host);
    } catch (error) {
      console.error("[rallydocker] could not save the public address: " + error.message);
    }
    res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    res.end(page("Rallly is starting", "Address recorded. Starting Rallly now, please wait..."));
    setTimeout(() => process.exit(0), 400);
    return;
  }
  res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  res.end(page("Rallly is starting", "Starting Rallly, please wait..."));
});

server.listen(port, "0.0.0.0", () => console.log("[rallydocker] learning listener on :" + port));
setTimeout(() => {
  try { server.close(); } catch (error) { /* already closed */ }
  process.exit(0);
}, timeoutMs);
TOSLEARN
  LEARN_STATE="$STATE_FILE" LEARN_TIMEOUT="$LEARN_TIMEOUT" node /tmp/tos-learn-url.js || true
  PUBLIC_URL="$(read_url "$STATE_FILE" 2>/dev/null || true)"
fi

if [ -z "$PUBLIC_URL" ]; then
  PUBLIC_URL="http://localhost:$HOST_PORT"
  log "no external request arrived; falling back to $PUBLIC_URL"
  log "open the app in a browser once, or write the address to $OVERRIDE_FILE"
fi

# The app must use exactly the address the browser uses: Next.js builds
# absolute links from NEXT_PUBLIC_BASE_URL and Better Auth rejects a POST whose
# Origin does not match it (403 INVALID_ORIGIN).
export NEXT_PUBLIC_BASE_URL="$PUBLIC_URL"
export APP_URL="$PUBLIC_URL"
export NEXTAUTH_URL="$PUBLIC_URL"
export AUTH_URL="$PUBLIC_URL"
log "public base URL: $PUBLIC_URL"

# ---------------------------------------------------------------------------
# 4. Wait for PostgreSQL, apply migrations
# ---------------------------------------------------------------------------
DB_HOST="${RALLYY_DB_HOST:-rallydocker-db}"
DB_PORT="${RALLYY_DB_PORT:-5432}"
log "waiting for the database at $DB_HOST:$DB_PORT"
tries=0
while ! node -e '
const net = require("net");
const socket = net.createConnection({ host: process.argv[1], port: Number(process.argv[2]) });
socket.setTimeout(2000);
socket.on("connect", () => { socket.end(); process.exit(0); });
socket.on("timeout", () => { socket.destroy(); process.exit(1); });
socket.on("error", () => process.exit(1));
' "$DB_HOST" "$DB_PORT" 2>/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -ge 90 ]; then
    log "FATAL: database $DB_HOST:$DB_PORT is not reachable"
    exit 1
  fi
  sleep 2
done

log "applying database migrations"
if ! npx --no-install prisma migrate deploy --config=./prisma.config.ts; then
  log "FATAL: database migrations failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# 5. Initial administrator (only on a fresh, empty database)
# ---------------------------------------------------------------------------
if [ ! -s "$SEED_MARKER" ] && [ ! -s "$CRED_FILE" ]; then
  ADMIN_EMAIL="${INITIAL_ADMIN_EMAIL:-admin@rallydocker.local}"
  ADMIN_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '\n/+=' | cut -c1-20)"
  ADMIN_HASH="$(node -e '
const crypto = require("crypto");
const password = process.argv[1];
const salt = crypto.randomBytes(16).toString("hex");
const key = crypto.scryptSync(password.normalize("NFKC"), salt, 64,
  { N: 16384, r: 16, p: 1, maxmem: 128 * 16384 * 16 * 2 });
process.stdout.write(salt + ":" + key.toString("hex"));
' "$ADMIN_PASSWORD")"
  ADMIN_ID="seed$(node -e 'process.stdout.write(require("crypto").randomBytes(10).toString("hex"))')"

  cat > /tmp/tos-seed-admin.sql <<SQL
DO \$tos\$
BEGIN
  IF EXISTS (SELECT 1 FROM users) THEN
    RAISE EXCEPTION 'TOS_SEED_SKIPPED_USERS_EXIST';
  END IF;
  INSERT INTO users (id, name, email, email_verified, role, created_at, updated_at)
  VALUES ('$ADMIN_ID', 'Administrator', '$ADMIN_EMAIL', true, 'admin', now(), now());
  INSERT INTO accounts (id, user_id, provider, provider_account_id, password, created_at, updated_at)
  VALUES ('acc$ADMIN_ID', '$ADMIN_ID', 'credential', '$ADMIN_ID', '$ADMIN_HASH', now(), now());
END
\$tos\$;
SQL

  if SEED_OUT="$(npx --no-install prisma db execute --file /tmp/tos-seed-admin.sql --config=./prisma.config.ts 2>&1)"; then
    {
      echo "Rallly administrator account (generated on first start)"
      echo "E-mail   $ADMIN_EMAIL"
      echo "Password $ADMIN_PASSWORD"
      echo ""
      echo "Sign in at http://<NAS-IP>:$HOST_PORT/login with the e-mail and password above."
      echo "Change the password under Settings -> Security, then delete this file."
    } > "$CRED_FILE"
    chmod 600 "$CRED_FILE"
    : > "$SEED_MARKER"
    log "created the initial administrator account ($ADMIN_EMAIL)"
    log "credentials: /Volume1/DockerAppData/rallydocker/data/admin-credentials.txt"
  else
    case "$SEED_OUT" in
      *TOS_SEED_SKIPPED_USERS_EXIST*)
        : > "$SEED_MARKER"
        log "existing accounts found; no initial administrator was created"
        ;;
      *)
        log "WARN: could not create the initial administrator account"
        log "$SEED_OUT"
        ;;
    esac
  fi
  rm -f /tmp/tos-seed-admin.sql
fi

# ---------------------------------------------------------------------------
# 6. Start Rallly as PID 1 (SIGTERM reaches Node, which shuts down gracefully)
# ---------------------------------------------------------------------------
log "starting Rallly"
exec node apps/web/server.js
