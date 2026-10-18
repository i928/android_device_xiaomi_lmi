#!/system/bin/sh
#
# Install the KernelSU module zips that ship with the ROM, once each.
#
# The point is a wiped device: `fastboot -w` erases /data and /sdcard, so every
# module and every zip staged there is gone. Zips under /product survive, because
# they are part of the image, so a freshly wiped phone can set itself back up with
# no transfers at all.
#
# Version check: each zip's module.prop (id, versionCode) is compared with the
# installed module, so a ROM update that ships a newer module upgrades phones
# that already have it, and never downgrades one the user updated past the ROM:
#   not installed, never installed by us  -> install
#   not installed, installed by us before -> skip (the user removed it)
#   installed versionCode < zip's         -> install the upgrade
#   installed versionCode >= zip's        -> skip
# The markers live in /data/adb, so a wipe deliberately makes them install
# again. A zip without a readable id/versionCode falls back to once per
# filename.
#
# Install order is filename order, which is why the zips carry numeric prefixes:
# the Zygisk implementation (10-ReZygisk) has to be installed before the Zygisk
# modules that load through it (20-*).
#
# Expected log on a wiped device (/data/adb/ksu-autoinstall.log):
#   boot 1: [SCRIPT TRIGGERED] -> [INSTALLED] x8 -> [WAITING] setup wizard ->
#           [REBOOT CMD]
#   boot 2: [SCRIPT TRIGGERED] -> [MODULES ACTIVE] 8 -> [NOTHING TO DO]

LOG=/data/adb/ksu-autoinstall.log
log() {
	echo "$(date +%H:%M:%S) - $*" >> "$LOG"
}

# One instance per boot: two running at once unpack into the same
# modules_update directory and break each other's installs. /dev is tmpfs, so
# the lock clears on reboot. To run it again by hand in the same boot:
#   rmdir /dev/.ksu-autoinstall.lock
if ! mkdir /dev/.ksu-autoinstall.lock 2>/dev/null; then
	log "[SKIPPED] Already ran this boot (rmdir /dev/.ksu-autoinstall.lock to rerun)."
	exit 0
fi

(
SRC=/product/etc/ksu-autoinstall
STATE=/data/adb/.ksu-autoinstall
KSUD=/data/adb/ksud
OUT=/dev/.ksu-autoinstall.out

# Reboot once after installing, so the modules are actually active. On by
# default: device.mk ships persist.ksu_ai_reboot=1 in build.prop, which
# applies exactly when /data/property is empty, i.e. after a wipe. The reboot
# waits for setup wizard to finish. To turn it off:
#   setprop persist.ksu_ai_reboot 0   (persists across boots)
# Name kept under 31 chars: the legacy property getter truncates longer names, so
# a longer name read back as nothing on sunfish.
REBOOT=$(getprop persist.ksu_ai_reboot 0)

echo "" >> "$LOG"
echo "===== $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$LOG"
log "[SCRIPT TRIGGERED] Boot reason: $(getprop sys.boot.reason), uptime $(cut -d. -f1 /proc/uptime)s"

[ -d "$SRC" ] || { log "[NOTHING TO DO] $SRC not in this ROM."; exit 0; }

# Earlier builds of this ROM dropped copies of this script into other KernelSU
# script directories. init.ksu-autoinstall.rc now installs it in service.d and
# removes the post-fs-data.d copy.

# On a wiped device /data/adb/ksud does not exist: the manager app creates it on
# first launch by copying its own bundled libksud.so. Waiting for that would mean
# nothing installs until the user opens the manager and reboots, which defeats
# the point. Seed it from the same binary the manager would use -- it ships in
# this ROM, so it matches this kernel by construction.
if [ ! -x "$KSUD" ]; then
	SEED=/product/app/KernelSUNext/lib/arm64/libksud.so
	[ -f "$SEED" ] || { log "[FAILED] No ksud and no $SEED to seed it from."; exit 0; }
	cp "$SEED" "$KSUD" && chmod 755 "$KSUD" || { log "[FAILED] Could not seed ksud."; exit 0; }
	log "[SEEDED KSUD] Copied from $SEED."
fi

# Modules that are already live, i.e. merged by KernelSU at boot (an `update`
# marker means installed but still waiting for the activation reboot).
active=0
pending_ids=""
for moddir in /data/adb/modules/*/; do
	[ -f "$moddir/module.prop" ] || continue
	id=${moddir%/}
	id=${id##*/}
	if [ -f "$moddir/update" ]; then
		pending_ids="$pending_ids $id"
	else
		active=$((active + 1))
	fi
