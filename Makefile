.PHONY: build test app run install clean screenshot selftest

build:
	swift build

test:
	swift test

app:
	./scripts/bundle.sh

run: app
	open build/Gloss.app

install: app
	rm -rf /Applications/Gloss.app
	cp -R build/Gloss.app /Applications/Gloss.app

screenshot: build
	.build/debug/Gloss --screenshot shots/now.png

selftest: build
	.build/debug/Gloss --self-test shots/self-test.json

clean:
	rm -rf .build build
