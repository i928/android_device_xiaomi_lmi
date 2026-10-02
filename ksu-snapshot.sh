#!/system/bin/sh
#
# Unpack the ROM's KernelSU module snapshot on the first boot after a wipe, in
# place of `ksud module install` for each zip.
#
# The snapshot is a finished install taken from a device (modules/, the files
# the module installers put elsewhere in /data/adb, and the metamodule link),
# plus .ksu-snapshot-labels -- one "context path" line per entry, because
# busybox tar drops SELinux labels and module files carry several
# (system_file, system_lib_file, xposed_file, dex2oat_exec, adb_data_file).
# Runtime state (fetched keybox, lspd, rezygisk sockets) is deliberately not in
# it; the module actions set that up after setup wizard. tricky_store/ holds
# only what AlwaysStrong's installer seeds from its zip. See
# ksu-autoinstall/snapshot/make-snapshot.sh for exactly what is included.
#
# It leaves exactly the state `ksud module install` leaves: each module staged
# in modules_update/<id>, with a stub modules/<id>/ holding module.prop and an
# `update` flag. KernelSU merges them at post-fs-data on the next boot, and
# ksu-autoinstall.sh does that one reboot (marker snapshot.reboot), as it does
# after zip installs. An earlier version put the modules straight into
# modules/ and ran `ksud post-fs-data` itself to make them live on the same
# boot; that build bootlooped, so the tested install-then-reboot path is kept.
#
# Run by init.ksu-autoinstall.rc at post-fs-data, synchronously, after
# `ksud install` has unpacked busybox.

SNAP=/product/etc/ksu-autoinstall/ksu-snapshot.tar.gz
ADB=/data/adb
STATE=$ADB/.ksu-autoinstall
BB=$ADB/ksu/bin/busybox
LOG=$ADB/ksu-autoinstall.log
# Also here: /metadata survives a recovery factory reset, so if this ever
# breaks a boot and the device gets wiped, the record of how far it got does not.
MLOG=/metadata/ksu-snapshot.log
log() {
	echo "$(date +%H:%M:%S) - $*" >> "$LOG"
	echo "$(date '+%m-%d %H:%M:%S') - $*" >> "$MLOG"
}

[ -f "$SNAP" ] || exit 0
[ -f "$STATE/snapshot.done" ] && exit 0
mkdir -p "$STATE"

echo "" >> "$LOG"
echo "===== $(date '+%Y-%m-%d %H:%M:%S') (post-fs-data) =====" >> "$LOG"

# Only onto a device with no modules yet. On a device that already has some
# (e.g. an update from a build without the snapshot), unpacking would roll back
# modules the user has updated since, so just record it as handled.
if [ -n "$(ls -A $ADB/modules 2>/dev/null)" ] || [ -n "$(ls -A $ADB/modules_update 2>/dev/null)" ]; then
	log "[SNAPSHOT] Skipped: modules already present."
	: > "$STATE/snapshot.done"
	exit 0
fi
if [ ! -x "$BB" ]; then
	log "[FAILED] Snapshot: no $BB (ksud install did not run?)."
	exit 0
fi

log "[SNAPSHOT] Unpacking $SNAP..."
rmdir "$ADB/modules" "$ADB/modules_update" 2>/dev/null
if ! "$BB" tar -xzpf "$SNAP" -C "$ADB"; then
	log "[FAILED] Snapshot: tar failed."
	exit 0
fi
log "[SNAPSHOT] Unpacked."

# Stage like `ksud module install`: the module trees go to modules_update/.
mv "$ADB/modules" "$ADB/modules_update" || { log "[FAILED] Snapshot: mv to modules_update."; exit 0; }
n=0
while read -r ctx path; do
	case "$path" in
		modules) path=modules_update ;;
		modules/*) path=modules_update/${path#modules/} ;;
	esac
	chcon -h "$ctx" "$ADB/$path" && n=$((n + 1))
done < "$ADB/.ksu-snapshot-labels"
rm -f "$ADB/.ksu-snapshot-labels"
log "[SNAPSHOT] $n SELinux labels restored."

# The stubs ksud leaves in modules/: module.prop and an `update` flag.
mkdir -p "$ADB/modules"
chmod 755 "$ADB/modules"
for mod in "$ADB"/modules_update/*/; do
	id=${mod%/}
	id=${id##*/}
	mkdir -p "$ADB/modules/$id"
	cp "$mod/module.prop" "$ADB/modules/$id/module.prop"
	: > "$ADB/modules/$id/update"
done

# AlwaysStrong's installer generates this per install (a random 32-byte key);
# the snapshot ships its tricky_store/ without it so no two devices share one.
if [ -d "$ADB/tricky_store" ] && [ ! -f "$ADB/tricky_store/hbk" ]; then
	head -c 32 /dev/random > "$ADB/tricky_store/hbk"
	chmod 600 "$ADB/tricky_store/hbk"
fi

: > "$STATE/snapshot.done"
: > "$STATE/snapshot.reboot"
log "[SNAPSHOT] Staged: $(ls $ADB/modules_update | tr '\n' ' ')- active after the next reboot."
