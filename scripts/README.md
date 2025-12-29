Make executable:
```bash
chmod +x scripts/install.sh
```

# Extract Ricoh driver
dpkg-deb -x SP-210211-series-Printer-0.03.deb ricoh

# Copy filter
sudo cp ricoh/usr/lib/cups/filter/rastertolilo \
  /opt/qemu/debian-i386/usr/lib/cups/filter/

sudo chmod +x /opt/qemu/debian-i386/usr/lib/cups/filter/rastertolilo

