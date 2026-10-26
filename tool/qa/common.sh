#!/usr/bin/env bash
# Shared helpers of the QA battery (docs/qa.md). Sourced by release_smoke.sh and
# run_battery.sh; works in Git Bash on Windows and on macOS.
#
# Rule of this file: only the emulator whose AVD name is $QA_AVD is ever
# touched. Emulators of other projects may be running: they are never
# started, stopped or addressed. Every adb call uses `-s <serial>`.

# Git Bash would rewrite /sdcard/... arguments of adb into C:/Program Files/Git/...
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

QA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QA_APP="$QA_ROOT/app"
QA_OUT="${QA_OUT:-$QA_APP/build/qa}"          # app/build/ is git-ignored
QA_AVD="${QA_AVD:-Apto_Armas}"
QA_PACKAGE="es.leyalblanco.app"

# Exit codes shared by the scripts.
QA_RC_OK=0
QA_RC_FAIL=1   # a check failed (the app or a test is wrong)
QA_RC_ENV=2    # the environment is wrong (no adb, emulator did not boot, build failed)

qa_log() { printf '[qa] %s\n' "$*" >&2; }
qa_die() { qa_log "ERROR: $*"; exit "${2:-$QA_RC_ENV}"; }

# Windows paths (C:\...) to POSIX ones when cygpath exists (Git Bash).
qa_posix() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s' "$1"; fi
}

# POSIX path to the form native Windows programs (adb.exe) understand.
qa_native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# --- tools -------------------------------------------------------------------

