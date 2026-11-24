#!/bin/sh
set -eu
base=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work="$base/.attune-build/domain-tests"
mkdir -p "$work"
swiftc -module-cache-path "$work/modules" "$base/Attune/Domain.swift" "$base/Tests/LedgerTests.swift" -o "$work/ledger-tests"
"$work/ledger-tests"
