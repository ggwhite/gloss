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
	@# Wait for the old Gloss to exit, or `open` below only re-activates it as it quits.
	@for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -f /Applications/Gloss.app/Contents/MacOS/Gloss >/dev/null || break; sleep 0.5; done
	-@pkill -f /Applications/Gloss.app/Contents/MacOS/Gloss; sleep 0.5
	rm -rf /Applications/Gloss.app
	ditto build/Gloss.app /Applications/Gloss.app
	@# Register the fresh copy with Launch Services, then open it (again if it didn't start).
	-@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Gloss.app
	open /Applications/Gloss.app
	@sleep 2; pgrep -f /Applications/Gloss.app/Contents/MacOS/Gloss >/dev/null || open /Applications/Gloss.app
	@sleep 1; pgrep -f /Applications/Gloss.app/Contents/MacOS/Gloss >/dev/null && echo "Gloss is running" || echo "Gloss did not start: open /Applications/Gloss.app"

screenshot: build
	.build/debug/Gloss --screenshot shots/now.png

selftest: build
	.build/debug/Gloss --self-test shots/self-test.json

clean:
	rm -rf .build build
