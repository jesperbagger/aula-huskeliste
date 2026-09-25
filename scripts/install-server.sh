#!/usr/bin/env bash
# =============================================================================
# Aula-huskeliste – serverinstallation
#
# Installerer aula-mcp (forbindelsen til Aula) og Caddy (HTTPS + adgangsnøgle)
# på en Ubuntu-server, fx en gratis maskine hos Oracle Cloud.
#
# Kør på serveren:
#   curl -fsSL https://raw.githubusercontent.com/jesperbagger/aula-huskeliste/main/scripts/install-server.sh | bash
#
# Scriptet kan køres igen uden problemer. Det opdaterer aula-mcp til nyeste
# udgivelse og beholder din connector-URL og nøgle.
#
# Valgfrie indstillinger (sættes foran "bash"):
#   AULA_DOMAIN=aula.mitdomæne.dk   Brug dit eget domæne i stedet for <ip>.nip.io
#   AULA_HUSKELISTE_VERSION=v1.0.0  Installer en bestemt udgivelse
# =============================================================================
set -euo pipefail

REPO="${AULA_HUSKELISTE_REPO:-jesperbagger/aula-huskeliste}"
REL_VERSION="${AULA_HUSKELISTE_VERSION:-latest}"
DATA_DIR=/var/lib/aula-mcp
CONF_DIR=/etc/aula-huskeliste
SERVICE_USER=aula
GUIDE="https://github.com/$REPO#readme"

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31mFEJL:\033[0m %s\n\n' "$*" >&2; exit 1; }

# --- Forudsætninger -----------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
if [ -n "$SUDO" ] && ! command -v sudo >/dev/null 2>&1; then
  die "Kommandoen sudo mangler. Kør scriptet som root eller installer sudo."
fi

# /etc/os-release læses i en subshell, så dens variabler (bl.a. VERSION) ikke overskriver scriptets egne.
OS_ID=$( { . /etc/os-release && echo "${ID:-}"; } 2>/dev/null || true)
OS_NAME=$( { . /etc/os-release && echo "${PRETTY_NAME:-}"; } 2>/dev/null || true)
[ "$OS_ID" = "ubuntu" ] || die "Scriptet er lavet til Ubuntu (fandt: ${OS_NAME:-ukendt system})."

case "$(uname -m)" in
  x86_64) ARCH=x64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) die "Ukendt CPU-type: $(uname -m). Kun x86_64 og ARM64 understøttes." ;;
esac

APT_OPTS=(-q -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
apt_update() {
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" update >/dev/null </dev/null
}
apt_install() {
  $SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
    apt-get "${APT_OPTS[@]}" install -y "$@" >/dev/null </dev/null
}

printf '\n\033[1mAula-huskeliste – serverinstallation\033[0m\n'
printf 'Udgivelse: %s  ·  Arkitektur: linux-%s\n' "$REL_VERSION" "$ARCH"

# --- 1. Systempakker ------------------------------------------------------------
info "1/7  Installerer systempakker"
# En helt ny maskine kører ofte automatiske opdateringer de første minutter.
if command -v cloud-init >/dev/null 2>&1; then
  printf '    Venter på, at maskinens første opstart bliver færdig …\n'
  $SUDO cloud-init status --wait >/dev/null 2>&1 || true
fi
apt_update
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | $SUDO debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | $SUDO debconf-set-selections
apt_install curl ca-certificates gnupg apt-transport-https iptables-persistent
ok "Systempakker er på plads"

# --- 2. Swap (gratis maskiner har kun 1 GB RAM) -------------------------------
info "2/7  Tjekker hukommelse"
mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ -z "$(swapon --show --noheadings 2>/dev/null)" ] && [ "$mem_kb" -lt 3000000 ]; then
  if [ ! -f /swapfile ]; then
    $SUDO fallocate -l 2G /swapfile
    $SUDO chmod 600 /swapfile
    $SUDO mkswap /swapfile >/dev/null
  fi
  $SUDO swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | $SUDO tee -a /etc/fstab >/dev/null
  ok "2 GB swap er slået til"
else
  ok "Hukommelsen er i orden"
fi

# --- 3. aula-mcp ----------------------------------------------------------------
info "3/7  Henter aula-mcp"
if [ "$REL_VERSION" = "latest" ]; then
  BASE="https://github.com/$REPO/releases/latest/download"
else
  BASE="https://github.com/$REPO/releases/download/$REL_VERSION"
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

download() {
  curl -fsSL --retry 3 -o "$TMP/$1" "$BASE/$1" \
    || die "Kunne ikke hente $1 fra $BASE. Er der udgivet en release i github.com/$REPO?"
}
download SHA256SUMS
download "aula-mcp-linux-$ARCH"
download "aula-linux-$ARCH"
(
  cd "$TMP"
  grep -E " \*?(aula-mcp-linux-$ARCH|aula-linux-$ARCH)\$" SHA256SUMS > checks
  [ "$(wc -l < checks)" -eq 2 ] && sha256sum -c --quiet checks
) || die "Kontrolsummen passer ikke. Filerne kan være ødelagte, så prøv igen."

