BIN    := jot
PREFIX ?= $(HOME)/.local/bin

.PHONY: build install test app install-app dist clean

build:
	go build -o bin/$(BIN) ./cmd/$(BIN)

install: build
	@mkdir -p $(PREFIX)
	@cp bin/$(BIN) $(PREFIX)/$(BIN)
	@echo "✓ installed $(PREFIX)/$(BIN)"

test:
	go vet ./...
	go test ./...
	cd macos && swift test

app:
	macos/build-app.sh release

install-app: app
	rm -rf /Applications/Jot.app
	cp -R macos/build/Jot.app /Applications/
	@echo "✓ installed /Applications/Jot.app"

dist:
	scripts/dist.sh

clean:
	rm -rf bin/ dist/ macos/build/ macos/.build/
