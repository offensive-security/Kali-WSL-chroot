#!/bin/bash

set -e

BUILDIR=$(pwd)
TMPDIR=$(mktemp -d)
TMPDIR_ARM64=$(mktemp -d)


create_x64_rootfs() {
cd $TMPDIR

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
apt-get --yes --force-yes install locales-all mlocate sudo net-tools wget host dnsutils whois curl
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

#sed -i 's/port=3389/port=3390/g' kali-root/etc/xrdp/xrdp.ini

echo "[*] Unmounting stuff"

umount kali-root/dev/pts
sleep 3
umount kali-root/dev
sleep 10
umount kali-root/proc
sleep 5


# cd kali-root

rm -rf kali-root/second-stage
rm -rf kali-root/etc/resolv.conf
cat <<EOF > kali-root/etc/apt/sources.list

deb http://http.kali.org/kali kali-rolling main non-free contrib
#deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF

cat << 'EOF' > kali-root/etc/profile
# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).

IS_WSL=`grep -i microsoft /proc/version` # WSL already sets PATH, shouldn't be overridden
if test "$IS_WSL" = ""; then
  if [ "`id -u`" -eq 0 ]; then
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  else
    PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
  fi
fi
export PATH

if [ "${PS1-}" ]; then
  if [ "${BASH-}" ] && [ "$BASH" != "/bin/sh" ]; then
    # The file bash.bashrc already sets the default PS1.
    # PS1='\h:\w\$ '
    if [ -f /etc/bash.bashrc ]; then
      . /etc/bash.bashrc
    fi
  else
    if [ "`id -u`" -eq 0 ]; then
      PS1='# '
    else
      PS1='$ '
    fi
  fi
fi

if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi
EOF

echo "[*] Compressing chroot to install.tar.gz"
mkdir -p $BUILDIR/x64
echo "cd kali-root; tar --ignore-failed-read -czf $BUILDIR/x64/install.tar.gz *"
cd kali-root; tar --ignore-failed-read -czf $BUILDIR/x64/install.tar.gz *
}

create_arm64_rootfs() {
cd $TMPDIR_ARM64

echo "[*] Boostrapping a base Kali install"

# Because we're using a foreign architecture (arm64 on amd64) we have to do the debootstrap in 2 stages.
LANG=C debootstrap --foreign --arch arm64 kali-rolling ./kali-root http://http.kali.org/kali
cp /usr/bin/qemu-aarch64-static kali-root/usr/bin
LANG=C chroot kali-root /debootstrap/debootstrap --second-stage

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
apt-get --yes --force-yes install locales-all mlocate sudo net-tools wget host dnsutils whois curl
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

#sed -i 's/port=3389/port=3390/g' kali-root/etc/xrdp/xrdp.ini

echo "[*] Unmounting stuff"

umount kali-root/dev/pts
sleep 3
umount kali-root/dev
sleep 10
umount kali-root/proc
sleep 5


# cd kali-root

rm -rf kali-root/second-stage
rm -rf kali-root/etc/resolv.conf
rm -rf kali-root/usr/bin/qemu-aarch64-static
cat <<EOF > kali-root/etc/apt/sources.list

deb http://http.kali.org/kali kali-rolling main non-free contrib
#deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF

cat << 'EOF' > kali-root/etc/profile
# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).

IS_WSL=`grep -i microsoft /proc/version` # WSL already sets PATH, shouldn't be overridden
if test "$IS_WSL" = ""; then
  if [ "`id -u`" -eq 0 ]; then
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  else
    PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
  fi
fi
export PATH

if [ "${PS1-}" ]; then
  if [ "${BASH-}" ] && [ "$BASH" != "/bin/sh" ]; then
    # The file bash.bashrc already sets the default PS1.
    # PS1='\h:\w\$ '
    if [ -f /etc/bash.bashrc ]; then
      . /etc/bash.bashrc
    fi
  else
    if [ "`id -u`" -eq 0 ]; then
      PS1='# '
    else
      PS1='$ '
    fi
  fi
fi

if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi
EOF

echo "[*] Compressing chroot to install.tar.gz"
mkdir -p $BUILDIR/ARM64
echo "cd kali-root; tar --ignore-failed-read -czf $BUILDIR/ARM64/install.tar.gz *"
cd kali-root; tar --ignore-failed-read -czf $BUILDIR/ARM64/install.tar.gz *
}
create_x64_rootfs
create_arm64_rootfs
echo "Cleaning up temporary build folders"
rm -rf $TMPDIR
rm -rf $TMPDIR_ARM64
