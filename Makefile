.PHONY: build test app run install dmg icon clean screenshot selftest

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

install: app
	rm -rf /Applications/Gloss.app
	cp -R build/Gloss.app /Applications/Gloss.app

screenshot: build
	.build/debug/Gloss --screenshot shots/now.png

selftest: build
	.build/debug/Gloss --self-test shots/self-test.json

clean:
	rm -rf .build build
