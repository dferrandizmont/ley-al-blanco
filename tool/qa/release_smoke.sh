#!/usr/bin/env bash
# Release smoke test: installs the R8-minified, obfuscated release APK on the
# Apto_Armas emulator, opens it and checks it really reaches the first screen.
#
# Why: the tests and the debug/profile builds never go through R8. A plugin
# that Dart calls by JNI (shared_preferences, path_provider) can be stripped
# there and the release then hangs on the loading screen with a
# NoSuchMethodError (docs/release-signing.md section 7).
#
# Usage:
#   tool/qa/release_smoke.sh                  # build the test APK, then check it
#   tool/qa/release_smoke.sh path/to/app.apk  # check an existing APK
#   tool/qa/release_smoke.sh --out DIR --wait 8 --abi arm64|x64
#
# Options (environment variables in brackets):
#   --out DIR     where the evidence goes   [QA_OUT/smoke, default app/build/qa/smoke]
#   --wait SECS   pause before the first look [QA_SMOKE_WAIT, default 8]
#   --abi ABI     arm64 (default) or x64. arm64 falls
#                 back to x64 on an emulator that cannot run arm64.
#   QA_SERIAL     use this adb serial instead of looking for the Apto_Armas AVD
#   QA_NO_GRADLE_STOP=1   keep the Gradle daemons our builds started
#
# Evidence in DIR: first-screen.png, ui-dump.xml, logcat-errors.txt
# (`adb logcat -d -s flutter:E AndroidRuntime:E`), logcat-full.txt, summary.txt.
#
# Exit codes: 0 = the app opened and showed Inicio; 1 = the app is broken
# (error in the log, first screen missing, process dead); 2 = the environment
# failed (no emulator, build or install failed).
set -u
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

qa_gradle_mark   # daemons that exist now are not ours
APK=""
OUT="$QA_OUT/smoke"
WAIT="${QA_SMOKE_WAIT:-8}"
ABI="${QA_APK_ABI:-arm64}"
while [ $# -gt 0 ]; do
  case "$1" in
    --out)  OUT="$2"; shift 2 ;;
    --wait) WAIT="$2"; shift 2 ;;
    --abi)  ABI="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
    -*) qa_die "unknown option $1" ;;
    *)  APK="$1"; shift ;;
  esac
done
mkdir -p "$OUT"
BUILT=0
finish() { if [ "$BUILT" = 1 ] && [ -z "${QA_SKIP_GRADLE_STOP:-}" ]; then qa_gradle_stop; fi; }
trap finish EXIT

# A local smoke build must not use the owner's upload key implicitly.
if [ -z "$APK" ] && [ -e "$QA_APP/android/key.properties" ]; then
  qa_die "local smoke builds require android/key.properties to be absent (see docs/release-signing.md section 8)"
fi

qa_ensure_emulator
SERIAL="$QA_SERIAL"
adb_() { "$ADB" -s "$SERIAL" "$@"; }

# --- the APK -------------------------------------------------------------------
if [ -z "$APK" ]; then
  # arm64 needs an emulator that lists it (x86_64 images with ARM translation).
  abilist="$(adb_ shell getprop ro.product.cpu.abilist | tr -d '\r')"
  if [ "$ABI" = "arm64" ] && ! printf '%s' "$abilist" | grep -q 'arm64-v8a'; then
    qa_log "the emulator ABIs are '$abilist': building x64 instead of arm64"
    ABI=x64
  fi
  case "$ABI" in
    arm64) PLATFORM=android-arm64; OUT_APK=app-arm64-v8a-release.apk ;;
    x64)   PLATFORM=android-x64;   OUT_APK=app-x86_64-release.apk ;;
    *) qa_die "unknown --abi $ABI (arm64 or x64)" ;;
  esac
  # Same local build as docs/release-signing.md section 8:
  # machine's Android debug key, no store keys, obfuscated.
  BUILD_LOG="$OUT/build.log"
  build() {
    ( cd "$QA_APP" && flutter build apk --release \
        --target-platform "$PLATFORM" --split-per-abi \
        -PallowDebugSigning=true \
        --obfuscate --split-debug-info=build/symbols/qa-smoke ) >"$BUILD_LOG" 2>&1
  }
  qa_log "building the $ABI release test APK (several minutes the first time)"
  BUILT=1
  if ! build; then
    if qa_gradle_flaky "$BUILD_LOG"; then
      qa_log "Gradle infrastructure failure (a daemon was stopped?): retrying once"
      sleep 5; build || qa_die "release build failed, see $BUILD_LOG"
    else
      tail -25 "$BUILD_LOG" >&2
      qa_die "release build failed, see $BUILD_LOG"
    fi
  fi
  APK="$QA_APP/build/app/outputs/flutter-apk/$OUT_APK"
fi
[ -f "$APK" ] || qa_die "APK not found: $APK"
qa_log "APK: $APK ($(wc -c <"$APK" | tr -d ' ') bytes)"

# --- install and launch ----------------------------------------------------------
adb_ uninstall "$QA_PACKAGE" >/dev/null 2>&1 || true
if ! adb_ install -r "$(qa_native "$APK")" >"$OUT/install.log" 2>&1 || ! grep -q Success "$OUT/install.log"; then
  cat "$OUT/install.log" >&2
  qa_die "adb install failed"