done
log "[MODULES ACTIVE] $active active${pending_ids:+, waiting for reboot:$pending_ids}"

# `ksud module install` refuses with "Android is Booting!" until boot completes.
# ksud starts service.d scripts well before that, so wait here.
log "[WAITING] Monitoring sys.boot_completed..."
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 60 ]; do
	sleep 2
	i=$((i + 1))
done
if [ "$(getprop sys.boot_completed)" = "1" ]; then
	log "[SYSTEM READY] Android has booted to UI/Setup Wizard stage."
else
	log "[TIMEOUT] sys.boot_completed not set after 120s; trying anyway."
fi

mkdir -p "$STATE" || exit 0

# Optional: pre-grant root to the apps in a snapshot of KernelSU's allowlist,
# so a wiped device does not need the grant tapped in by hand. The file is the
# ROM's own snapshot of /data/adb/ksu/.allowlist (magic "USK", per-uid entries);
# ship it only in builds where that is wanted -- it grants root to whatever is
# in it, com.android.shell included, which means anyone with adb access.
#
# Seeded only when nothing has been granted yet, so a later grant made through
# the manager is never clobbered. ksud reads the allowlist at startup, so this
# takes effect on the next boot -- which is the boot this script triggers
# anyway after installing modules.
SEED_ALLOWLIST="$SRC/shell-root.allowlist"
if [ -f "$SEED_ALLOWLIST" ] && [ ! -f "$STATE/allowlist.done" ]; then
	if ! grep -qa "com.android.shell" /data/adb/ksu/.allowlist 2>/dev/null; then
		mkdir -p /data/adb/ksu
		if cp "$SEED_ALLOWLIST" /data/adb/ksu/.allowlist &&
			chmod 644 /data/adb/ksu/.allowlist; then
			: > "$STATE/allowlist.done"
			log "[ALLOWLIST] Seeded KSU allowlist from $SEED_ALLOWLIST."
		else
			log "[FAILED] Could not seed KSU allowlist."
		fi
	else
		# Already granted: leave it alone and stop reconsidering it.
		: > "$STATE/allowlist.done"
	fi
fi

# prop FILE KEY: a module.prop value. zprop ZIP KEY: the same from inside a zip.
prop() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1 | tr -d '\r'; }
zprop() { unzip -p "$1" module.prop 2>/dev/null | sed -n "s/^$2=//p" | head -n 1 | tr -d '\r'; }
isnum() { case "$1" in ''|*[!0-9]*) return 1;; esac; }
# Installed versionCode of a module id: a staged update counts over the live one.
instvc() {
	if [ -f "/data/adb/modules_update/$1/module.prop" ]; then
		prop "/data/adb/modules_update/$1/module.prop" versionCode
	elif [ -f "/data/adb/modules/$1/module.prop" ]; then
		prop "/data/adb/modules/$1/module.prop" versionCode
	fi
}

# Action markers from the script before the version check are empty: they
# count as done for the version live now, before any upgrade below is staged.
for id in tricky_store bindhosts; do
	m="$STATE/action-$id.done"
	[ -f "$m" ] && [ ! -s "$m" ] &&
		prop "/data/adb/modules/$id/module.prop" versionCode > "$m"
done

installed=0
upgraded=0
total=0
for zip in "$SRC"/*.zip; do
	[ -f "$zip" ] || continue
	total=$((total + 1))
	# Phones set up by the filename-only script have <name>.done but no id
	# marker yet: adopt it, so a module the user removed stays removed.
	zid=$(zprop "$zip" id)
	[ -n "$zid" ] && [ -f "$STATE/${zip##*/}.done" ] && [ ! -f "$STATE/id-$zid.done" ] &&
		: > "$STATE/id-$zid.done"
