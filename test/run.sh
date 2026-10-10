#!/bin/sh
# Usage: sh test/run.sh
# Runs bin/refresh.sh against the fixtures, with the fake herdr and treehouse
# commands of test/bin on a PATH that holds nothing else but jq and four system
# tools.

# shellcheck disable=SC2016
set -u
unset HERDR_BIN_PATH HERDR_PLUGIN_STATE_DIR

here=$(cd "$(dirname "$0")" && pwd -P)
plugin=${here%/*}
shell=$(command -v "${TEST_SHELL:-sh}")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

tools="$tmp/tools"
mkdir -p "$tools"
for tool in cat mktemp rm date; do
  ln -s "$(command -v "$tool")" "$tools/$tool"
done

setup() {
  t="$tmp/$1"
  state_dir="$t/state"
  herdr_bin=''
  mkdir -p "$t/bin" "$t/fake/treehouse" "$t/state" "$t/root"
  root=$(cd "$t/root" && pwd -P)
  mkdir -p "$root/plain" "$root/src/research" "$root/src/api" \
    "$root/pools/research-6310cd/1/research" \
    "$root/pools/research-6310cd/2/research" \
    "$root/pools/research-6310cd/3/research" \
    "$root/pools/api-9f2c1a/1/api"
  echo research.json >"$root/src/research/.fake-treehouse"
  echo research.json >"$root/pools/research-6310cd/.fake-treehouse"
  echo api.json >"$root/src/api/.fake-treehouse"
  echo api.json >"$root/pools/api-9f2c1a/.fake-treehouse"
  for fixture in herdr/pane-list.json herdr/workspace-list.json; do
    sed "s|@ROOT@|$root|g" "$here/fixtures/$fixture" >"$t/fake/${fixture#herdr/}"
  done
  for fixture in research.json api.json; do
    sed "s|@ROOT@|$root|g" "$here/fixtures/treehouse/$fixture" >"$t/fake/treehouse/$fixture"
  done
  ln -s "$here/bin/herdr" "$here/bin/treehouse" "$(command -v jq)" "$t/bin/"
  reset_logs
  : >"$t/failures"
}

reset_logs() {
  for log in reports calls treehouse unexpected; do
    : >"$t/fake/$log.log"
  done
}

edit() {
  file="$t/fake/$1"
  filter=$2
  shift 2
  jq "$@" "$filter" "$file" >"$file.new" && mv "$file.new" "$file"
}

refresh() {
  PATH="$t/bin:$tools" FAKE_DIR="$t/fake" \
    HERDR_BIN_PATH="$herdr_bin" HERDR_PLUGIN_STATE_DIR="$state_dir" \
    "$shell" "$plugin/bin/refresh.sh" >"$t/stdout" 2>"$t/stderr" </dev/null
  check 'exit status' 0 $?
  check 'stdout' '' "$(cat "$t/stdout")"
}

apply_reports_to_workspace_list() {
  edit workspace-list.json '
    reduce ($log | split("\n")[] | select(length > 0)
            | capture("^(?<workspace>\\S+) (?<op>set|clear) (?<name>[^=]+)(=(?<value>.*))?$")) as $r
      (.; (.result.workspaces[] | select(.workspace_id == $r.workspace)) |=
            if $r.op == "set" then .tokens[$r.name] = $r.value
            else del(.tokens[$r.name]) end)
  ' --rawfile log "$t/fake/reports.log"
}

refresh_until_reported() {
  refresh
  apply_reports_to_workspace_list
  reset_logs
}

check() {
  [ "$2" = "$3" ] && return
  printf '  %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3" >>"$t/failures"
}

expect_reports() {
  check 'token reports' "$(cat)" "$(cat "$t/fake/reports.log")"
}

expect_log() {
  check 'plugin log' "$1" "$(cat "$t/stderr")"
}

reported_value() {
  sed -n "s/^$1 set $2=//p" "$t/fake/reports.log"
}

test_slot_workspaces_get_all_tokens() {
  refresh
  expect_reports <<'EOF'
w1 set th_line=🌳 research#1 · in-use · fm/fix-x
w1 set th_slot=🌳 research#1
w1 set th_state=in-use
w1 set th_branch=fm/fix-x
w3 set th_line=🌳 research#2 · in-use · detached
w3 set th_slot=🌳 research#2
w3 set th_state=in-use
w3 set th_branch=detached
w4 set th_line=🌳 api#1 · leased · feat/login
w4 set th_slot=🌳 api#1
w4 set th_state=leased
w4 set th_branch=feat/login
EOF
  expect_log ''
}

test_one_report_for_each_workspace_with_source_and_time_limit() {
  refresh
  check 'herdr calls' "$(
    cat <<'EOF'
w1 --source plugin:azd325.treehouse --ttl-ms 1800000
w3 --source plugin:azd325.treehouse --ttl-ms 1800000
w4 --source plugin:azd325.treehouse --ttl-ms 1800000
EOF
  )" "$(cat "$t/fake/calls.log")"
}

test_treehouse_runs_once_for_each_pool() {
  refresh
  check 'treehouse calls' "$(
    cat <<EOF
$root/pools/research-6310cd/1/research
$root/plain
$root/src/api
EOF
  )" "$(cat "$t/fake/treehouse.log")"
}

test_directory_outside_a_slot_is_asked_once() {
  edit pane-list.json '
    .result.panes[0] |= (.cwd = $plain | .foreground_cwd = $plain)
    | .result.panes[2] |= (.cwd = $clone | .foreground_cwd = $clone)
  ' --arg plain "$root/plain" --arg clone "$root/src/api"
  refresh
  check 'treehouse calls' "$(
    cat <<EOF
$root/plain
$root/src/api
EOF
  )" "$(cat "$t/fake/treehouse.log")"
}

test_unchanged_values_are_not_reported() {
  refresh_until_reported
  refresh
  expect_reports </dev/null
  check 'herdr calls' '' "$(cat "$t/fake/calls.log")"
}

test_old_slot_value_is_updated_on_the_next_run() {
  refresh_until_reported
  edit workspace-list.json '.result.workspaces[0].tokens.th_slot = "research#1"'
  refresh
  expect_reports <<'EOF'
w1 set th_slot=🌳 research#1
EOF
}

test_slot_has_a_symbol_and_line_has_exactly_one() {
  refresh
  check 'slot prefix' '🌳 ' "$(reported_value w1 th_slot | jq -Rr '.[0:2]')"
  check 'symbols in line' 1 "$(reported_value w1 th_line | jq -Rr '[scan("🌳")] | length')"
}

test_long_project_keeps_symbol_and_slot_within_80_characters() {
  project=$(jq -nr '"é" * 100')
  long_path="$root/pools/research-6310cd/1/$project"
  mkdir -p "$long_path"
  edit treehouse/research.json '.[0] |= (.path = $path | .name = "12")' --arg path "$long_path"
  edit pane-list.json '.result.panes[0] |= (.cwd = $path | .foreground_cwd = $path)' --arg path "$long_path"
  refresh
  check 'long slot' "$(jq -nr '"🌳 " + ("é" * 75) + "#12"')" "$(reported_value w1 th_slot)"
  check 'unchanged long line' "$(jq -nr '"🌳 " + ("é" * 77) + "…"')" "$(reported_value w1 th_line)"
  check 'length of th_slot' 80 "$(reported_value w1 th_slot | jq -Rr length)"
  apply_reports_to_workspace_list
  reset_logs
  refresh
  expect_reports </dev/null
}

test_changed_state_reports_only_the_changed_tokens() {
  refresh_until_reported
  edit treehouse/research.json '.[0].status = "leased"'
  refresh
  expect_reports <<'EOF'
w1 set th_line=🌳 research#1 · leased · fm/fix-x
w1 set th_state=leased
EOF
}

test_all_tokens_are_reported_again_after_half_the_time_limit() {
  refresh_until_reported
  start=$(date +%s)
  echo $((start - 900)) >"$t/state/keepalive"
  refresh
  check 'number of token reports' 12 "$(grep -c . "$t/fake/reports.log")"
  read -r stamp <"$t/state/keepalive"
  [ "$stamp" -ge "$start" ] || check 'keepalive stamp' "at least $start" "$stamp"
}

test_tokens_are_not_reported_again_before_half_the_time_limit() {
  refresh_until_reported
  echo $(($(date +%s) - 880)) >"$t/state/keepalive"
  refresh
  expect_reports </dev/null
}

test_without_a_state_directory_only_changes_are_reported() {
  state_dir=''
  refresh_until_reported
  refresh
  expect_reports </dev/null
}

test_stale_tokens_outside_a_slot_are_cleared() {
  edit workspace-list.json \
    '.result.workspaces[1].tokens = {th_line: "🌳 old#7 · dirty", th_slot: "old#7", th_state: "dirty", jj_status: "*2"}'
  refresh
  check 'reports for w2' "$(
    cat <<'EOF'
w2 clear th_line
w2 clear th_slot
w2 clear th_state
EOF
  )" "$(grep '^w2 ' "$t/fake/reports.log")"
}

test_tokens_are_cleared_when_the_pane_directory_is_gone() {
  refresh_until_reported
  edit pane-list.json '.result.panes[0] |= (.cwd = $gone | .foreground_cwd = $gone)' \
    --arg gone "$root/gone"
  refresh
  expect_reports <<'EOF'
w1 clear th_line
w1 clear th_slot
w1 clear th_state
w1 clear th_branch
EOF
}

test_workspace_without_a_listed_pane_keeps_its_tokens() {
  edit workspace-list.json '.result.workspaces[1].tokens = {th_slot: "old#7"}'
  edit pane-list.json 'del(.result.panes[1])'
  refresh
  check 'reports for w2' '' "$(grep '^w2 ' "$t/fake/reports.log")"
}

test_workspace_with_a_pane_of_unknown_directory_keeps_its_tokens() {
  edit workspace-list.json '.result.workspaces[1].tokens = {th_slot: "old#7"}'
  edit pane-list.json '.result.panes[1] |= del(.cwd, .foreground_cwd)'
  refresh
  check 'reports for w2' '' "$(grep '^w2 ' "$t/fake/reports.log")"
}

test_slot_without_a_branch_clears_the_branch_token() {
  refresh_until_reported
  edit treehouse/research.json '.[0] |= (.branch = "" | .flavor = "jj")'
  refresh
  expect_reports <<'EOF'
w1 set th_line=🌳 research#1 · in-use
w1 clear th_branch
EOF
}

test_youre_here_with_resident_processes_is_in_use() {
  edit treehouse/research.json '.[0].status = "you'\''re here"'
  refresh
  check 'state of w1' 'in-use' "$(reported_value w1 th_state)"
}

test_youre_here_without_processes_stays() {
  edit treehouse/research.json '.[0] |= (.status = "you'\''re here" | .processes = [])'
  refresh
  check 'state of w1' "you're here" "$(reported_value w1 th_state)"
}

test_pane_without_foreground_cwd_uses_cwd() {
  edit pane-list.json 'del(.result.panes[0].foreground_cwd)'
  refresh
  check 'slot of w1' '🌳 research#1' "$(reported_value w1 th_slot)"
}

test_foreground_cwd_outside_a_slot_gives_no_token() {
  edit pane-list.json '.result.panes[0].foreground_cwd = $plain' --arg plain "$root/plain"
  refresh
  check 'reports for w1' '' "$(grep '^w1 ' "$t/fake/reports.log")"
}

test_first_pane_in_a_slot_gives_the_tokens() {
  edit pane-list.json '.result.panes[3] |= (.cwd = $slot | .foreground_cwd = $slot)' \
    --arg slot "$root/pools/research-6310cd/3/research"
  refresh
  check 'line of w4' '🌳 research#3 · available · detached' "$(reported_value w4 th_line)"
}

test_pane_directory_through_a_symlink_matches() {
  ln -s "$root/pools" "$root/link"
  edit pane-list.json '.result.panes[0].foreground_cwd |= sub("/pools/"; "/link/")'
  refresh
  check 'slot of w1' '🌳 research#1' "$(reported_value w1 th_slot)"
}

test_slot_path_through_a_symlink_matches() {
  ln -s "$root/pools" "$root/link"
  edit treehouse/research.json '.[].path |= sub("/pools/"; "/link/")'
  refresh
  check 'slot of w1' '🌳 research#1' "$(reported_value w1 th_slot)"
}

test_pane_in_a_subdirectory_of_a_slot_matches() {
  mkdir -p "$root/pools/research-6310cd/1/research/docs"
  edit pane-list.json '.result.panes[0].foreground_cwd += "/docs"'
  refresh
  check 'slot of w1' '🌳 research#1' "$(reported_value w1 th_slot)"
}

test_long_values_keep_80_characters_and_compare_equal() {
  edit treehouse/research.json '.[0].branch = "feature/" + ("x" * 100)'
  refresh
  line=$(reported_value w1 th_line)
  check 'length of th_line' 80 "$(printf '%s' "$line" | jq -Rr length)"
  check 'end of th_line' '…' "$(printf '%s' "$line" | jq -Rr '.[-1:]')"
  check 'length of th_branch' 80 "$(reported_value w1 th_branch | jq -Rr length)"
  apply_reports_to_workspace_list
  reset_logs
  refresh
  expect_reports </dev/null
}

test_herdr_bin_path_is_used() {
  rm "$t/bin/herdr"
  herdr_bin="$here/bin/herdr"
  refresh
  check 'slot of w1' '🌳 research#1' "$(reported_value w1 th_slot)"
}

test_missing_treehouse_reports_nothing() {
  rm "$t/bin/treehouse"
  refresh
  expect_reports </dev/null
  expect_log 'treehouse: treehouse is not on PATH, no token reported'
}

test_missing_jq_reports_nothing() {
  rm "$t/bin/jq"
  refresh
  expect_reports </dev/null
  expect_log 'treehouse: jq is not on PATH, no token reported'
}

test_failed_herdr_list_reports_nothing() {
  rm "$t/fake/pane-list.json"
  refresh
  expect_reports </dev/null
  expect_log 'treehouse: herdr pane list failed, no token reported'
}

test_unknown_pane_list_form_reports_nothing() {
  edit pane-list.json '.result = {type: "pane_list", items: []}'
  refresh
  expect_reports </dev/null
  expect_log 'treehouse: unknown form of herdr pane list, no token reported'
}

test_unknown_workspace_list_form_reports_nothing() {
  echo 'not json' >"$t/fake/workspace-list.json"
  refresh
  expect_reports </dev/null
  expect_log 'treehouse: unknown form of herdr workspace list, no token reported'
}

test_unknown_treehouse_form_leaves_its_workspaces_untouched() {
  edit workspace-list.json '.result.workspaces[0].tokens = {th_slot: "research#1"}'
  edit treehouse/research.json '{worktrees: .}'
  edit treehouse/api.json 'map(del(.status))'
  refresh
  expect_reports </dev/null
  expect_log 'treehouse: unknown form of treehouse status --json, no token reported for its workspaces'
}

test_unknown_form_of_one_pool_does_not_stop_the_other_pool() {
  edit treehouse/research.json '{worktrees: .}'
  refresh
  check 'slot of w4' '🌳 api#1' "$(reported_value w4 th_slot)"
  check 'reports for w1 and w3' '' "$(grep '^w[13] ' "$t/fake/reports.log")"
}

test_refused_report_gives_one_log_line_and_no_keepalive_stamp() {
  touch "$t/fake/refuse-reports"
  refresh
  expect_log 'treehouse: herdr refused a token report'
  [ -e "$t/state/keepalive" ] && check 'keepalive stamp' 'no file' 'file'
}

pass=0
fail=0
sed -n 's/^\(test_[a-z0-9_]*\)().*/\1/p' "$0" >"$tmp/names"
while read -r name <&3; do
  setup "$name"
  "$name"
  check 'calls that the plugin must not make' '' "$(cat "$t/fake/unexpected.log")"
  if [ -s "$t/failures" ]; then
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$name"
    cat "$t/failures"
  else
    pass=$((pass + 1))
    printf 'ok   %s\n' "$name"
  fi
done 3<"$tmp/names"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
