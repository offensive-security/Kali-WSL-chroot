#!/bin/bash

rm -rf kali-root
rm -rf install.tar.gz

echo "[*] Boostrapping a base Kali install"

LANG=C debootstrap kali-rolling ./kali-root http://http.kali.org/kali

cat << EOF > kali-root/etc/resolv.conf
nameserver 8.8.8.8
EOF

export MALLOC_CHECK_=0 # workaround for LP: #520465
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

echo "[*] Mounting stuff"

mount -t proc proc kali-root/proc
mount -o bind /dev/ kali-root/dev/
mount -o bind /dev/pts kali-root/dev/pts


cat << EOF > kali-root/second-stage
#!/bin/bash
apt-get update
apt-get --yes --force-yes install locales-all mlocate sudo
#apt-get --yes --force-yes install kali-desktop-xfce xorg xrdp
rm -rf /root/.bash_history
apt-get clean
apt-get autoremove

rm -f /0
rm -f /hs_err*
rm -f /cleanup
rm -f /usr/bin/qemu*

updatedb
EOF

echo "[*] Executing second stage"

chmod +x kali-root/second-stage
LANG=C chroot kali-root /second-stage

sed -i 's/port=3389/port=3390/g' kali-root/etc/xrdp/xrdp.ini

echo "[*] Unmounting stuff"

umount kali-root/dev/pts
umount kali-root/dev/
umount kali-root/proc

echo "[*]Compressing chroot to install.tar.gz"

cd kali-root
tar czf ../install.tar.gz *