done
# KSU-Next 3.4 ksud scans each zip against a downloaded risk catalog and, on
# a Low/Medium hit, waits 5 s for a volume-down press, else aborts the install
# (AlwaysStrong is flagged Medium). Nobody is there to press it, so pause the
# check for these installs and put it back afterwards. Older ksud has no
# `module risk`: status prints nothing and the check is left alone.
risk_was=$("$KSUD" module risk status 2>/dev/null)
[ "$risk_was" = Enabled ] && "$KSUD" module risk disable > /dev/null 2>&1
# Several passes: installing a metamodule (Hybrid-Mount) resets sys.boot_completed
# to 0, so every install queued behind it fails with "Android is Booting!" until
# the prop comes back. Filename order puts the metamodule last (30-), and these
# passes recover anything that still lost the race.
pass_no=1
while [ "$pass_no" -le 3 ]; do
	pending=0
	for zip in "$SRC"/*.zip; do
		[ -f "$zip" ] || continue
		name=${zip##*/}
		zid=$(zprop "$zip" id)
		zvc=$(zprop "$zip" versionCode)
		if [ -n "$zid" ] && isnum "$zvc"; then
			ivc=$(instvc "$zid")
			if [ -z "$ivc" ]; then
				# Not installed: first time, or removed by the user.
				[ -f "$STATE/id-$zid.done" ] && continue
				what=INSTALLING
			elif isnum "$ivc" && [ "$ivc" -lt "$zvc" ]; then
				[ -f "/data/adb/modules/$zid/remove" ] && continue
				what=UPGRADING
			else
				# Same or newer already installed (the user may have updated it).
				: > "$STATE/$name.done"
				: > "$STATE/id-$zid.done"
				continue
			fi
		else
			[ -f "$STATE/$name.done" ] && continue
			what=INSTALLING
		fi

		# The prop may have been reset by a metamodule install in this pass.
		i=0
		while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 30 ]; do
			sleep 2
			i=$((i + 1))
		done

		if [ "$what" = UPGRADING ]; then
			log "[UPGRADING] $name ($zid versionCode $ivc -> $zvc, pass $pass_no)..."
		else
			log "[INSTALLING] $name (pass $pass_no)..."
		fi
		# ksud's own output goes to the log indented, so the tagged lines
		# stay easy to scan.
		"$KSUD" module install "$zip" > "$OUT" 2>&1
		rc=$?
		sed 's/^/        | /' "$OUT" >> "$LOG"
		if [ "$rc" -eq 0 ]; then
			: > "$STATE/$name.done"
			[ -n "$zid" ] && : > "$STATE/id-$zid.done"
			if [ "$what" = INSTALLING ]; then
				installed=$((installed + 1))
			else
				upgraded=$((upgraded + 1))
				upgraded_names="${upgraded_names:+$upgraded_names, }$(zprop "$zip" name) $(zprop "$zip" version)"
			fi
			log "[INSTALLED] $name"
		else
			# No marker: retried in the next pass, then on the next boot.
			log "[FAILED] $name (pass $pass_no, exit $rc)"
			pending=$((pending + 1))
		fi
	done
	[ "$pending" -eq 0 ] && break
	pass_no=$((pass_no + 1))
done
rm -f "$OUT"
[ "$risk_was" = Enabled ] && "$KSUD" module risk enable > /dev/null 2>&1

# ksu-snapshot.sh staged the ROM's module snapshot at post-fs-data this boot,
# the same state zip installs leave: they go live on the next boot, so count
# them as installed and take the same single reboot below.
if [ -f "$STATE/snapshot.reboot" ]; then
	rm -f "$STATE/snapshot.reboot"
	n=$(ls /data/adb/modules_update 2>/dev/null | wc -l)
	installed=$((installed + n))
	total=$((total + n))
	log "[SNAPSHOT] $n modules staged from the ROM snapshot at post-fs-data."
fi

