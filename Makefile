.PHONY: bootstrap generate format format-check lint lint-release build test test-app verify ci release-dry-run open clean

PROJECT := Pathsta.xcodeproj
SCHEME := Pathsta
ARCHITECTURE := $(shell uname -m)
DESTINATION := platform=macOS,arch=$(ARCHITECTURE)
DERIVED_DATA := .build/DerivedData
VERSION := $(shell awk '$$1 == "MARKETING_VERSION:" { print $$2; exit }' project.yml)
BUILD_NUMBER := $(shell awk '$$1 == "CURRENT_PROJECT_VERSION:" { print $$2; exit }' project.yml)

bootstrap:
	brew bundle
	$(MAKE) generate

generate:
	xcodegen generate

format:
	swift-format format --in-place Package.swift
	swift-format format --in-place --recursive Sources Tests

format-check:
	swift-format lint --strict Package.swift
	swift-format lint --strict --recursive Sources Tests

lint:
	$(MAKE) format-check
	swiftlint lint --strict

lint-release:
	actionlint
	shellcheck Scripts/release/*.sh

build: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

test:
	swift test --parallel

test-app: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		-only-testing:PathstaAppTests \
		test

verify: lint test test-app

release-dry-run: generate
	Scripts/release/preflight.sh v$(VERSION)
	ALLOW_ADHOC_SIGNING=1 SIGNING_IDENTITY=- \
		Scripts/release/build-app.sh $(VERSION) $(BUILD_NUMBER)
	ALLOW_ADHOC_SIGNING=1 SIGNING_IDENTITY=- \
		Scripts/release/make-dmg.sh $(VERSION)
	Scripts/release/package-release.sh $(VERSION)
	ALLOW_ADHOC_SIGNING=1 ALLOW_UNNOTARIZED=1 \
		Scripts/release/verify-distribution.sh \
		.build/release/dist/Pathsta-$(VERSION).dmg $(VERSION) $(BUILD_NUMBER)

ci: verify lint-release release-dry-run

open: generate
	open $(PROJECT)

clean: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(DERIVED_DATA) \
		clean