fi
adb_ logcat -c >/dev/null 2>&1 || true
adb_ shell am force-stop "$QA_PACKAGE" >/dev/null 2>&1 || true
adb_ shell monkey -p "$QA_PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
  || qa_die "could not launch $QA_PACKAGE"
qa_log "launched; waiting ${WAIT}s"
sleep "$WAIT"

# --- did the first screen render? --------------------------------------------------
# uiautomator reads Flutter's semantics tree. The first dump can come back empty
# (semantics are switched on by the dump itself), and the first launch imports
# the 423 questions, so retry for up to 60 more seconds.
#
# If another tool already holds the UiAutomation connection (e.g. a mobile-mcp
# session driving this emulator), every dump fails with "UiAutomationService
# ... already registered". Then fall back to checking that our activity is the
# resumed one, and say so (UI_OK=2: foreground only, texts not read).
UI_OK=0
UI_BUSY=0
DUMP_FAILS=0
for _ in $(seq 1 30); do
  adb_ shell rm -f /sdcard/qa_smoke_ui.xml >/dev/null 2>&1 || true
  adb_ shell uiautomator dump /sdcard/qa_smoke_ui.xml >"$OUT/ui-dump.log" 2>&1 || true
  adb_ exec-out cat /sdcard/qa_smoke_ui.xml >"$OUT/ui-dump.xml" 2>/dev/null || true
  if grep -q 'Ley al Blanco' "$OUT/ui-dump.xml" && grep -q 'Simulacro' "$OUT/ui-dump.xml"; then
    UI_OK=1; break
  fi
  # A working uiautomator says "UI hierchary dumped to ..." (sic). When another
  # tool holds the connection it crashes, often without printing anything.
  if grep -q 'dumped to' "$OUT/ui-dump.log"; then
    DUMP_FAILS=0
  else
    DUMP_FAILS=$((DUMP_FAILS + 1))
    if [ "$DUMP_FAILS" -ge 3 ]; then UI_BUSY=1; break; fi
  fi
  sleep 2
done
if [ "$UI_OK" != 1 ] && [ "$UI_BUSY" = 1 ]; then
  sleep 5
  if adb_ shell dumpsys activity activities 2>/dev/null | tr -d '\r' \
      | grep -E 'ResumedActivity' | grep -q "$QA_PACKAGE"; then
    UI_OK=2
  fi
fi
adb_ shell rm -f /sdcard/qa_smoke_ui.xml >/dev/null 2>&1 || true
qa_screenshot "$SERIAL" "$OUT/first-screen.png"

# --- logs ---------------------------------------------------------------------------
# Only OUR errors count (uiautomator and system apps crash too):
#  - the app's own log, at error level (current pid);
#  - crash-buffer blocks whose "Process:" line names our package (a crash
#    that killed an earlier pid of the app).
PID="$(adb_ shell pidof "$QA_PACKAGE" 2>/dev/null | tr -d '\r' | tr -d ' ')"
adb_ logcat -d 2>/dev/null | tr -d '\r' >"$OUT/logcat-full.txt"
: >"$OUT/logcat-errors.txt"
if [ -n "$PID" ]; then
  adb_ logcat -d --pid="$PID" '*:E' 2>/dev/null | tr -d '\r' >"$OUT/logcat-errors.txt"
fi
adb_ logcat -d -b crash 2>/dev/null | tr -d '\r' \
  | grep -B1 -A30 "Process: $QA_PACKAGE" >>"$OUT/logcat-errors.txt" || true
FINDINGS="$(grep -E "NoSuchMethodError|ClassNotFoundException|FATAL EXCEPTION|Unhandled Exception|Process: $QA_PACKAGE" "$OUT/logcat-errors.txt" || true)"

# --- verdict ---------------------------------------------------------------------------
RC=0
{
  echo "APK:        $APK"
  echo "Emulator:   $SERIAL ($QA_AVD)"
  echo "Screenshot: $OUT/first-screen.png"
  echo "Log errors: $(grep -c . "$OUT/logcat-errors.txt") line(s) in $OUT/logcat-errors.txt"
} >"$OUT/summary.txt"

if [ -n "$FINDINGS" ]; then
  RC=$QA_RC_FAIL
  { echo "FAIL: errors in the log:"; printf '%s\n' "$FINDINGS" | head -20; } | tee -a "$OUT/summary.txt" >&2
fi
if [ "$UI_OK" = 2 ]; then
  echo "WARN: uiautomator was busy (another tool holds it): only checked that the app is in the foreground; look at first-screen.png" \
    | tee -a "$OUT/summary.txt" >&2
elif [ "$UI_OK" != 1 ]; then
  RC=$QA_RC_FAIL
  echo "FAIL: the first screen did not show 'Ley al Blanco' and 'Simulacro' (ui-dump.xml, first-screen.png)" \
    | tee -a "$OUT/summary.txt" >&2
fi
if [ -z "$PID" ]; then
  RC=$QA_RC_FAIL
  echo "FAIL: the app process is not running (it died)" | tee -a "$OUT/summary.txt" >&2
fi
if [ "$RC" = 0 ]; then
  echo "PASS: the release app opened and showed Inicio (pid $PID)" | tee -a "$OUT/summary.txt" >&2
fi
exit "$RC"