# Boot scripts shipped alongside the zips. They are not modules and not
# installed anywhere; they are executed from here, detached, on every boot --
# which is what they expect anyway (ksu_script.sh sleeps, then bind-mounts over
# /product/app once the framework is up).
#
# Each runs from /data/adb/<name>, not from /product, so it can be edited on the
# device and tested without rebuilding the ROM. The ROM copy only seeds it when
# missing, so an edit survives reboots; delete /data/adb/<name> to go back to
# the ROM version on the next boot.
for src in "$SRC"/scripts/*.sh; do
	[ -f "$src" ] || continue
	run=/data/adb/${src##*/}
	if [ ! -f "$run" ]; then
		cp "$src" "$run" || continue
		log "[BOOT SCRIPT] Seeded $run from ROM."
	fi
	log "[BOOT SCRIPT] Running $run"
	if command -v setsid >/dev/null 2>&1; then
		setsid sh "$run" </dev/null >>"$LOG" 2>&1 &
	else
		sh "$run" </dev/null >>"$LOG" 2>&1 &
	fi
done

# Some modules only configure themselves when their Action is run -- AlwaysStrong
# fetches and refreshes the keybox and fingerprint that way. A module is only
# active after the reboot following its install, so this runs on a later boot,
# once the module directory exists and carries an action.sh. Called after the
# zygote restart below.
run_actions() {
	# ctl.restart zygote restarts the framework; ksud refuses module commands
	# with "Android is Booting!" until sys.boot_completed is back.
	i=0
	while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 60 ]; do
		sleep 2
		i=$((i + 1))
	done
	# Only modules whose action is setup, by module id (the directory name,
	# not the display name): AlwaysStrong installs as tricky_store. Others'
	# actions are one-off tools -- errlog's restarts its capture, which its
	# own post-fs-data.sh/service.sh already start every boot.
	# Both actions download (AlwaysStrong its fingerprint, bindhosts its host
	# lists), and after the zygote restart Wi-Fi reconnects from scratch.
	i=0
	until /system/bin/ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || [ "$i" -ge 60 ]; do
		sleep 2
		i=$((i + 1))
	done
	if [ "$i" -ge 60 ]; then
		log "[NO NETWORK] Still offline after 120s; running actions anyway."
	else
		log "[NETWORK] Online."
	fi
	for id in tricky_store bindhosts; do
		moddir=/data/adb/modules/$id
		[ -f "$moddir/action.sh" ] || continue
		[ -f "$moddir/disable" ] && continue
		[ -f "$moddir/remove" ] && continue
		# An upgrade staged this boot is not live yet, but ksud already copied
		# its module.prop over the live one and flagged it "update": wait for
		# the reboot, or the old action runs and the new version is marked done.
		[ -f "$moddir/update" ] && continue
		[ -d "/data/adb/modules_update/$id" ] && continue
		# The marker holds the versionCode the action last ran for, so a
		# module upgrade runs it once more.
		vc=$(prop "$moddir/module.prop" versionCode)
		if [ -f "$STATE/action-$id.done" ]; then
			[ "$(cat "$STATE/action-$id.done")" = "$vc" ] && continue
			done_vc=$(cat "$STATE/action-$id.done")
			log "[ACTION] $id changed from versionCode $done_vc to $vc."
		fi

		log "[ACTION] Running action for $id..."
		"$KSUD" module action "$id" > "$OUT" 2>&1
		rc=$?
		# bindhosts exits 0 even when every download failed.
		grep -q "all downloads failed" "$OUT" && rc=1
		sed 's/^/        | /' "$OUT" >> "$LOG"
		if [ "$rc" -eq 0 ]; then
			echo "$vc" > "$STATE/action-$id.done"
			log "[ACTION DONE] $id"
		else
			# No marker: AlwaysStrong's action needs network, so let it retry.
			log "[FAILED] Action for $id (exit $rc)"
		fi
	done
	rm -f "$OUT"
}

