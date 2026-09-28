# macOS / Xcode 16+ 専用。Linux では使えません。

.PHONY: open build test

open:
	open ScreenRectTranslate.xcodeproj

build:
	xcodebuild -scheme ScreenRectTranslate -configuration Debug -destination 'platform=macOS,arch=arm64' build

test:
	xcodebuild -scheme ScreenRectTranslate -configuration Debug -destination 'platform=macOS,arch=arm64' test
