# macOS / Xcode 16+ 専用。Linux では使えません。

.PHONY: open build test release

# release は Apple Development 証明書で署名する。DEVELOPMENT_TEAM に自分の Team ID を渡す。
#   make release DEVELOPMENT_TEAM=XXXXXXXXXX
DEVELOPMENT_TEAM ?=
RELEASE_APP = build/DerivedData/Build/Products/Release/ScreenRectTranslate.app

open:
	open ScreenRectTranslate.xcodeproj

build:
	xcodebuild -scheme ScreenRectTranslate -configuration Debug -destination 'platform=macOS,arch=arm64' build

test:
	xcodebuild -scheme ScreenRectTranslate -configuration Debug -destination 'platform=macOS,arch=arm64' test

release:
	@test -n "$(DEVELOPMENT_TEAM)" || (echo "DEVELOPMENT_TEAM を指定してください" >&2; exit 1)
	xcodebuild -scheme ScreenRectTranslate -configuration Release -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath build/DerivedData -allowProvisioningUpdates \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) CODE_SIGN_IDENTITY="Apple Development" build
	@echo "$(RELEASE_APP)"
