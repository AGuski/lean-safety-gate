#!/usr/bin/env bash
# Fail if the project is unproved, uses axioms outside Lean's standard three,
# or changes the specification without updating spec.lock and spec.manifest.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

if [[ -d "${HOME}/.elan/bin" ]]; then
  export PATH="${HOME}/.elan/bin:${PATH}"
fi

fail() {
  echo "gate: $*" >&2
  exit 1
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

entries() {
  grep -E '^[^#[:space:]]' "$1" | awk '{print $1}' | sort -u
}

echo "gate: lake build"
lake build

echo "gate: sorry, admit, and axiom"
keyword='(^|[^A-Za-z0-9_'"'"'])(sorry|admit|axiom)([^A-Za-z0-9_'"'"']|$)'
if grep -nE "$keyword" LeanSafetyGate.lean LeanSafetyGate/*.lean; then
  fail "Lean source contains sorry, admit, or axiom"
fi

echo "gate: spec.lock"
locked_lines=$(entries spec.lock | wc -l | tr -d ' ')
if [[ "$locked_lines" != "1" ]]; then
  fail "spec.lock must contain exactly one hash, found ${locked_lines}"
fi
locked=$(entries spec.lock)
actual=$(hash_file LeanSafetyGate/Spec.lean)
if [[ "$locked" != "$actual" ]]; then
  fail "spec.lock has ${locked:-nothing}, but LeanSafetyGate/Spec.lean is $actual. Update spec.lock in the same commit."
fi

echo "gate: spec.manifest"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

entries spec.manifest > "$tmp/manifest"
grep -E '^def[[:space:]]+[A-Za-z_][A-Za-z0-9_'"'"']*[[:space:]]*:[[:space:]]*Prop[[:space:]]*:=' \
  LeanSafetyGate/Spec.lean \
  | sed -E 's/^def[[:space:]]+([A-Za-z_][A-Za-z0-9_'"'"']*).*/\1/' \
  | sort -u > "$tmp/props"

if [[ ! -s "$tmp/manifest" ]]; then
  fail "spec.manifest lists no propositions"
fi
if ! cmp -s "$tmp/props" "$tmp/manifest"; then
  echo "in Spec.lean but not in spec.manifest:" >&2
  comm -23 "$tmp/props" "$tmp/manifest" >&2 || true
  echo "in spec.manifest but not declared as \`def <name> : Prop\` in Spec.lean:" >&2
  comm -13 "$tmp/props" "$tmp/manifest" >&2 || true
  fail "spec.manifest does not match the propositions in Spec.lean"
fi

{
  echo "import LeanSafetyGate.Proofs"
  echo
  while read -r name; do
    echo "#check (LeanSafetyGate.Proofs.${name} : LeanSafetyGate.Spec.${name})"
    echo "#print axioms LeanSafetyGate.Proofs.${name}"
  done < "$tmp/manifest"
} > "$tmp/Check.lean"

echo "gate: #print axioms"
lake env lean "$tmp/Check.lean" | tee "$tmp/axioms"

awk '
  /does not depend on any axioms/ { seen[$0]=1; next }
  /depends on axioms:/ {
    seen[$0]=1
    inner=$0
    sub(/^.*\[/, "", inner)
    sub(/\].*$/, "", inner)
    n=split(inner, xs, ",")
    for (i=1; i<=n; i++) {
      gsub(/[[:space:]]/, "", xs[i])
      if (xs[i]=="") continue
      if (xs[i]!="propext" && xs[i]!="Classical.choice" && xs[i]!="Quot.sound") {
        print "gate: forbidden axiom " xs[i] > "/dev/stderr"
        bad=1
      }
    }
    next
  }
  END { if (bad) exit 1 }
' "$tmp/axioms"

while read -r name; do
  if ! grep -q "LeanSafetyGate.Proofs.${name}'" "$tmp/axioms"; then
    fail "no #print axioms result for ${name}"
  fi
done < "$tmp/manifest"

echo "gate: ok"
