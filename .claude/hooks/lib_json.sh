#!/usr/bin/env sh
# Shared JSON field extraction for hooks.
# Source this file, then call: extract_json_field "$payload" "field_name"
#
# The field argument accepts a dotted path (e.g. "tool_input.file_path")
# to reach nested values. Top-level keys work without a dot.
#
# Uses jq when available for correct handling of escaped characters.
# Falls back to sed (works for most payloads but fragile with \" in
# values). The sed fallback matches the leaf key name anywhere in the
# payload, which happens to work for the common case of unique key
# names, but users with ambiguous payloads should install jq.

extract_json_field() {
  _payload="$1"
  _field="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$_payload" | jq -r ".${_field} // empty" 2>/dev/null
  else
    _leaf="${_field##*.}"
    printf '%s' "$_payload" | sed -n "s/.*\"${_leaf}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
  fi
}
