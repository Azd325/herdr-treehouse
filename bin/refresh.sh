#!/bin/sh

set -u

SOURCE='plugin:azd325.treehouse'
TTL_MS=1800000
HERDR=${HERDR_BIN_PATH:-herdr}
US=$(printf '\037')

quit() {
  printf 'treehouse: %s\n' "$1" >&2
  exit 0
}

command -v jq >/dev/null 2>&1 || quit 'jq is not on PATH, no token reported'
command -v treehouse >/dev/null 2>&1 || quit 'treehouse is not on PATH, no token reported'

work=$(mktemp -d) || quit 'mktemp failed, no token reported'
trap 'rm -rf "$work"' EXIT

"$HERDR" pane list >"$work/panes.json" 2>/dev/null </dev/null ||
  quit 'herdr pane list failed, no token reported'
"$HERDR" workspace list >"$work/workspaces.json" 2>/dev/null </dev/null ||
  quit 'herdr workspace list failed, no token reported'

jq -e '.result.workspaces | type == "array"' "$work/workspaces.json" >/dev/null 2>&1 ||
  quit 'unknown form of herdr workspace list, no token reported'

jq -r '
  .result.panes
  | if type == "array" then .[] else error("form") end
  | [.workspace_id, (.foreground_cwd // .cwd // "")]
  | select(all(.[]; type == "string" and (test("\\p{Cc}") | not)))
  | join("\u001f")
' "$work/panes.json" >"$work/panes" 2>/dev/null ||
  quit 'unknown form of herdr pane list, no token reported'

note=''
: >"$work/known"
: >"$work/resolved"

# Records in known, fields separated by US:
#   slot, slot directory, slot label, state, branch, original line label
#   none, directory outside a slot
#   unknown, directory with a status of unknown form
lookup() {
  while IFS=$US read -r kind path slot state branch line_slot; do
    case $kind in
      slot)
        case "$1/" in
          "$path"/*) return 0 ;;
        esac
        ;;
      *)
        [ "$1" = "$path" ] && return 0
        ;;
    esac
  done <"$work/known"
  return 1
}

ask_treehouse() {
  if ! (cd "$1" && treehouse status --json) >"$work/status.json" 2>/dev/null </dev/null; then
    printf 'none%s%s\n' "$US" "$1" >>"$work/known"
    return
  fi
  # Herdr trims a token value, drops its control characters and keeps 80
  # characters. The values below have the same form, so a stored value compares
  # equal. "you're here" names the directory of the caller, which is this script:
  # from any other directory Treehouse reports a slot with resident processes as
  # in-use.
  if ! jq -r --arg here "you're here" '
    def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
    def clean: gsub("\\p{Cc}"; "") | trim | .[0:80] | trim;
    def slot:
      (.name | clean | .[0:77] | trim | "#" + .) as $suffix
      | (.path | sub("/+$"; "") | split("/") | last | clean) as $project
      | "🌳 " + $project[0:([0, 78 - ($suffix | length)] | max)] + $suffix;
    if type == "array" then .[] else error("form") end
    | if type == "object" and ([.name, .path, .status] | all(type == "string"))
      then . else error("form") end
    | select(.path | test("\\p{Cc}") | not)
    | [ .path,
        slot,
        (if .status == $here and ((.processes // []) | length) > 0
         then "in-use" else .status end | clean),
        (if (.branch | type) == "string" and .branch != "" then .branch
         elif .detached == true then "detached"
         else "" end | clean),
        ((.path | sub("/+$"; "") | split("/") | last) + "#" + .name | clean) ]
    | join("\u001f")
  ' "$work/status.json" >"$work/pool" 2>/dev/null; then
    note='unknown form of treehouse status --json, no token reported for its workspaces'
    printf 'unknown%s%s\n' "$US" "$1" >>"$work/known"
    return
  fi
  while IFS=$US read -r path slot state branch line_slot; do
    root=$(cd "$path" 2>/dev/null && pwd -P) || root=$path
    printf 'slot%s%s%s%s%s%s%s%s%s%s\n' \
      "$US" "$root" "$US" "$slot" "$US" "$state" "$US" "$branch" "$US" "$line_slot" >>"$work/known"
  done <"$work/pool"
  printf 'none%s%s\n' "$US" "$1" >>"$work/known"
}

while IFS=$US read -r workspace dir; do
  kind=unknown slot='' state='' branch='' line_slot=''
  if [ -n "$dir" ]; then
    if physical=$(cd "$dir" 2>/dev/null && pwd -P); then
      lookup "$physical" || {
        ask_treehouse "$physical"
        lookup "$physical"
      }
    else
      kind=none
    fi
  fi
  printf '%s%s%s%s%s%s%s%s%s%s%s\n' \
    "$workspace" "$US" "$kind" "$US" "$slot" "$US" "$state" "$US" "$branch" "$US" "$line_slot" >>"$work/resolved"
done <"$work/panes"

# A token keeps its time limit from the report that set it. A report of all
# tokens after half the limit keeps a correct value on the row.
keepalive=0
stamp=${HERDR_PLUGIN_STATE_DIR:+$HERDR_PLUGIN_STATE_DIR/keepalive}
now=$(date +%s)
if [ -n "$stamp" ]; then
  keepalive=1
  last=''
  [ -r "$stamp" ] && read -r last <"$stamp"
  case $last in
    '' | *[!0-9]*) ;;
    *)
      age=$((now - last))
      [ "$age" -ge 0 ] && [ "$age" -lt $((TTL_MS / 2000)) ] && keepalive=0
      ;;
  esac
fi

jq -r --rawfile resolved "$work/resolved" --argjson keepalive "$keepalive" '
  def cap: if length > 80 then .[0:79] + "…" else . end;
  ($resolved | split("\n") | map(select(length > 0) | split("\u001f"))) as $rows
  | .result.workspaces[]
  | select((.workspace_id | type) == "string")
  | .workspace_id as $workspace
  | (.tokens | if type == "object" then . else {} end) as $have
  | [$rows[] | select(.[0] == $workspace)] as $mine
  | ([$mine[] | select(.[1] == "slot")] | first) as $hit
  | if $hit then
      {th_slot: $hit[2], th_state: $hit[3], th_branch: $hit[4]}
      | .th_line = ("🌳 " + ([$hit[5], .th_state, .th_branch] | map(select(. != "")) | join(" · ")) | cap)
    elif ($mine | length) == 0 or any($mine[]; .[1] == "unknown") then empty
    else {} end
  | . as $want
  | ("th_line", "th_slot", "th_state", "th_branch") as $name
  | ($want[$name] // "") as $value
  | if $value != "" then
      select($keepalive == 1 or $have[$name] != $value)
      | [$workspace, "set", $name, $value]
    else
      select($have | has($name))
      | [$workspace, "clear", $name, ""]
    end
  | join("\u001f")
' "$work/workspaces.json" >"$work/plan" 2>/dev/null ||
  quit 'unknown form of herdr workspace list, no token reported'

report() {
  target=$1
  shift
  "$HERDR" workspace report-metadata "$target" --source "$SOURCE" --ttl-ms "$TTL_MS" "$@" \
    >/dev/null 2>&1 </dev/null || note='herdr refused a token report'
}

current=''
set --
while IFS=$US read -r workspace op name value; do
  if [ "$workspace" != "$current" ]; then
    [ $# -gt 0 ] && report "$current" "$@"
    current=$workspace
    set --
  fi
  case $op in
    set) set -- "$@" --token "$name=$value" ;;
    clear) set -- "$@" --clear-token "$name" ;;
  esac
done <"$work/plan"
[ $# -gt 0 ] && report "$current" "$@"

if [ "$keepalive" -eq 1 ] && [ -z "$note" ]; then
  { printf '%s\n' "$now" >"$stamp"; } 2>/dev/null
fi
[ -n "$note" ] && quit "$note"
exit 0
