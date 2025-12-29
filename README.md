# `ricoh-sp210su-raspberrypi`

### CUPS + QEMU + x86 Driver Compatibility Layer for Ricoh SP 210SU on Raspberry Pi ARM

This repository documents how to run **Ricoh SP 210 / SP 210SU GDI printer** on **ARM devices (Raspberry Pi Zero 2 W)** using **CUPS** + patched **PPD + rastertolilo x86 filter executed inside QEMU i386 chroot**.

> This printer does *not* natively support PostScript/PCL — It needs Ricoh's proprietary **GDI raster driver (rastertolilo)**, available only for **Intel i386 Linux**.
> We bypass architecture restriction using a **Debian-i386 chroot executed via QEMU user-mode emulation**.

This README exists so future-you will not spend *two entire days debugging again.* 😄

---

## System Used

| Component             | Details                                                                        |
| --------------------- | ------------------------------------------------------------------------------ |
| Printer Model         | **Ricoh SP 210SU**                                                             |
| Print method          | USB-only GDI raster                                                            |
| CUPS Host             | **Raspberry Pi Zero 2 W (ARMv8)**                                              |
| OS Tested             | Raspberry Pi OS + QEMU i386 chroot                                             |
| Remote Clients Tested | ✔ macOS AirPrint via IPP <br> ✔ Android Mobile <br> ✔ Other PCs (HTTP CUPS UI) |
| Working state         | **Fully Printing (A4/PDF/Text)**                                               |
| Driver                | `rastertolilo` executed within `qemu-i386` chroot                              |
| PPD Installed On Pi   | `/etc/cups/ppd/RICOH_SP_210SU.ppd`                                             |
| QEMU chroot path      | `/opt/qemu/debian-i386`                                                        |

---

## 1. Install Packages

```bash
sudo apt update
sudo apt install cups avahi-daemon qemu-user-static debootstrap
sudo systemctl enable --now cups avahi-daemon
```

---

## 2. Create i386 Chroot For Driver

```bash
sudo mkdir -p /opt/qemu/debian-i386
sudo debootstrap --arch=i386 stable /opt/qemu/debian-i386 http://deb.debian.org/debian
sudo cp /usr/bin/qemu-i386-static /opt/qemu/debian-i386/usr/bin/
```

---

## 3. Install Ricoh driver inside chroot

```bash
sudo chroot /opt/qemu/debian-i386
apt update
apt install cups libcups2 ghostscript
exit
```

Copy the real i386 filter into chroot:

```
/opt/qemu/debian-i386/usr/lib/cups/filter/rastertolilo
```

---

## 4. Wrapper Script (runs x86 filter through chroot)

Create:

```
sudo nano /usr/lib/cups/filter/rastertolilo
```

Paste:

```sh
#!/bin/sh
exec sudo -n chroot /opt/qemu/debian-i386 /usr/lib/cups/filter/rastertolilo "$@"
```

Make executable:

```bash
sudo chmod +x /usr/lib/cups/filter/rastertolilo
```

---

## 5. Allow CUPS user `lp` to execute chroot without password

```
sudo nano /etc/sudoers.d/011_lp-chroot
```

Add:

```
lp ALL=(ALL) NOPASSWD: /usr/sbin/chroot
```

---

## 6. Install & fix the PPD

Place final working PPD here:

```
/etc/cups/ppd/RICOH_SP_210SU.ppd
```

Check cupsFilter entry:

```
*cupsFilter: "application/vnd.cups-raster 100 rastertolilo"
```

Default Page must be A4:

```
*DefaultPageSize: A4
*DefaultPageRegion: A4
```

---

## 7. Add Printer in CUPS

```bash
sudo lpadmin -p RICOH_SP_210SU -E -v usb://RICOH/SP%20210SU -P /etc/cups/ppd/RICOH_SP_210SU.ppd
sudo cupsenable RICOH_SP_210SU
sudo cupsaccept RICOH_SP_210SU
```

Restart:

```bash
sudo systemctl restart cups
```

---

## 8. Verification & Test Print

```bash
echo "Test OK" | lp -d RICOH_SP_210SU -o media=A4 -o PageSize=A4
```

Expected printer behaviour:

✔ wakes up
⚠ may show "Form Feed / Paper Size Mismatch"
👉 press **Form Feed button** once → prints correctly

---

## 9. macOS configuration

Printer appears under:

```
ipp://192.168.1.39/printers/RICOH_SP_210SU
```

Check config:

```bash
lpoptions -p RICOH
lpoptions -p RICOH -l    # list capabilities
```

macOS uses **Generic PostScript** but job is rasterized on Pi.

<img width="553" height="513" alt="image" src="https://github.com/user-attachments/assets/1b7b99c3-e3b2-4e39-8049-efec6417c5d2" />


---

## 10. Android Printing

Install **CUPS/AirPrint supported print plugin**
Select → `RICOH_SP_210SU` (network)
A4 must be manually selected to avoid mismatch

---

## 11. Logs & Debugging

Show job conversion:

```bash
sudo tail -f /var/log/cups/error_log
```

Check media size negotiated:

```
grep -i "DEVICEWIDTHPOINTS" /var/log/cups/error_log
```

Example working log:

```
-dDEVICEWIDTHPOINTS=595 -dDEVICEHEIGHTPOINTS=842 -scupsPageSizeName=A4
```

---

## 12. Common Errors & Fixes

| Error                                       | Cause                   | Fix                                  |
| ------------------------------------------- | ----------------------- | ------------------------------------ |
| `Can't open Raster` / `Bad file descriptor` | wrapper didn't chroot   | check `/etc/sudoers.d/011_lp-chroot` |
| mac prints but freezes                      | page size mismatch      | force `-o media=A4 -o PageSize=A4`   |
| printer blinks red                          | mismatch expected       | press **Form Feed**                  |
| Android prints blank                        | chooses Letter size     | set A4 in print dialog               |
| `filter failed` in CUPS                     | missing exec permission | chmod +x rastertolilo                |

---

## 13. Backup for Future Restore

```bash
sudo tar -cvf ricoh_backup.tar \
  /etc/cups/ppd/RICOH_SP_210SU.ppd \
  /usr/lib/cups/filter/rastertolilo \
  /etc/sudoers.d/011_lp-chroot \
  /opt/qemu/debian-i386
```

To restore:

```bash
sudo tar -xvf ricoh_backup.tar -C /
sudo systemctl restart cups
```

---
