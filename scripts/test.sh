#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_dir=$(mktemp -d "${TMPDIR:-/tmp}/autoid-tests.XXXXXX")
trap 'rm -rf "$task_dir"' EXIT
swiftc -module-cache-path "$task_dir/module-cache" AutoIDPhoto/AppLanguage.swift AutoIDPhoto/PhotoGeometry.swift AutoIDPhoto/BackgroundCompositor.swift AutoIDPhoto/PhotoJPEGEncoder.swift Tests/main.swift -o "$task_dir/geometry-tests"
"$task_dir/geometry-tests"
