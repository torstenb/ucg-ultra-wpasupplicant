#!/bin/bash

# Marker file to store checksum of original systemd template
MARKER=/etc/wpa_supplicant/.wpa_unit_checksum
TEMPLATE=/lib/systemd/system/wpa_supplicant-wired@.service
OVERRIDE_DIR=/etc/systemd/system/wpa_supplicant-wired@eth4.service.d
OVERRIDE=$OVERRIDE_DIR/override.conf

# Function to apply override and store checksum
apply_override() {
    mkdir -p "$OVERRIDE_DIR"

    cat <<EOF > "$OVERRIDE"
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/usr/bin/test -e /etc/wpa_supplicant/wpa_supplicant-wired-eth4.conf
ExecStart=/sbin/wpa_supplicant -ieth4 -Dwired -c/etc/wpa_supplicant/wpa_supplicant-wired-eth4.conf
EOF

    sha256sum "$TEMPLATE" | awk '{print $1}' > "$MARKER"

    systemctl daemon-reload
    systemctl enable wpa_supplicant-wired@eth4
    systemctl restart wpa_supplicant-wired@eth4
    echo "✅ Applied network-aware override and saved checksum."
}

# Only apply override if systemd template changed
if [[ ! -f "$MARKER" || "$(sha256sum "$TEMPLATE" | awk '{print $1}')" != "$(cat $MARKER)" ]]; then
    echo "🔍 Detected UniFi OS update or missing checksum. Reapplying override..."
    apply_override
else
    echo "✅ Override already applied and up-to-date."
fi

# Setup reinstall service for future firmware resets
cat <<EOF > /etc/systemd/system/reinstall-wpa.service
[Unit]
Description=Reinstall and re-enable wpa_supplicant after firmware update
AssertPathExistsGlob=/etc/wpa_supplicant/packages/wpasupplicant*arm64.deb
AssertPathExistsGlob=/etc/wpa_supplicant/packages/libpcsclite1*arm64.deb
ConditionPathExists=!/sbin/wpa_supplicant
After=network-online.target
Requires=network-online.target

[Service]
Type=oneshot
ExecStartPre=/bin/bash -c 'dpkg -Ri /etc/wpa_supplicant/packages'
ExecStart=/bin/bash -c 'systemctl start wpa_supplicant-wired@eth4'
ExecStartPost=/bin/bash -c 'systemctl enable wpa_supplicant-wired@eth4'
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable reinstall-wpa.service
echo "✅ Persistent reinstall service installed."
