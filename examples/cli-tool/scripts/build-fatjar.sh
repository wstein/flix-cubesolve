#!/usr/bin/env sh
# Build a self-contained example fatjar when QR rendering is enabled.
#
# Flix 0.75.3 resolves [mvn-dependencies] for compilation, but its fatjar
# assembler embeds only JARs present in lib/. Stage ZXing there briefly, build
# with the normal project wrapper, then remove the ignored staging directory.
set -eu

cd "$(dirname "$0")/.."

stage_dir=lib/render-fatjar

cleanup() {
  rm -rf "$stage_dir"
}

trap cleanup EXIT HUP INT TERM
mkdir -p "$stage_dir"

for coordinate in \
  com.google.zxing:core:3.5.4 \
  com.google.zxing:javase:3.5.4 \
  com.github.jai-imageio:jai-imageio-core:1.4.0 \
  org.jcommander:jcommander:1.85
do
  mvn -q org.apache.maven.plugins:maven-dependency-plugin:3.6.1:copy \
    -Dartifact="$coordinate" \
    -DoutputDirectory="$stage_dir" \
    -Dmdep.stripVersion=true
done

flix build-fatjar "$@"
