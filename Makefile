.PHONY: build test app run dmg icon clean

build:
	swift build

test:
	swift test

# Local ad-hoc signed bundle for the host architecture.
app:
	ARCHS="$$(uname -m)" scripts/build-app.sh

run: app
	open build/Possum.app

dmg: app
	scripts/make-dmg.sh build/Possum.app build/Possum.dmg

icon:
	swift scripts/make-icon.swift Resources/AppIcon-source.webp Resources/AppIcon.icns

clean:
	rm -rf .build build
