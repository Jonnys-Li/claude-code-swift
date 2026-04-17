# Claude Code Swift

Swift implementation of Claude Code - A complete refactor for learning purposes.

## Overview

This is a complete 1:1 refactor of [Claude Code](https://github.com/anthropics/claude-code) from TypeScript to Swift, designed as a learning project to understand the architecture of AI coding assistants and practice Swift development.

## Features (Planned)

- ✅ CLI interface with ArgumentParser
- 🚧 Core query engine with async/await
- 🚧 30+ built-in tools (Read, Write, Edit, Bash, etc.)
- 🚧 Full MCP protocol support (stdio/SSE/WebSocket/HTTP)
- 🚧 Terminal UI with swift-term
- 🚧 Session memory and persistence
- 🚧 Skills system
- 🚧 Remote execution

## Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 15.0+ (optional)

## Installation

```bash
git clone https://github.com/Jonnys-Li/claude-code-swift.git
cd claude-code-swift
swift build -c release
```

## Usage

```bash
swift run claude-code --version
```

## Development Roadmap

See [Design Document](docs/superpowers/specs/2026-04-17-claude-code-swift-refactor-design.md) for detailed implementation plan.

### Phase 1: Project Scaffold (Week 1) ✅
- [x] Swift Package setup
- [x] CLI framework
- [x] Configuration loading
- [ ] Test framework

### Phase 2: Query Engine Core (Week 2-3)
- [ ] Claude API client
- [ ] Query engine structure
- [ ] Message streaming
- [ ] Simple REPL

### Phase 3-12: See design document

## Architecture

```
┌─────────────────────────────────────────┐
│   CLI Entry Layer                        │
├─────────────────────────────────────────┤
│   REPL/TUI Layer                         │
├─────────────────────────────────────────┤
│   Query Engine                           │
├─────────────────────────────────────────┤
│   Tool System                            │
├─────────────────────────────────────────┤
│   Services Layer                         │
├─────────────────────────────────────────┤
│   Foundation Layer                       │
└─────────────────────────────────────────┘
```

## Testing

```bash
swift test
```

## Contributing

This is a personal learning project, but suggestions and feedback are welcome!

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Original [Claude Code](https://github.com/anthropics/claude-code) by Anthropic
- [claude-code-analysis](https://github.com/liuup/claude-code-analysis) for architecture insights

## Author

Created by [@Jonnys-Li](https://github.com/Jonnys-Li) as a learning project.