$SUDO install -m 755 "$TMP/aula-mcp-linux-$ARCH" /usr/local/bin/aula-mcp
$SUDO install -m 755 "$TMP/aula-linux-$ARCH" /usr/local/bin/aula
ok "aula-mcp er installeret i /usr/local/bin"

# --- 4. Tjeneste (systemd) -----------------------------------------------------
info "4/7  Opsætter aula-mcp som tjeneste"
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
  $SUDO useradd --system --home-dir "$DATA_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
fi
$SUDO install -d -m 700 -o "$SERVICE_USER" -g "$SERVICE_USER" "$DATA_DIR"

$SUDO tee /etc/systemd/system/aula-mcp.service >/dev/null <<EOF
[Unit]
Description=aula-mcp (Aula-huskeliste)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
Environment=HOME=$DATA_DIR
Environment=AULA_MCP_DIR=$DATA_DIR
Environment=AULA_MCP_HOST=127.0.0.1
Environment=AULA_MCP_PORT=7878
ExecStart=/usr/local/bin/aula-mcp
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

# Hjælpekommandoer
$SUDO tee /usr/local/bin/aula-import-login >/dev/null <<'EOF'
#!/usr/bin/env bash
# Importerer et Aula-login (tokens.json + .key) og genstarter aula-mcp.
set -euo pipefail
DIR="${1:?Brug: aula-import-login <mappe med tokens.json og .key>}"
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
if [ ! -f "$DIR/tokens.json" ] || [ ! -f "$DIR/.key" ]; then
  echo "Mangler tokens.json eller .key i $DIR" >&2
  exit 1
fi
WORK=$(mktemp -d)
cp "$DIR/tokens.json" "$DIR/.key" "$WORK/"
chown -R aula:aula "$WORK"
chmod 700 "$WORK"
sudo -u aula env HOME=/var/lib/aula-mcp AULA_MCP_DIR=/var/lib/aula-mcp AULA_MCP_NO_KEYCHAIN=1 \
  /usr/local/bin/aula tokens import "$WORK"
rm -rf "$WORK"
rm -f "$DIR/tokens.json" "$DIR/.key"
rmdir "$DIR" 2>/dev/null || true
systemctl restart aula-mcp
sleep 2
echo
sudo -u aula env HOME=/var/lib/aula-mcp AULA_MCP_DIR=/var/lib/aula-mcp /usr/local/bin/aula status || true
EOF

$SUDO tee /usr/local/bin/aula-status >/dev/null <<'EOF'
#!/usr/bin/env bash
# Viser status for Aula-huskelistens server.
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
echo "Tjenester:"
for s in aula-mcp caddy; do printf '  %-9s %s\n' "$s" "$(systemctl is-active "$s")"; done
echo
echo "Aula-login:"
sudo -u aula env HOME=/var/lib/aula-mcp AULA_MCP_DIR=/var/lib/aula-mcp /usr/local/bin/aula status 2>&1 | sed 's/^/  /'
echo
echo "Se connector-oplysningerne med: aula-connector"
EOF

$SUDO tee /usr/local/bin/aula-connector >/dev/null <<'EOF'
#!/usr/bin/env bash
# Viser connector-URL og nøgle til Claude. Del dem aldrig med andre.
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
f=/etc/aula-huskeliste/connector.env
[ -f "$f" ] || { echo "Ingen connector er sat op endnu. Kør installationsscriptet." >&2; exit 1; }
domain=$(sed -n 's/^DOMAIN=//p' "$f"); secret=$(sed -n 's/^SECRET=//p' "$f"); key=$(sed -n 's/^KEY=//p' "$f")
echo
echo "  Connector-URL:  https://$domain/$secret/mcp"
echo "  Header-navn:    X-API-Key"
echo "  Header-værdi:   $key"
echo
echo "  (Vælger du i stedet 'Authorization' som header, er værdien: Bearer $key)"
echo
EOF
$SUDO chmod 755 /usr/local/bin/aula-import-login /usr/local/bin/aula-status /usr/local/bin/aula-connector

$SUDO systemctl daemon-reload
$SUDO systemctl enable aula-mcp >/dev/null 2>&1
$SUDO systemctl restart aula-mcp
started=""
for _ in $(seq 1 30); do
  if curl -fsS --max-time 3 http://127.0.0.1:7878/healthz >/dev/null 2>&1; then started=1; break; fi
  sleep 1
done
[ -n "$started" ] || die "aula-mcp startede ikke. Se loggen med: sudo journalctl -u aula-mcp -n 50"
ok "aula-mcp kører"

# --- 5. Firewall på selve maskinen ----------------------------------------------
info "5/7  Åbner port 80 og 443 i serverens firewall"
for port in 80 443; do
  if ! $SUDO iptables -C INPUT -p tcp -m state --state NEW --dport "$port" -j ACCEPT 2>/dev/null; then
    reject_line=$($SUDO iptables -L INPUT --line-numbers -n | awk '$2 == "REJECT" {print $1; exit}')
    if [ -n "$reject_line" ]; then
      $SUDO iptables -I INPUT "$reject_line" -p tcp -m state --state NEW --dport "$port" -j ACCEPT
    else
      $SUDO iptables -A INPUT -p tcp -m state --state NEW --dport "$port" -j ACCEPT
    fi
  fi
