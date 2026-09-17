.PHONY: bootstrap generate format lint build test verify open clean

PROJECT := Pathsta.xcodeproj
SCHEME := Pathsta
ARCHITECTURE := $(shell uname -m)
DESTINATION := platform=macOS,arch=$(ARCHITECTURE)
DERIVED_DATA := .build/DerivedData

bootstrap:
	brew bundle
	$(MAKE) generate

generate:
	xcodegen generate

format:
	swift-format format --in-place Package.swift
	swift-format format --in-place --recursive Sources Tests

lint:
	swift-format lint --strict Package.swift
	swift-format lint --strict --recursive Sources Tests
	swiftlint lint --strict

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

verify: format lint test

open: generate
	open $(PROJECT)

clean: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(DERIVED_DATA) \
		clean
