#!/usr/bin/env bash
# The pre-release QA battery, in one command (docs/qa.md):
#
#   1. unit and widget tests          flutter test
#   2. end-to-end scenarios           flutter test integration_test -d <Apto_Armas>
#   3. release smoke (R8 build)       tool/qa/release_smoke.sh
#
# Boots the Apto_Armas emulator when it is not running (never touches any other
# emulator). Prints a summary table and writes it to app/build/qa/last-run.md
# (app/build/ is git-ignored). Also in app/build/qa/: unit.log, integration.log,
# integration-summary.md, shots/<scenario>.png (screenshot of each failure),
# smoke/ (evidence of the release smoke).
#
# Options (environment variables):
#   QA_ONLY=arranque,ajustes     only these scenarios (a name also selects its
#                                family: ajustes -> ajustes_tema, ...)
#   QA_SKIP=ajustes              leave these scenarios out
#   QA_STAGES=unit,integration,smoke   which stages to run (default: all)
#   QA_SERIAL=emulator-5554      use this adb serial
#   QA_NO_GRADLE_STOP=1          keep the Gradle daemons our builds started
#   QA_WINDOW=1                  show the emulator window (headless by default)
#
# Exit codes: 0 all green; 1 something failed; 2 the environment failed.
set -u
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

qa_gradle_mark   # daemons that exist now are not ours
STAGES="${QA_STAGES:-unit,integration,smoke}"
has_stage() { case ",$STAGES," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

mkdir -p "$QA_OUT/shots"
rm -f "$QA_OUT"/shots/*.png
START=$(date +%s)
SUMMARY_ROWS=()
OVERALL=0
WATCH_PID=""
WATCH_DONE="$QA_OUT/.integration-done"
cleanup() {
  : >"$WATCH_DONE" 2>/dev/null   # ends the screenshot watcher (see stage 2)
  [ -n "$WATCH_PID" ] && kill "$WATCH_PID" 2>/dev/null
  qa_gradle_stop
}
trap cleanup EXIT

row() { # stage result seconds detail
  SUMMARY_ROWS+=("| $1 | $2 | $3 s | $4 |")
  [ "$2" = "PASS" ] || [ "$2" = "SKIPPED" ] || OVERALL=1
}

# --- emulator (needed by the last two stages) ------------------------------------
if has_stage integration || has_stage smoke; then
  qa_ensure_emulator
fi
export QA_SERIAL="${QA_SERIAL:-}"

# --- 1. unit and widget tests ---------------------------------------------------------
if has_stage unit; then
  qa_log "stage 1/3: flutter test"
  t0=$(date +%s)
  ( cd "$QA_APP" && TZ="${TZ:-Europe/Madrid}" flutter test ) >"$QA_OUT/unit.log" 2>&1
  rc=$?
  last="$(tr -d '\r' <"$QA_OUT/unit.log" | grep -E '^[0-9:]+ \+[0-9]+' | tail -1)"
  passed="$(printf '%s' "$last" | sed -n 's/.*+\([0-9][0-9]*\).*/\1/p')"
  failed="$(printf '%s' "$last" | sed -n 's/.* -\([0-9][0-9]*\).*/\1/p')"
  if [ "$rc" = 0 ]; then
    row "Unit and widget tests" PASS $(( $(date +%s) - t0 )) "${passed:-?} tests"
  else
    row "Unit and widget tests" FAIL $(( $(date +%s) - t0 )) "${failed:-?} failed, ${passed:-?} passed (unit.log)"
  fi
else
  row "Unit and widget tests" SKIPPED 0 "not selected"
fi

# --- 2. integration scenarios -----------------------------------------------------------
# While flutter runs, a watcher takes a screenshot each time a scenario fails
# (the harness prints QA_SHOT|<id> and waits 3 s).
#
# It polls the log once a second instead of `tail -F | while read`: killing
# that pipeline left orphaned bash processes on Windows (Git Bash) that lived
# for hours after the battery finished. This loop ends by itself as soon as
# the integration stage drops $WATCH_DONE (cleanup() drops it too on exit).
screenshot_watcher() {
  local seen=0 total
  while [ ! -f "$WATCH_DONE" ]; do
    total=$(wc -l <"$QA_OUT/integration.log" 2>/dev/null || echo 0)
    if [ "${total:-0}" -gt "$seen" ]; then
      sed -n "$((seen + 1)),${total}p" "$QA_OUT/integration.log" | tr -d '\r' |
        grep '^QA_SHOT|' | while IFS= read -r line; do
          qa_screenshot "$QA_SERIAL" "$QA_OUT/shots/${line#QA_SHOT|}.png"
        done
      seen=$total
    fi
    sleep 1
  done
}

run_integration() {
  local defines=()
  [ -n "${QA_ONLY:-}" ] && defines+=("--dart-define=QA_ONLY=$QA_ONLY")
  [ -n "${QA_SKIP:-}" ] && defines+=("--dart-define=QA_SKIP=$QA_SKIP")
  : >"$QA_OUT/integration.log"
  ( cd "$QA_APP" && flutter test integration_test/qa_test.dart -d "$QA_SERIAL" ${defines[@]+"${defines[@]}"} ) \
    >>"$QA_OUT/integration.log" 2>&1
}

if has_stage integration; then
  qa_log "stage 2/3: integration scenarios on $QA_SERIAL (first build takes minutes)"
  t0=$(date +%s)
  : >"$QA_OUT/integration.log"
  rm -f "$WATCH_DONE"
  screenshot_watcher &
  WATCH_PID=$!
  run_integration; rc=$?
  if [ "$rc" != 0 ] && ! grep -q '^QA_START' "$QA_OUT/integration.log" && qa_gradle_flaky "$QA_OUT/integration.log"; then
    qa_log "Gradle infrastructure failure (a daemon was stopped?): retrying once"
    sleep 5; run_integration; rc=$?
  fi
  sleep 2
  : >"$WATCH_DONE"
  wait "$WATCH_PID" 2>/dev/null; WATCH_PID=""

  # Per-scenario table from the QA_START / QA_RESULT lines.
  tr -d '\r' <"$QA_OUT/integration.log" >"$QA_OUT/integration.clean.log"
  {
    echo "| Scenario | Result | Time | Detail |"
    echo "|---|---|---|---|"
    awk -F'|' '
      /^QA_START\|/  { started[$2]=1; order[++n]=$2 }
      /^QA_RESULT\|/ { res[$2]=$3; ms[$2]=$4; detail[$2]=$5 }
      END {
        for (i=1;i<=n;i++) { id=order[i]
          if (id in res) {
            d=detail[id]; gsub(/\|/,"/",d); if (length(d)>300) d=substr(d,1,300) "..."
            printf "| %s | %s | %.1f s | %s |\n", id, res[id], ms[id]/1000, d
          } else printf "| %s | FAIL | - | no result (the app or the run died) |\n", id
        }
      }' "$QA_OUT/integration.clean.log"
  } >"$QA_OUT/integration-summary.md"
  n_pass=$(grep -c '| PASS |' "$QA_OUT/integration-summary.md")
  n_fail=$(grep -c '| FAIL |' "$QA_OUT/integration-summary.md")
  dur=$(( $(date +%s) - t0 ))
  if [ "$rc" = 0 ] && [ "$n_fail" = 0 ] && [ "$n_pass" -gt 0 ]; then
    row "Integration scenarios" PASS "$dur" "$n_pass scenarios"
  else
    detail="$n_pass passed, $n_fail failed (integration-summary.md, shots/)"
    [ "$n_pass" = 0 ] && [ "$n_fail" = 0 ] && detail="no scenario ran: see integration.log (flutter exit $rc)"
    row "Integration scenarios" FAIL "$dur" "$detail"
  fi
else
  row "Integration scenarios" SKIPPED 0 "not selected"
fi

# --- 3. release smoke -----------------------------------------------------------------------
if has_stage smoke; then
  qa_log "stage 3/3: release smoke"
  t0=$(date +%s)
  QA_SKIP_GRADLE_STOP=1 "$QA_ROOT/tool/qa/release_smoke.sh" --out "$QA_OUT/smoke" >"$QA_OUT/smoke.log" 2>&1
  rc=$?
  case "$rc" in
    0) row "Release smoke (R8)" PASS $(( $(date +%s) - t0 )) "opened and showed Inicio (smoke/first-screen.png)" ;;
    1) row "Release smoke (R8)" FAIL $(( $(date +%s) - t0 )) "app broken: $(grep -m1 '^FAIL' "$QA_OUT/smoke.log" | cut -c1-200)" ;;
    *) row "Release smoke (R8)" FAIL $(( $(date +%s) - t0 )) "environment error (exit $rc), see smoke.log" ;;
  esac
else
  row "Release smoke (R8)" SKIPPED 0 "not selected"
fi

# --- summary ----------------------------------------------------------------------------------
END_TS=$(date +%s)
{
  echo "# QA battery: $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "Emulator: ${QA_SERIAL:-none} ($QA_AVD). Total: $(( END_TS - START )) s."
  echo
  echo "| Stage | Result | Time | Detail |"
  echo "|---|---|---|---|"
  printf '%s\n' "${SUMMARY_ROWS[@]}"
  echo
  if [ -f "$QA_OUT/integration-summary.md" ] && has_stage integration; then
    echo "## Integration scenarios"
    echo
    cat "$QA_OUT/integration-summary.md"
  fi
} >"$QA_OUT/last-run.md"

echo
cat "$QA_OUT/last-run.md"
echo
if [ "$OVERALL" = 0 ]; then echo "QA battery: ALL GREEN"; else echo "QA battery: FAILED (see above)"; fi
exit "$OVERALL"