done
$SUDO netfilter-persistent save >/dev/null 2>&1 || true
ok "Port 80 og 443 er åbne (reglerne overlever genstart)"

# --- 6. Caddy (HTTPS + adgangskontrol) ---------------------------------------
info "6/7  Opsætter HTTPS og adgangsnøgle (Caddy)"
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | $SUDO gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | $SUDO tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  apt_update
  apt_install caddy
fi

$SUDO install -d -m 700 "$CONF_DIR"
saved() { $SUDO sed -n "s/^$1=//p" "$CONF_DIR/connector.env" 2>/dev/null || true; }
SECRET=$(saved SECRET)
KEY=$(saved KEY)
DOMAIN="${AULA_DOMAIN:-$(saved DOMAIN)}"
[ -n "$SECRET" ] || SECRET=$(openssl rand -hex 24)
[ -n "$KEY" ] || KEY=$(openssl rand -hex 32)
if [ -z "$DOMAIN" ]; then
  IP=$(curl -4 -fsS --max-time 10 https://api.ipify.org || true)
  if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "Kunne ikke finde serverens offentlige IP-adresse. Har maskinen en offentlig IPv4-adresse? Se $GUIDE"
  fi
  DOMAIN="$IP.nip.io"
fi

printf 'DOMAIN=%s\nSECRET=%s\nKEY=%s\n' "$DOMAIN" "$SECRET" "$KEY" | $SUDO tee "$CONF_DIR/connector.env" >/dev/null
$SUDO chmod 600 "$CONF_DIR/connector.env"

$SUDO tee /etc/caddy/Caddyfile >/dev/null <<EOF
# Genereret af Aula-huskeliste. Kun kald med den hemmelige sti OG den rigtige
# nøgle (X-API-Key eller Authorization: Bearer) når frem til aula-mcp.
$DOMAIN {
	@apikey {
		path /$SECRET/*
		header X-API-Key $KEY
	}
	@bearer {
		path /$SECRET/*
		header Authorization *$KEY
	}
	handle @apikey {
		uri strip_prefix /$SECRET
		reverse_proxy 127.0.0.1:7878 {
			header_up -X-API-Key
		}
	}
	handle @bearer {
		uri strip_prefix /$SECRET
		reverse_proxy 127.0.0.1:7878 {
			header_up -Authorization
		}
	}
	handle {
		respond 404
	}
}
EOF
$SUDO chown root:caddy /etc/caddy/Caddyfile
$SUDO chmod 640 /etc/caddy/Caddyfile
$SUDO caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 \
  || die "Caddy-konfigurationen er ugyldig. Se: sudo caddy validate --config /etc/caddy/Caddyfile"
$SUDO systemctl enable caddy >/dev/null 2>&1
$SUDO systemctl reload caddy 2>/dev/null || $SUDO systemctl restart caddy
ok "Caddy kører på $DOMAIN"

# --- 7. Test udefra -----------------------------------------------------------
info "7/7  Tester forbindelsen (HTTPS-certifikatet kan tage op til et minut)"
reachable=""
# Nøglen lægges i en fil, så den ikke står i proceslisten.
printf 'X-API-Key: %s\n' "$KEY" > "$TMP/header"
chmod 600 "$TMP/header"
for _ in $(seq 1 30); do
  if curl -fsS --max-time 5 -H @"$TMP/header" "https://$DOMAIN/$SECRET/healthz" >/dev/null 2>&1; then
    reachable=1
    break
  fi
  sleep 3
done

if [ -n "$reachable" ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://$DOMAIN/$SECRET/healthz" || true)
  ok "Serveren svarer via HTTPS"
  if [ "$code" = "404" ]; then ok "Kald uden nøgle bliver afvist"; else warn "Kald uden nøgle gav $code (forventet 404)"; fi
else
  warn "Serveren kunne ikke nås via https://$DOMAIN endnu."
  warn "Det skyldes næsten altid, at port 80 og 443 ikke er åbnet i Oracle-konsollen"
  warn "(Security List). Se trin 1 i vejledningen, og kør derefter scriptet igen."
fi

cat <<EOF

────────────────────────────────────────────────────────────────────────
  Installationen er færdig.

  Gem disse oplysninger et sikkert sted (fx din password manager).
  Du skal bruge dem, når du tilføjer connectoren i Claude:

    Connector-URL:  https://$DOMAIN/$SECRET/mcp
    Header-navn:    X-API-Key
    Header-værdi:   $KEY

  Del dem aldrig med andre. De giver adgang til dine Aula-data.
  Du kan altid se dem igen med kommandoen:  aula-connector

  Næste skridt: log ind med MitID fra din egen computer
  (trin 3 i vejledningen: $GUIDE).
────────────────────────────────────────────────────────────────────────
EOF
