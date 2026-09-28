#!/bin/sh
#
# Xcode Cloud: リポジトリのクローン直後に実行される。
# Xcode 26 以降は Metal Toolchain が別コンポーネントになっており、Xcode Cloud の環境には
# 入っていないことがある。入っていないと .metal ファイルのコンパイル（CompileMetalFile）で失敗するため、
# ビルド前にダウンロードしておく。

set -e

xcodebuild -downloadComponent MetalToolchain
