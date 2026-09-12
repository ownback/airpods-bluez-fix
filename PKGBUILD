# Maintainer: Andreas Radke <andyrtr@archlinux.org>
# Maintainer: Robin Candau <antiz@archlinux.org>
# Contributor: Tom Gundersen <teg@jklm.no>
# Contributor: Andrea Scarpino <andrea@archlinux.org>
# Contributor: Geoffroy Carrier <geoffroy@archlinux.org>
# Local fork: AirPods Pro 3 crash fixes — see README.md
#
# Based on the official Arch bluez PKGBUILD with three local patches:
#  - 0001: upstream fix 3f0cffa8df578a9ec2a133f896113c8a02eef250
#    ("a2dp: Fix loading of remote SEP from cache") cherry-picked on top of
#    the 5.87 tag. Without it bluetoothd segfaults in load_remote_sep()
#    right after "Unable to load LastUsed: rseid N not found".
#  - 0002: defensive NULL-guard in gatt-client discovery_op_complete() to
#    stop a segfault when a GATT service discovery is aborted mid-flight.
#  - 0003: gatt-db notifies observers about removal of inactive services
#    too, so discovery ops' pending service lists can never hold dangling
#    attribute pointers (the real use-after-free behind the crash above).

pkgbase=bluez
pkgname=('bluez' 'bluez-utils' 'bluez-libs' 'bluez-cups' 'bluez-deprecated-tools' 'bluez-hid2hci' 'bluez-mesh' 'bluez-obex')
pkgver=5.87
pkgrel=6
url="http://www.bluez.org/"
arch=('x86_64')
license=('GPL-2.0-only')
makedepends=('dbus' 'libical' 'systemd' 'alsa-lib' 'json-c' 'ell' 'python-docutils' 'python-pygments' 'cups' 'git')
source=("git+https://github.com/bluez/bluez.git#tag=$pkgver"
        "0001-a2dp-Fix-loading-of-remote-SEP-from-cache.patch"
        "0002-gatt-client-null-guard-discovery-op.patch"
        "0003-gatt-db-notify-removal-of-inactive-services.patch"
	bluetooth.modprobe)
b2sums=('SKIP'
        '8e19f1f59fa0e49df83ade6b394bc4bd71ba3efb2f102076e8dd672a18617bcc7f10790285f8ca579b05783b6cc8a70d2ea5f92500c4346e330a4082f38093e4'
        '8733a158256770236c1e16f9b9fff97b722d985004a36f6ed1dec9e9fa000782fb8294f7fdcc0291e9a39fe4560b4a916fc46543d5c155d1ce597566e52901da'
        '4aecd0dcbd3b2419f4865670cbf4332123e9d655a9ce98023ad266c5a439fbdddbd57f94c4043e60e3b51a05c24384e5eed60ecde7350032fc4310c4f5661d12'
        '0ce33d13b796d4ae2fd688b17742b3a3055663b68a352b02720dac82bcfdaa47bf2ee2a034dfb8ef4ddf3f827bc58fe80548730939c2915f64864cea39c10170')
# validpgpkeys=('E932D120BC2AEC444E558F0106CA9F5D1DCF2659') # Marcel Holtmann <marcel@holtmann.org>

prepare() {
  cd "${pkgname}"
  patch -Np1 -i ../0001-a2dp-Fix-loading-of-remote-SEP-from-cache.patch
  patch -Np1 -i ../0002-gatt-client-null-guard-discovery-op.patch
  patch -Np1 -i ../0003-gatt-db-notify-removal-of-inactive-services.patch
  autoreconf -vfi
}