qa_sdk_dir() {
  local c
  for c in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" \
           "${LOCALAPPDATA:+$(qa_posix "$LOCALAPPDATA")/Android/Sdk}" \
           "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
    [ -n "$c" ] || continue
    c="$(qa_posix "$c")"
    [ -d "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

qa_find_tools() {
  local sdk=""
  sdk="$(qa_sdk_dir)" || true
  ADB="$(command -v adb 2>/dev/null || true)"
  [ -z "$ADB" ] && [ -n "$sdk" ] && for f in "$sdk/platform-tools/adb" "$sdk/platform-tools/adb.exe"; do
    [ -x "$f" ] && ADB="$f" && break
  done
  EMULATOR="$(command -v emulator 2>/dev/null || true)"
  [ -z "$EMULATOR" ] && [ -n "$sdk" ] && for f in "$sdk/emulator/emulator" "$sdk/emulator/emulator.exe"; do
    [ -x "$f" ] && EMULATOR="$f" && break
  done
  [ -n "$ADB" ] || qa_die "adb not found (install platform-tools or set ANDROID_HOME)"
  export ADB EMULATOR
}

# Runs "$@" with a time limit of $1 seconds (macOS has no `timeout`). Prints
# the command's stdout; returns its status, or 124 on timeout.
qa_timeout() {
  local secs="$1"; shift
  local out; out="$(mktemp)"
  "$@" >"$out" 2>/dev/null &
  local pid=$!
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge $((secs * 5)) ]; then
      kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
      cat "$out"; rm -f "$out"; return 124
    fi
    sleep 0.2; i=$((i + 1))
  done
  wait "$pid"; local rc=$?
  cat "$out"; rm -f "$out"; return "$rc"
}

# --- the Apto_Armas emulator -------------------------------------------------

# `adb devices` without the CRs that adb.exe prints.
qa_devices() { "$ADB" devices | tr -d '\r'; }

# adb state of a serial: device | offline | unauthorized | ...
qa_state() { qa_devices | awk -v s="$1" '$1==s {print $2}'; }

# Prints the serial of the emulator whose AVD name is $QA_AVD ("" if none).
# Offline emulators cannot answer `emu avd name` and are skipped.
qa_find_serial() {
  local s name
  for s in $(qa_devices | awk '/^emulator-[0-9]+/ && $2=="device" {print $1}'); do
    name="$(qa_timeout 10 "$ADB" -s "$s" emu avd name | head -1 | tr -d '\r')"
    if [ "$name" = "$QA_AVD" ]; then printf '%s' "$s"; return 0; fi
  done
  return 1
}

# Serials in the "offline" state (candidates for a stuck $QA_AVD).
qa_offline_serials() { qa_devices | awk '/^emulator-[0-9]+/ && $2=="offline" {print $1}'; }

# Waits until sys.boot_completed=1 and the package manager answers.
qa_wait_boot() {
  local serial="$1" limit="${2:-300}" i=0 v
  while [ "$i" -lt "$limit" ]; do
    v="$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [ "$v" = "1" ] && "$ADB" -s "$serial" shell pm path android >/dev/null 2>&1; then
      return 0
    fi
    sleep 2; i=$((i + 2))
  done
  return 1
}

# Makes sure $QA_AVD is booted and sets QA_SERIAL. Starts it when it is not
# running. Never touches another emulator.
qa_ensure_emulator() {
  qa_find_tools
  mkdir -p "$QA_OUT"
  if [ -n "${QA_SERIAL:-}" ]; then
    qa_log "using QA_SERIAL=$QA_SERIAL"
    qa_wait_boot "$QA_SERIAL" 120 || qa_die "$QA_SERIAL did not finish booting"
    return 0
  fi
  if QA_SERIAL="$(qa_find_serial)"; then
    qa_log "$QA_AVD is online as $QA_SERIAL"
    qa_wait_boot "$QA_SERIAL" 300 || qa_die "$QA_SERIAL did not finish booting"
    export QA_SERIAL; return 0
  fi
  QA_SERIAL=""

  # An offline emulator might be ours, stuck. Wait a little for it.
  local s waited=0 stuck=""
  stuck="$(qa_offline_serials | head -1)"
  while [ -n "$stuck" ] && [ "$waited" -lt 40 ]; do
    sleep 4; waited=$((waited + 4))
    if QA_SERIAL="$(qa_find_serial)"; then
      qa_log "$QA_AVD came online as $QA_SERIAL"
      qa_wait_boot "$QA_SERIAL" 300 || qa_die "$QA_SERIAL did not finish booting"
      export QA_SERIAL; return 0
    fi
    QA_SERIAL=""
    stuck="$(qa_offline_serials | head -1)"
  done
  for s in $(qa_offline_serials); do
    local name; name="$(qa_timeout 10 "$ADB" -s "$s" emu avd name | head -1 | tr -d '\r')"
    if [ "$name" = "$QA_AVD" ]; then
      qa_log "$s is a stuck $QA_AVD: killing only that one"
      "$ADB" -s "$s" emu kill >/dev/null 2>&1 || true
      sleep 5
    fi
  done

  [ -n "${EMULATOR:-}" ] || qa_die "emulator binary not found: start the AVD $QA_AVD by hand"
  qa_log "starting $QA_AVD (first boot can take a few minutes)"
  # Always a cold boot: a quick-boot snapshot left by an abrupt shutdown can
  # hang the emulator "offline" for good (seen 2026-10-19). ~1 min slower.
  # Headless by default (less RAM, nothing to look at during the battery);
  # QA_WINDOW=1 shows the window.
  local window_flag="-no-window"
  [ "${QA_WINDOW:-0}" = "1" ] && window_flag=""
  # shellcheck disable=SC2086
  nohup "$EMULATOR" -avd "$QA_AVD" $window_flag -no-snapshot-load -no-boot-anim -netdelay none -netspeed full \
    >"$QA_OUT/emulator.log" 2>&1 &
  disown 2>/dev/null || true
  local i=0
  while [ "$i" -lt 300 ]; do
    if QA_SERIAL="$(qa_find_serial)"; then break; fi
    QA_SERIAL=""; sleep 3; i=$((i + 3))
  done
  [ -n "$QA_SERIAL" ] || qa_die "$QA_AVD did not appear in adb within 5 minutes (see $QA_OUT/emulator.log)"
  qa_wait_boot "$QA_SERIAL" 300 || qa_die "$QA_SERIAL did not finish booting"
  # Wake and unlock the screen (the emulator has no lock screen configured).
  "$ADB" -s "$QA_SERIAL" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  qa_log "$QA_AVD booted as $QA_SERIAL"
  export QA_SERIAL
}

qa_screenshot() { # serial out.png
  "$ADB" -s "$1" exec-out screencap -p >"$2" 2>/dev/null
}

# --- Gradle -------------------------------------------------------------------

# PIDs of the running Gradle daemons, one per line, sorted.
qa_gradle_daemon_pids() {
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.Name -like 'java*' -and \$_.CommandLine -like '*GradleDaemon*' } | ForEach-Object { \$_.ProcessId }" 2>/dev/null | tr -d '\r'
  else
    pgrep -f GradleDaemon 2>/dev/null
  fi | grep -E '^[0-9]+$' | sort -u
}

