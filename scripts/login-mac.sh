#!/usr/bin/env bash
# =============================================================================
# Aula-huskeliste – MitID-login fra Mac (eller Linux)
#
# Logger ind på Aula med MitID fra din egen computer (Aula blokerer login fra
# servere) og flytter derefter login'et sikkert over på din server via SSH.
#
# Kør i Terminal:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/jesperbagger/aula-huskeliste/main/scripts/login-mac.sh)"
#
# Kør scriptet igen, hvis du en dag får mailen "Aula-automation: kræver handling".
# =============================================================================
set -euo pipefail

REPO="${AULA_HUSKELISTE_REPO:-jesperbagger/aula-huskeliste}"
SERVER_USER="${AULA_SERVER_USER:-ubuntu}"
BASE="https://github.com/$REPO/releases/latest/download"

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31mFEJL:\033[0m %s\n\n' "$*" >&2; exit 1; }
ask()  { local answer; printf '    %s' "$1" > /dev/tty; IFS= read -r answer < /dev/tty; printf '%s' "$answer"; }

printf '\n\033[1mAula-huskeliste – MitID-login\033[0m\n'
printf 'Kør dette hjemmefra (ikke via VPN eller arbejdsnetværk).\n'

# --- 1. Forudsætninger -------------------------------------------------------
info "1/5  Tjekker system"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) ASSET=aula-macos-arm64 ;;
  Darwin-x86_64) ASSET=aula-macos-x64 ;;
  Linux-x86_64) ASSET=aula-linux-x64 ;;
  Linux-aarch64 | Linux-arm64) ASSET=aula-linux-arm64 ;;
  *) die "Ukendt system: $(uname -s) $(uname -m)" ;;
esac
command -v ssh >/dev/null && command -v scp >/dev/null || die "ssh/scp mangler."
command -v curl >/dev/null || die "curl mangler."
if command -v shasum >/dev/null; then SHA="shasum -a 256"; else SHA="sha256sum"; fi
ok "Klar ($ASSET)"

# --- 2. Server og nøgle -------------------------------------------------------
info "2/5  Forbindelse til din server"
SERVER=$(ask "Serverens IP-adresse (fx 203.0.113.10): ")
SERVER="${SERVER//[[:space:]]/}"
[ -n "$SERVER" ] || die "Du skal indtaste serverens IP-adresse."

DEFAULT_KEY=$(ls -t "$HOME"/Downloads/ssh-key-*.key 2>/dev/null | head -n 1 || true)
if [ -n "$DEFAULT_KEY" ]; then
  KEY=$(ask "Sti til din SSH-nøgle [Enter = $DEFAULT_KEY]: ")
  KEY="${KEY:-$DEFAULT_KEY}"
else
  KEY=$(ask "Sti til din SSH-nøgle: ")
fi
# Rens stien: fjern mellemrum og anførselstegn i enderne og "\ " fra træk-og-slip i Finder.
KEY=$(printf '%s' "$KEY" | sed -e 's/^[[:space:]"'"'"']*//' -e 's/[[:space:]"'"'"']*$//' -e 's/\\ / /g')
# shellcheck disable=SC2088  # vi matcher bevidst en bogstavelig "~/" fra brugerens input
case "$KEY" in "~/"*) KEY="$HOME/${KEY#\~/}" ;; esac
[ -f "$KEY" ] || die "Kan ikke finde SSH-nøglen: $KEY"
chmod 600 "$KEY"

SSH_OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
ssh "${SSH_OPTS[@]}" "$SERVER_USER@$SERVER" 'command -v aula-import-login >/dev/null' < /dev/null \
  || die "Kunne ikke forbinde til serveren, eller installationsscriptet er ikke kørt endnu (trin 2)."
ok "Forbundet til $SERVER"

# --- 3. Hent aula-programmet ----------------------------------------------
info "3/5  Henter aula-programmet"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
curl -fsSL --retry 3 -o "$WORK/aula" "$BASE/$ASSET" || die "Kunne ikke hente $ASSET."
curl -fsSL --retry 3 -o "$WORK/SHA256SUMS" "$BASE/SHA256SUMS" || die "Kunne ikke hente SHA256SUMS."
expected=$(awk -v f="$ASSET" '{name=$2; sub(/^\*/, "", name)} name == f {print $1}' "$WORK/SHA256SUMS")
actual=$($SHA "$WORK/aula" | awk '{print $1}')
[ -n "$expected" ] && [ "$expected" = "$actual" ] || die "Kontrolsummen passer ikke. Prøv igen."
chmod +x "$WORK/aula"
ok "aula er hentet og kontrolleret"

# --- 4. MitID-login -----------------------------------------------------------
info "4/5  Log ind med MitID"
printf '    Skriv dit MitID-brugernavn, når der spørges om "MitID username".\n'
printf '    Derefter vises en QR-kode. Scan den med MitID-appen og godkend.\n'
export AULA_MCP_DIR="$WORK/data" AULA_MCP_NO_KEYCHAIN=1
"$WORK/aula" login < /dev/tty \
  || die "Login mislykkedes. Står der 'bot protection', så er du ikke på dit hjemmenetværk."
[ -f "$WORK/data/tokens.json" ] && [ -f "$WORK/data/.key" ] || die "Login gav ingen tokens. Prøv igen."
ok "Logget ind"

# --- 5. Flyt login'et til serveren --------------------------------------------
info "5/5  Flytter login'et til serveren"
ssh "${SSH_OPTS[@]}" "$SERVER_USER@$SERVER" 'mkdir -p ~/aula-login && chmod 700 ~/aula-login' < /dev/null
scp "${SSH_OPTS[@]}" "$WORK/data/tokens.json" "$WORK/data/.key" "$SERVER_USER@$SERVER:aula-login/" < /dev/null \
  || die "Kunne ikke kopiere login'et til serveren."
ssh "${SSH_OPTS[@]}" "$SERVER_USER@$SERVER" 'sudo aula-import-login ~/aula-login' < /dev/null \
  || die "Serveren kunne ikke importere login'et."
ok "Serveren er logget ind på Aula"

printf '\n\033[32mFærdigt.\033[0m Login'"'"'et ligger nu kun på din server (kopien på denne computer er slettet).\n'
printf 'Næste skridt: tilføj connectoren i Claude (trin 4 i vejledningen).\n\n'
