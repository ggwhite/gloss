.PHONY: build test app run install dmg icon demos clean screenshot selftest

build:
	swift build

test:
	swift test

app:
	./scripts/bundle.sh

run: app
	open build/Gloss.app

icon:
	./scripts/make-icon.sh

dmg:
	./scripts/dmg.sh

demos:
	./scripts/record-demos.sh

install:
	RELEASE=1 ./scripts/bundle.sh
	-osascript -e 'quit app "Gloss"'
	rm -rf /Applications/Gloss.app
	ditto build/Gloss.app /Applications/Gloss.app
	open /Applications/Gloss.app

screenshot: build
	.build/debug/Gloss --screenshot shots/now.png

selftest: build
	.build/debug/Gloss --self-test shots/self-test.json

clean:
	rm -rf .build build