# Remembers which daemons existed before our builds. Exported so the nested
# release_smoke.sh of the battery keeps the battery's list.
qa_gradle_mark() {
  [ -n "${QA_GRADLE_BEFORE+x}" ] && return 0
  QA_GRADLE_BEFORE="$(qa_gradle_daemon_pids | tr '\n' ' ')"
  export QA_GRADLE_BEFORE
}

# True when the daemon's own log shows it built this app and no other project.
# A daemon that appeared during our build may belong to another session (seen
# 2026-10-24: a murmur-flutter daemon), and daemons are shared between
# projects with the same Gradle version and JVM arguments.
qa_gradle_daemon_is_ours() {
  local log
  log="$(ls "${GRADLE_USER_HOME:-$HOME/.gradle}"/daemon/*/daemon-"$1".out.log 2>/dev/null | head -1)"
  [ -n "$log" ] || return 1
  # Every build the daemon ran is logged as "currentDir=<dir>,". (No `grep -i`
  # here: Git Bash's grep aborts on -i with these patterns.)
  local ours dirs
  ours="currentDir=$(qa_native "$QA_APP/android" | tr '/' '\\')"
  dirs="$(LC_ALL=C grep -aoE 'currentDir=[^,}]*' "$log" | sort -u)"
  [ -n "$dirs" ] && [ "$dirs" = "$ours" ]
}

# Stops only our Gradle daemons, by PID: those that appeared after
# qa_gradle_mark and only built this app. Never `gradlew --stop`: it stops the
# daemons of every session on the machine (other projects and agents build in
# parallel). Set QA_NO_GRADLE_STOP=1 to keep them.
qa_gradle_stop() {
  [ -n "${QA_NO_GRADLE_STOP:-}" ] && return 0
  [ -n "${QA_GRADLE_BEFORE+x}" ] || { qa_log "no Gradle baseline: not stopping any daemon"; return 0; }
  local p
  for p in $(qa_gradle_daemon_pids); do
    case " $QA_GRADLE_BEFORE " in *" $p "*) continue ;; esac
    if ! qa_gradle_daemon_is_ours "$p"; then
      qa_log "Gradle daemon $p is new but not only ours: left running"
      continue
    fi
    qa_log "stopping our Gradle daemon (pid $p)"
    if command -v taskkill >/dev/null 2>&1; then
      # MSYS_NO_PATHCONV=1 (top of this file) passes /PID through unchanged.
      taskkill /PID "$p" /T /F >/dev/null 2>&1 || true
    else
      kill "$p" 2>/dev/null || true
    fi
  done
}

# True when a log shows a Gradle infrastructure failure (a daemon stopped by
# someone else's `gradlew --stop`, a half-written transform cache), not a real
# compile error: worth one retry.
qa_gradle_flaky() {
  grep -qE "Gradle build daemon has been stopped|Could not find implementation class|Could not connect to the Gradle daemon|Timeout waiting to lock" "$1" 2>/dev/null
}