build() {
  cd "${pkgname}"
  ICAL_LIBS="-lical -licalvcal" \
  ./configure \
          --prefix=/usr \
          --mandir=/usr/share/man \
          --sysconfdir=/etc \
          --localstatedir=/var \
          --libexecdir=/usr/lib \
          --with-dbusconfdir=/usr/share \
          --enable-btpclient \
          --enable-midi \
          --enable-sixaxis \
          --enable-mesh \
          --enable-hid2hci \
          --enable-experimental \
          --enable-datafiles \
          --enable-external-ell \
          --enable-library --enable-deprecated # libraries and these tools are deprecated
  make

  # fake installation to be seperated into packages
  make DESTDIR="${srcdir}/fakeinstall" install

  # add missing tools FS#41132, FS#41687, FS#42716
  for files in `find tools/ -type f -perm -755`; do
    filename=$(basename $files)
    install -Dm755 "${srcdir}"/"${pkgbase}"/tools/$filename "${srcdir}/fakeinstall"/usr/bin/$filename
  done

  for files in `find client/btpclient/ -type f -perm -755`; do
    filename=$(basename $files)
    install -Dm755 "${srcdir}"/"${pkgbase}"/client/btpclient/$filename "${srcdir}/fakeinstall"/usr/bin/$filename
  done


  # add man pages for the above tools
  # https://github.com/bluez/bluez/commit/44e3dd321e4be052bcde40939552b93b734538d3
  for manfile in `find doc/ -type f -regex '.*\.[1-8]'`; do
    section=$(echo $manfile | sed -E 's/.*\.([1-8])$/\1/')
    filename=$(basename $manfile)
    install -Dm644 "${srcdir}"/"${pkgbase}"/doc/$filename "${srcdir}/fakeinstall"/usr/share/man/man${section}/$filename
  done
}

_install() {
  local src f dir
  for src; do
    f="${src#fakeinstall/}"
    dir="${pkgdir}/${f%/*}"
    install -m755 -d "${dir}"
    # use copy so a new file is created and fakeroot can track properties such as setuid
    cp -av "${src}" "${dir}/"
    rm -rf "${src}"
  done
}

check() {
  cd "$pkgname"
  make check
}


