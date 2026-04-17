#!/bin/bash

# Development helper script for Claude Code Swift

set -e

case "$1" in
    build)
        echo "Building project..."
        swift build
        ;;
    run)
        echo "Running claude-code..."
        swift run claude-code "${@:2}"
        ;;
    test)
        echo "Running tests..."
        swift test
        ;;
    clean)
        echo "Cleaning build artifacts..."
        swift package clean
        rm -rf .build
        ;;
    release)
        echo "Building release version..."
        swift build -c release
        echo "Binary location: .build/release/claude-code"
        ;;
    install)
        echo "Installing to /usr/local/bin..."
        swift build -c release
        sudo cp .build/release/claude-code /usr/local/bin/
        echo "Installed successfully!"
        ;;
    *)
        echo "Usage: ./dev.sh {build|run|test|clean|release|install}"
        echo ""
        echo "Commands:"
        echo "  build    - Build the project"
        echo "  run      - Run the project"
        echo "  test     - Run tests"
        echo "  clean    - Clean build artifacts"
        echo "  release  - Build release version"
        echo "  install  - Install to /usr/local/bin"
        exit 1
        ;;
esac
