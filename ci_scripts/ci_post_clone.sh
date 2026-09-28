#!/bin/sh
#
# Xcode Cloud: リポジトリのクローン直後に実行される。
# .metal ファイルのコンパイルには Metal Toolchain が必要。Xcode 26 以降は別コンポーネントのため、
# 使えない環境でだけダウンロードする。調査用に Metal の状態をログへ出す。
# （このスクリプトの失敗でビルド全体を止めないよう、各コマンドの失敗は無視する）

echo "== Xcode"
xcodebuild -version || true

if xcrun metal --version >/dev/null 2>&1; then
    echo "== Metal Toolchain は利用可能"
else
    echo "== Metal Toolchain が見つからないためダウンロードする"
    xcodebuild -downloadComponent MetalToolchain || true
fi

echo "== Metal"
xcrun -f metal || true
xcrun metal --version || true

exit 0
