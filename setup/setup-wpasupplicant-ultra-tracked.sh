#!/bin/bash
set -e

# ===========================
# Configuration
# ===========================
INTERFACE="eth4"  # ← change this to match your WAN port, e.g. eth1, eth0, etc.

TEMPLATE="/lib/systemd/system/wpa_supplicant-wired@.service"
MARKER="/etc/wpa_supplicant/.wpa_unit_checksum"
OVERRIDE_DIR="/etc/systemd/system/wpa_supplicant-wired@${INTERFACE}.service.d"
OVERRIDE="${OVERRIDE_DIR}/override.conf"

# ===========================
# Function: apply systemd override
# ===========================
apply_override() {
  echo "🔍 Applying network-aware override for interface ${INTERFACE}…"
  mkdir -p "${OVERRIDE_DIR}"

  cat > "${OVERRIDE}" <<EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/usr/bin/test -e /etc/wpa_supplicant/wpa_supplicant-wired-${INTERFACE}.conf
ExecStart=/sbin/wpa_supplicant -i${INTERFACE} -Dwired -c/etc/wpa_supplicant/wpa_supplicant-wired-${INTERFACE}.conf
EOF

  # Store checksum of the original template to detect upstream updates
  sha256sum "${TEMPLATE}" | awk '{print $1}' > "${MARKER}"

  systemctl daemon-reload
  systemctl enable "wpa_supplicant-wired@${INTERFACE}"
  systemctl restart "wpa_supplicant-wired@${INTERFACE}"
  echo "✅ Override applied and checksum saved."
}

# ===========================
# Main: Only re-apply if template changed
# ===========================
current_sum="$(sha256sum "${TEMPLATE}" | awk '{print $1}')"
if [[ ! -f "${MARKER}" || "${current_sum}" != "$(cat "${MARKER}")" ]]; then
  apply_override
else
  echo "✅ Override already applied and up-to-date."
fi

# ===========================
# Setup persistent reinstall service
# ===========================
cat > /etc/systemd/system/reinstall-wpa.service <<EOF
[Unit]
Description=Reinstall wpa_supplicant after firmware update
After=network-online.target
Wants=network-online.target
AssertPathExistsGlob=/etc/wpa_supplicant/packages/wpasupplicant*arm64.deb
AssertPathExistsGlob=/etc/wpa_supplicant/packages/libpcsclite1*arm64.deb
ConditionPathExists=!/sbin/wpa_supplicant

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'dpkg -i /etc/wpa_supplicant/packages/*.deb'
ExecStart=/bin/bash -c 'systemctl start wpa_supplicant-wired@${INTERFACE}'
ExecStartPost=/bin/bash -c 'systemctl enable wpa_supplicant-wired@${INTERFACE}'
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable reinstall-wpa.service
echo "✅ Persistent reinstall service installed for interface ${INTERFACE}."
