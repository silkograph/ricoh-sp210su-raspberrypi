#!/usr/bin/env bash
set -e

echo "=== Ricoh SP 210SU Raspberry Pi Installer ==="

# 1. Root check
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root: sudo ./install.sh"
  exit 1
fi

# 2. Install base packages
echo "📦 Installing system dependencies..."
apt update
apt install -y \
  cups \
  avahi-daemon \
  qemu-user-static \
  debootstrap \
  ghostscript

systemctl enable --now cups avahi-daemon

# 3. Create i386 chroot
CHROOT=/opt/qemu/debian-i386

if [[ ! -d "$CHROOT" ]]; then
  echo "📂 Creating i386 Debian chroot..."
  mkdir -p "$CHROOT"
  debootstrap --arch=i386 stable "$CHROOT" http://deb.debian.org/debian
fi

# 4. Install qemu binary into chroot
echo "🔧 Installing qemu-i386-static into chroot..."
cp -f /usr/bin/qemu-i386-static "$CHROOT/usr/bin/"

# 5. Install runtime libs inside chroot
echo "📦 Installing runtime libraries inside chroot..."
chroot "$CHROOT" apt update
chroot "$CHROOT" apt install -y libcups2 libcupsimage2 ghostscript

# 6. Verify rastertolilo presence
FILTER="$CHROOT/usr/lib/cups/filter/rastertolilo"
if [[ ! -x "$FILTER" ]]; then
  echo ""
  echo "❌ rastertolilo NOT FOUND"
  echo "➡️  Please extract it from Ricoh SP 210 Linux driver and place it at:"
  echo "   $FILTER"
  echo ""
  exit 1
fi

# 7. Install wrapper filter
echo "🧩 Installing wrapper filter..."
cat > /usr/lib/cups/filter/rastertolilo <<'EOF'
#!/bin/sh
exec sudo -n chroot /opt/qemu/debian-i386 /usr/lib/cups/filter/rastertolilo "$@"
EOF

chmod +x /usr/lib/cups/filter/rastertolilo

# 8. Configure sudoers for CUPS
echo "🔐 Configuring sudoers..."
cat > /etc/sudoers.d/011_lp-chroot <<'EOF'
lp ALL=(ALL) NOPASSWD: /usr/sbin/chroot
EOF

chmod 440 /etc/sudoers.d/011_lp-chroot

# 9. Restart CUPS
systemctl restart cups

echo ""
echo "✅ Installation complete!"
echo ""
echo "NEXT STEPS:"
echo "1. Copy RICOH_SP_210SU.ppd to /etc/cups/ppd/"
echo "2. Add printer via lpadmin or CUPS web UI"
echo "3. Always print with A4:"
echo "   lp -d RICOH_SP_210SU -o media=A4 -o PageSize=A4"
echo ""
