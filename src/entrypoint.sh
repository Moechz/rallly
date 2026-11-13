#!/bin/sh
# TOS wrapper: Rallly requires 32-character secrets and a valid support email
# at startup; hard-coding them in the compose file is forbidden. Generate a
# stable secret on first start, keep it in /data, and reuse it afterwards.
set -u
set -e
mkdir -p /data
F=/data/app_secrets
if [ ! -s "$F" ]; then
  head -c 32 /dev/urandom | base64 | tr -d '\n/+=' | cut -c1-32 > "$F"
fi
S="$(cat "$F")"
export SECRET_KEY="$S"
export NEXTAUTH_SECRET="$S"
export SECRET_PASSWORD="$S"
exec docker-entrypoint.sh ./docker-start.sh
