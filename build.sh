#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

# clean
echo "========="
echo "clean all"
echo "========="
rm -rf .build/aarch64-unknown-linux-gnu* .build/arm64-apple-macosx* .build/x86_64-apple-macosx* .build/x86_64-unknown-linux-gnu*

# build
echo "==========="
echo "macOS arm64"
echo "==========="
swift build -c release --arch arm64

echo "============"
echo "macOS x86_64"
echo "============"
swift build -c release --arch x86_64

echo "==========="
echo "Linux arm64"
echo "==========="
docker run --platform linux/arm64 -v "$PWD:/code" -w /code swift:latest swift build -c release --static-swift-stdlib

echo "==========="
echo "Linux amd64"
echo "==========="
# swift側のarch指定でコンパイルしたいが, そうするとビルド落ちるのでdockerのplatform自体をamd64にしている. ので遅い.
docker run --platform linux/amd64 -v "$PWD:/code" -w /code swift:latest swift build -c release --static-swift-stdlib

# cp libs
echo "======="
echo "cp libs"
echo "======="
cp -r lib/arm64 .build/aarch64-unknown-linux-gnu/release/lib
cp -r lib/x86_64 .build/x86_64-unknown-linux-gnu/release/lib

# Then zip
echo "======="
echo "zip all"
echo "======="
cd .build
zip -r aarch64-unknown-linux-gnu-$1.zip aarch64-unknown-linux-gnu/release
zip -r arm64-apple-macosx-$1.zip        arm64-apple-macosx/release
zip -r x86_64-apple-macosx-$1.zip       x86_64-apple-macosx/release
zip -r x86_64-unknown-linux-gnu-$1.zip  x86_64-unknown-linux-gnu/release
