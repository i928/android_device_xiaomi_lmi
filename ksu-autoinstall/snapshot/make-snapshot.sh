#!/bin/bash
#
# make-snapshot.sh -- build ksu-snapshot.tar.gz from a phone that has the
# modules freshly installed and working.
#
#   1. install the modules on a phone (drop the zips in ../ and let
#      ksu-autoinstall.sh install them, or use the manager), reboot once
#   2. ./make-snapshot.sh            (adb root via su on the phone)
#   3. move the zips to ../installed-in-snapshot/ so they are not installed
#      on top, rebuild the ROM
#
# What goes in: /data/adb/modules plus what the module installers put
# elsewhere in /data/adb (their config dirs, hook scripts, the metamodule link).
# What stays out: state created while running -- it is per-device (AlwaysStrong's
# hbk and fetched keybox) or stale, and the module actions recreate it after
# setup wizard. ksu-snapshot.sh on the phone unpacks it and restores SELinux
# labels from the .ksu-snapshot-labels list made here (busybox tar drops them).
set -e
cd "$(dirname "$0")"
ZIPS=../installed-in-snapshot
BB=/data/adb/ksu/bin/busybox
TMP=/data/local/tmp/ksu-snapshot-build

# Relative to /data/adb.
INCLUDE="modules bindhosts susfs4ksu hybrid-mount/config.toml hybrid-mount/module_blacklist.toml
post-fs-data.d/rezygisk.sh post-mount.d/rezygisk.sh boot-completed.d/hmaoss.sh metamodule"

# Runtime files inside module dirs, relative to /data/adb. .bootstrapped makes
# AlwaysStrong skip its own first-boot Action; pif.prop/custom.pif.prop and the
# log are what that Action wrote on the source phone.
EXCLUDE="modules/tricky_store/.bootstrapped modules/tricky_store/pif.prop
modules/tricky_store/custom.pif.prop modules/tricky_store/logs"

# Modules installed on the source phone that must not ship, e.g. one being
# tried out:  SNAPSHOT_SKIP="droidwin_keybox" ./make-snapshot.sh
for m in $SNAPSHOT_SKIP; do EXCLUDE="$EXCLUDE modules/$m"; done

# AlwaysStrong's installer seeds /data/adb/tricky_store from its zip (bundled
# keybox.xml, starter target.txt) and generates a random hbk. Seed the same two
# files from the zip rather than this phone's fetched ones; ksu-snapshot.sh
# generates hbk per device.
AS_ZIP=$(ls $ZIPS/*AlwaysStrong*.zip 2>/dev/null | head -1)
[ -n "$AS_ZIP" ] || { echo "no AlwaysStrong zip in $ZIPS"; exit 1; }
rm -rf ts && mkdir ts
unzip -qjo "$AS_ZIP" keybox.xml target.txt -d ts
# Pushed as the adb shell user, then moved into the root-owned build dir.
adb shell "rm -rf /data/local/tmp/ksu-snapshot-ts; mkdir /data/local/tmp/ksu-snapshot-ts"
adb push ts/keybox.xml ts/target.txt /data/local/tmp/ksu-snapshot-ts/ >/dev/null
adb shell "su -c 'rm -rf $TMP; mkdir -p $TMP && mv /data/local/tmp/ksu-snapshot-ts $TMP/tricky_store'"
rm -rf ts

adb shell "su -c '
set -e
cd /data/adb
for p in $(echo $INCLUDE); do [ -e \$p ] || [ -L \$p ] || { echo missing \$p; exit 1; }; done
$BB tar -cpf - $(echo $INCLUDE) | $BB tar -xpf - -C $TMP
cd $TMP
rm -rf $(echo $EXCLUDE)
chown -R 0:0 tricky_store; chmod 755 tricky_store; chmod 644 tricky_store/*
ls modules/*/update modules/*/disable modules/*/remove 2>/dev/null && { echo pending module state; exit 1; }
# Labels from the live files; tricky_store is left to inherit adb_data_file.
find $(echo $INCLUDE) | while read f; do echo \"\$(ls -dZ /data/adb/\$f | cut -d\" \" -f1) \$f\"; done > .ksu-snapshot-labels
$BB tar -czpf /data/local/tmp/ksu-snapshot.tar.gz .ksu-snapshot-labels \$(ls -A | grep -v ^.ksu-snapshot-labels\$)
cd /; rm -rf $TMP
'"
adb pull /data/local/tmp/ksu-snapshot.tar.gz . >/dev/null
adb shell "su -c 'rm -f /data/local/tmp/ksu-snapshot.tar.gz'"
ls -la ksu-snapshot.tar.gz
echo "labels: $(tar -xzOf ksu-snapshot.tar.gz .ksu-snapshot-labels | wc -l)"
tar -tzf ksu-snapshot.tar.gz | cut -d/ -f1-2 | sort -u | grep -v '^modules/.*/' | tr '\n' ' '; echo
