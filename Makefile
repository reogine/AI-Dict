.PHONY: build run clean

build:
	swift build

run: build
	./.build/debug/AIDictApp

clean:
	rm -rf .build