# TEST: the one automatic full reboot (below) now happens as soon as the
# modules are installed, before setup wizard. Zygisk has still needed another
# reboot after the wizard, so on the boot after that full reboot, restart
# zygote once when the wizard finishes, to see whether that alone is enough.
# Once per wipe (marker .zygote_restarted).
# /system/bin/ps explicitly: ksud runs this under busybox sh in standalone
# mode, where a bare `ps` is busybox's, which has no -A or -o NAME.
zygisk_ps() {
	/system/bin/ps -A -o NAME 2>/dev/null | grep -i zygisk | tr '\n' ' '
}
if [ "$installed" -eq 0 ] && [ -f "$STATE/.rebooted" ] && [ ! -f "$STATE/.zygote_restarted" ]; then
	log "[WAITING] Waiting for Setup Wizard to finish before zygote restart..."
	while [ "$(settings get global device_provisioned 2>/dev/null)" != "1" ]; do
		sleep 3
	done
	log "[SETUP DONE] Setup Wizard complete."
	: > "$STATE/.zygote_restarted"
	log "[ZYGOTE RESTART] setprop ctl.restart zygote (zygisk processes before: $(zygisk_ps))"
	setprop ctl.restart zygote
	sleep 30
	log "[ZYGOTE RESTART] Done (zygisk processes after 30s: $(zygisk_ps))"
	run_actions
	exit 0
fi

if [ "$installed" -eq 0 ]; then
	# Retry any action that failed on an earlier boot (e.g. no network yet),
	# and run the action of a module that was upgraded since.
	[ -f "$STATE/.zygote_restarted" ] && run_actions
	if [ "$upgraded" -gt 0 ]; then
		# No automatic reboot for an upgrade on a set-up phone: it already
		# had its one, and the user may be using it.
		log "[UPGRADES STAGED] $upgraded module upgrade(s); they activate on the next reboot."
		# Tell the user, who otherwise has no way to know a reboot is needed.
		# Posted under the shell's notification channel; swiped away like any
		# other, and gone after the reboot.
		cmd notification post -S bigtext -t "Reboot to finish module update" \
			ksu-autoinstall "$upgraded_names updated. Reboot to activate." \
			> /dev/null 2>&1 && log "[NOTIFIED] Reboot needed for: $upgraded_names"
	else
		log "[NOTHING TO DO] All $total module zips installed and up to date."
	fi
	exit 0
fi
log "[MODULES STAGED] $installed of $total installed this boot; they activate on the next full boot."

if [ "$REBOOT" != "1" ]; then
	log "[NO REBOOT] persist.ksu_ai_reboot is not 1; reboot by hand to activate."
	exit 0
fi
# Never reboot out from under setup wizard: boot_completed fires long before the
# user finishes it. Waiting costs nothing -- this runs again on the next boot.
# [ "$(settings get secure user_setup_complete 2>/dev/null)" = "1" ] || exit 0
# Guard against a reboot loop if a module somehow fails to mark itself done.
if [ -f "$STATE/.rebooted" ]; then
	log "[NO REBOOT] Already auto-rebooted once ($STATE/.rebooted); reboot by hand."
	exit 0
fi

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

: > "$STATE/.rebooted"
log "[REBOOT CMD] Full reboot to activate $installed module(s) (not waiting for setup wizard)!"
setprop sys.powerctl reboot,ksu-autoinstall
exit 0

# Unreachable while the immediate reboot above is active; kept until the test
# settles which design stays.

# Loop until Setup Wizard is completed
log "[WAITING] Waiting for Setup Wizard to finish before rebooting..."
while true; do
    PROVISIONED=$(settings get global device_provisioned 2>/dev/null)
    if [ "$PROVISIONED" = "1" ]; then
        break
    fi
    sleep 3
done
log "[SETUP DONE] Setup Wizard complete."

# Setup Wizard is complete!
# Optional: Trigger any background module staging cleanup if needed by KSU
# Instead of a full hard reboot which looks ugly, restart the Android Framework (Soft Reboot)
# This forces Zygote to completely restart and instantly load your Zygisk modules!
#
# NOT ENOUGH: a zygote restart leaves the new modules staged in
# /data/adb/modules_update -- KernelSU only merges them, and ReZygisk only
# starts, during a full boot. Userspace reboot (reboot,userspace) is ignored on
# Android 16 ("Userspace reboot is deprecated").
#setprop ctl.restart zygote

# Marked only now, so a reboot before setup finished does not use up the one
# automatic reboot.
: > "$STATE/.rebooted"
log "[REBOOT CMD] Full reboot to activate $installed module(s)!"
setprop sys.powerctl reboot,ksu-autoinstall
) </dev/null >>/data/adb/ksu-autoinstall.log 2>&1 &
