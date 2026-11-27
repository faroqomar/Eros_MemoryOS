#!/bin/sh
set -eu

# Test tooling only. No app bundle/source mutation and no host network changes.
# Both source files must live beside this script. Compile into the supplied output.
# __interpose reference: Apple dyld/include/mach-o/dyld-interposing.h.
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$#" -ne 1 ]; then
  printf '%s\n' 'Usage: prepare.sh OUTPUT_DIRECTORY (outside app sources)' >&2
  exit 2
fi
output_dir=$1
mkdir -p "$output_dir"
for name in offline-policy api-network-faults; do
  xcrun --sdk iphonesimulator clang \
    -target arm64-apple-ios18.0-simulator -dynamiclib -Wall -Wextra -Werror \
    "$source_dir/$name.c" -o "$output_dir/libmemoryos-$name.dylib"
  codesign --force --sign - "$output_dir/libmemoryos-$name.dylib"
done
printf '%s\n' "Prepared test-only Simulator helpers in $output_dir"
printf '%s\n' 'API interposition injects failure through public APIs; it does not establish kernel isolation.'