package_bluez() {
  pkgdesc="Daemons for the bluetooth protocol stack"
  depends=('systemd-libs' 'dbus' 'glib2' 'alsa-lib' 'glibc')
  backup=(etc/bluetooth/{main,input,network}.conf)

  _install fakeinstall/etc/bluetooth/main.conf
  _install fakeinstall/etc/bluetooth/input.conf
  _install fakeinstall/etc/bluetooth/network.conf
  _install fakeinstall/usr/lib/bluetooth/bluetoothd
  _install fakeinstall/usr/lib/systemd/system/bluetooth.service
  _install fakeinstall/usr/share/dbus-1/system-services/org.bluez.service
  _install fakeinstall/usr/share/dbus-1/system.d/bluetooth.conf
  _install fakeinstall/usr/share/man/man8/bluetoothd.8

  # bluetooth.service wants ConfigurationDirectoryMode=0555
  chmod -v 555 "${pkgdir}"/etc/bluetooth

  # add basic documention
  install -dm755 "${pkgdir}"/usr/share/doc/"${pkgbase}"/dbus-apis
  cp -a "${pkgbase}"/doc/*.txt "${pkgdir}"/usr/share/doc/"${pkgbase}"/dbus-apis/
  # fix module loading errors
  install -dm755 "${pkgdir}"/usr/lib/modprobe.d
  install -Dm644 "${srcdir}"/bluetooth.modprobe "${pkgdir}"/usr/lib/modprobe.d/bluetooth-usb.conf
  # load module at system start required by some functions
  # https://bugzilla.kernel.org/show_bug.cgi?id=196621
  install -dm755 "$pkgdir"/usr/lib/modules-load.d
  echo "crypto_user" > "$pkgdir"/usr/lib/modules-load.d/bluez.conf
}

package_bluez-utils() {
  pkgdesc="Development and debugging utilities for the bluetooth protocol stack"
  depends=('dbus' 'systemd-libs' 'glib2' 'glibc' 'readline')
  optdepends=('ell: for btpclient'
              'perl: for parse_companies.pl')

  provides=('bluez-plugins')
  replaces=('bluez-plugins')

  _install fakeinstall/usr/bin/{advtest,avinfo,avtest,bcmfw,bdaddr,bluemoon,bluetoothctl,bluetooth-player,bneptest,btattach,btconfig,btgatt-client,btgatt-server,btinfo,btiotest,btmgmt,btmon,btpclient,btpclientctl,btproxy,btsnoop,check-selftest,cltest,create-image,eddystone,gatt-service,hcieventmask,hcisecfilter,hex2hcd,hid2hci,hwdb,ibeacon,isotest,l2ping,l2test,mpris-proxy,nokfw,oobtest,parse_companies.pl,rctest,rtlfw,scotest,seq2bseq,test-runner,update_compids.sh}
  _install fakeinstall/usr/lib/systemd/user/mpris-proxy.service
  _install fakeinstall/usr/share/man/man1/bluetoothctl*.1
  # _install fakeinstall/usr/share/man/man1/{bdaddr,btattach,btmgmt,btmon,isotest,l2ping,rctest}.1
  _install fakeinstall/usr/share/man/man1/{btattach,btmon,isotest,l2ping,rctest}.1
  _install fakeinstall/usr/share/man/man5/org.bluez.{A,B,C,D,G,I,L,M,N,P,T}*.5
  _install fakeinstall/usr/share/man/man7/{btsnoop,hci,l2cap,mgmt,sco,iso}.7
  _install fakeinstall/usr/share/zsh/site-functions/_bluetoothctl
}

package_bluez-deprecated-tools() {
  pkgdesc="Deprecated tools that are no longer maintained"
  depends=('json-c' 'systemd-libs' 'glib2' 'dbus' 'readline' 'glibc')

  _install fakeinstall/usr/bin/{ciptool,hciattach,hciconfig,hcitool,meshctl,rfcomm,sdptool}
  _install fakeinstall/usr/share/man/man1/{ciptool,hciattach,hciconfig,hcitool,rfcomm,sdptool}.1
  _install fakeinstall/usr/share/man/man7/rfcomm.7
}

package_bluez-libs() {
  pkgdesc="Deprecated libraries for the bluetooth protocol stack"
  depends=('glibc')
  provides=('libbluetooth.so')
  license=('LGPL-2.1-only')

  _install fakeinstall/usr/include/bluetooth/*
  _install fakeinstall/usr/lib/libbluetooth.so*
  _install fakeinstall/usr/lib/pkgconfig/*
}

package_bluez-cups() {
  pkgdesc="CUPS printer backend for Bluetooth printers"
  depends=('cups' 'glib2' 'glibc' 'dbus')

  _install fakeinstall/usr/lib/cups/backend/bluetooth
}

package_bluez-hid2hci() {
  pkgdesc="Put HID proxying bluetooth HCI's into HCI mode"
  depends=('systemd-libs' 'glibc')

  _install fakeinstall/usr/lib/udev/*
  _install fakeinstall/usr/share/man/man1/hid2hci.1
}

package_bluez-mesh() {
  pkgdesc="Services for bluetooth mesh"
  depends=('ell' 'json-c' 'readline' 'glibc')
  backup=('etc/bluetooth/mesh-main.conf')

  _install fakeinstall/etc/bluetooth/mesh-main.conf
  _install fakeinstall/usr/bin/{mesh-cfgclient,mesh-cfgtest}
  _install fakeinstall/usr/lib/bluetooth/bluetooth-meshd
  _install fakeinstall/usr/lib/systemd/system/bluetooth-mesh.service
  _install fakeinstall/usr/share/dbus-1/system-services/org.bluez.mesh.service
  _install fakeinstall/usr/share/dbus-1/system.d/bluetooth-mesh.conf
  _install fakeinstall/usr/share/man/man8/bluetooth-meshd.8

  # bluetooth.service wants ConfigurationDirectoryMode=0555
  chmod -v 555 "${pkgdir}"/etc/bluetooth
}

package_bluez-obex() {
  pkgdesc="Object Exchange daemon for sharing content"
  depends=('glib2' 'libical' 'dbus' 'readline' 'systemd-libs' 'glibc')

  _install fakeinstall/usr/bin/{obexctl,obex-client-tool,obex-server-tool}
  _install fakeinstall/usr/lib/bluetooth/obexd
  _install fakeinstall/usr/lib/systemd/user/obex.service
  _install fakeinstall/usr/share/dbus-1/services/org.bluez.obex.service
  _install fakeinstall/usr/share/dbus-1/system.d/obex.conf
  _install fakeinstall/usr/lib/systemd/user/dbus-org.bluez.obex.service
  _install fakeinstall/usr/share/man/man5/org.bluez.obex*.5

  # make sure there are no files left to install
  rm fakeinstall/usr/lib/libbluetooth.la
  find fakeinstall -depth -print0 | xargs -0 rmdir
}
