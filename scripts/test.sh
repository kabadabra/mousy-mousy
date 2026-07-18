#!/bin/bash
# Runs the test suite. Under Command Line Tools (no full Xcode), swift-testing
# ships with a broken layout: Testing.framework is off swiftc's default search
# path, and its baked-in rpath to lib_TestingInterop.dylib resolves one
# directory short. This wrapper supplies both paths; with full Xcode selected
# it degrades to a bare `swift test`.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVDIR="$(xcode-select -p)"
if [[ "$DEVDIR" == *CommandLineTools* ]]; then
    FW="$DEVDIR/Library/Developer/Frameworks"
    INTEROP="$DEVDIR/Library/Developer/usr/lib"
    exec env DYLD_LIBRARY_PATH="$INTEROP" swift test \
        -Xswiftc -F -Xswiftc "$FW" \
        -Xlinker -F -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$INTEROP" \
        "$@"
else
    exec swift test "$@"
fi
