BUILD_PATH ?= $(HOME)/Library/Caches/Cake-build
RESOURCE_PROFILE ?= dev

.PHONY: build-resources build test release quality ci

build-resources:
	./scripts/build-resources.sh $(RESOURCE_PROFILE)

build: build-resources
	CAKE_RESOURCE_PROFILE=$(RESOURCE_PROFILE) swift build --build-path "$(BUILD_PATH)"

test:
	RESOURCE_PROFILE=release ./scripts/build-resources.sh release
	CAKE_RESOURCE_PROFILE=release swift test --build-path "$(BUILD_PATH)"

release:
	RESOURCE_PROFILE=release ./scripts/build-resources.sh release
	CAKE_RESOURCE_PROFILE=release swift build -c release --build-path "$(BUILD_PATH)"

quality:
	./scripts/quality-gate.sh

ci:
	./scripts/check-large-assets.sh
	$(MAKE) quality
