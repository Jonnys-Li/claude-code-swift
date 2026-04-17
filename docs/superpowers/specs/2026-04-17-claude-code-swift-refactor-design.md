# Claude Code Swift重构设计文档

## 项目背景

### 目标
将Claude Code从TypeScript完整重构为Swift，用于学习目的。目标平台为macOS CLI应用。

### 范围
- 完整1:1功能重构（~512K行TypeScript代码）
- 支持所有30+内置工具
- 完整MCP协议实现（stdio/SSE/WebSocket/HTTP）
- 使用现有Swift TUI库构建终端界面
- 分阶段实现，每个阶段都有可运行版本
- 预计2-3个月全职开发完成

### 技术约束
- Swift 6.0+（利用最新并发特性）
- macOS 13.0+
- 仅支持macOS平台（初期）

---

## 整体架构

### 分层设计

```
┌─────────────────────────────────────────┐
│   CLI Entry Layer                        │
│   - ArgumentParser处理命令行参数         │
│   - 初始化配置和环境                      │
├─────────────────────────────────────────┤
│   REPL/TUI Layer                         │
│   - REPLController管理交互循环           │
│   - UI组件系统（基于swift-term）         │
│   - 用户输入处理和显示                    │
├─────────────────────────────────────────┤
│   Query Engine                           │
│   - 核心async/await执行循环              │
│   - 工具编排（并行/串行）                 │
│   - 流式响应处理                          │
├─────────────────────────────────────────┤
│   Tool System                            │
│   - ToolProtocol定义                     │
│   - 30+工具实现                          │
│   - 工具权限检查                          │
├─────────────────────────────────────────┤
│   Services Layer                         │
│   - ClaudeAPIClient（流式API调用）       │
│   - MCPClient（4种传输方式）             │
│   - SessionMemory（持久化）              │
│   - PermissionManager                    │
├─────────────────────────────────────────┤
│   Foundation Layer                       │
│   - Process执行                          │
│   - FileManager I/O                      │
│   - Configuration管理                    │
└─────────────────────────────────────────┘
```

### 核心设计原则

1. **协议优先（Protocol-Oriented）**
   - 所有工具实现`ToolProtocol`
   - 所有服务实现对应的Service协议
   - 便于测试和Mock

2. **Actor隔离**
   - `AppState` Actor保护全局状态
   - `SessionMemory` Actor管理会话数据
   - 避免数据竞争

3. **结构化并发**
   - 使用`async/await`替代回调
   - `TaskGroup`管理并行工具调用
   - 支持取消和超时

4. **类型安全**
   - `Codable`处理JSON序列化
   - 泛型确保API类型安全
   - `Result`类型处理错误

---

## 核心模块设计

### 1. Query Engine（查询引擎）

**职责**：执行用户查询的核心循环，协调Claude API调用和工具执行。

**核心类型**：

```swift
actor QueryEngine {
    let apiClient: ClaudeAPIClient
    let toolRegistry: ToolRegistry
    let memory: SessionMemory
    
    func execute(query: String) async throws -> AsyncStream<QueryEvent>
}

enum QueryEvent {
    case thinking(content: String)
    case toolCall(tool: String, input: ToolInput)
    case toolResult(tool: String, output: ToolOutput)
    case response(content: String)
    case error(Error)
}
```

**执行流程**：
1. 接收用户输入
2. 构建消息上下文（包含历史和工具定义）
3. 调用Claude API（流式）
4. 解析工具调用请求
5. 执行工具（支持并行/串行）
6. 将结果返回给Claude
7. 循环直到得到最终响应

**与TypeScript版本差异**：
- 用`AsyncStream`替代async generator
- 用`TaskGroup`管理并行工具调用
- 用Actor保护状态

---

### 2. Tool System（工具系统）

**职责**：定义工具接口，实现30+内置工具，管理工具权限。

**核心协议**：

```swift
protocol ToolProtocol {
    var name: String { get }
    var description: String { get }
    var inputSchema: JSONSchema { get }
    
    func execute(input: ToolInput, context: ToolContext) async throws -> ToolOutput
    func requiresPermission() -> Bool
}

struct ToolInput: Codable {
    let parameters: [String: AnyCodable]
}

struct ToolOutput: Codable {
    let content: String
    let metadata: [String: AnyCodable]?
}
```

**工具分类**：

| 类别 | 工具 | 优先级 |
|------|------|--------|
| 文件操作 | Read, Write, Edit, Glob | P0 |
| 代码搜索 | Grep | P0 |
| 命令执行 | Bash | P0 |
| Agent | Agent, SendMessage | P1 |
| Git | (通过Bash实现) | P1 |
| Web | WebFetch, WebSearch | P2 |
| 任务管理 | TaskCreate, TaskUpdate, TaskList | P2 |
| 其他 | Cron, Skill, AskUserQuestion等 | P3 |

**权限系统**：

```swift
actor PermissionManager {
    enum PermissionMode {
        case alwaysAllow
        case alwaysAsk
        case promptBased(patterns: [String])
    }
    
    func checkPermission(tool: String, input: ToolInput) async -> Bool
}
```

---

### 3. MCP Client（模型上下文协议客户端）

**职责**：实现完整的MCP协议，支持4种传输方式和OAuth认证。

**核心架构**：

```swift
protocol MCPTransport {
    func connect() async throws
    func send(_ message: MCPMessage) async throws
    func receive() async throws -> AsyncStream<MCPMessage>
    func disconnect() async throws
}

class StdioTransport: MCPTransport { }
class SSETransport: MCPTransport { }
class WebSocketTransport: MCPTransport { }
class HTTPTransport: MCPTransport { }

actor MCPClient {
    let transport: MCPTransport
    let auth: MCPAuthProvider?
    
    func listTools() async throws -> [MCPTool]
    func callTool(name: String, arguments: [String: Any]) async throws -> MCPResult
}
```

**实现要点**：
- 使用Swift NIO处理网络传输
- OAuth流程使用ASWebAuthenticationSession
- 连接池和重连机制
- 超时和错误处理

---

### 4. REPL/TUI Layer（交互界面层）

**职责**：提供终端用户界面，处理用户输入，显示执行结果。

**技术选型**：
- 使用`swift-term`或`Ratatui-Swift`作为TUI框架
- 如果现有库不满足需求，考虑封装ncurses

**核心组件**：

```swift
class REPLController {
    let engine: QueryEngine
    let ui: TUIRenderer
    
    func start() async throws
    func handleInput(_ input: String) async
    func displayEvent(_ event: QueryEvent) async
}

protocol TUIRenderer {
    func render(state: UIState) async
    func clear() async
    func showSpinner(message: String) async
}
```

**UI状态管理**：

```swift
struct UIState {
    var messages: [Message]
    var currentThinking: String?
    var toolExecutions: [ToolExecution]
    var inputPrompt: String
}
```

**与React/Ink的映射**：
- 组件 → Swift struct/class
- State → @Published属性或Actor
- 渲染 → 手动调用render方法

---

### 5. Memory System（内存系统）

**职责**：管理会话历史、自动记忆、压缩和持久化。

**核心设计**：

```swift
actor SessionMemory {
    private var messages: [Message]
    private let storage: MemoryStorage
    
    func append(_ message: Message) async
    func getContext(maxTokens: Int) async -> [Message]
    func compress() async throws
    func save() async throws
}

protocol MemoryStorage {
    func load() async throws -> [Message]
    func save(_ messages: [Message]) async throws
}

class FileMemoryStorage: MemoryStorage {
    let directory: URL
    // 实现基于文件的持久化
}
```

**内存层级**：
1. Session Memory（会话内存）
2. Auto Memory（自动记忆，~/.claude/memory/）
3. Transcript（完整对话记录）

**压缩策略**：
- 当上下文超过阈值时触发
- 保留最近N条消息
- 压缩旧消息为摘要

---

### 6. API Client（Claude API客户端）

**职责**：与Anthropic Claude API通信，处理流式响应。

**核心实现**：

```swift
actor ClaudeAPIClient {
    let apiKey: String
    let baseURL: URL
    
    func createMessage(
        messages: [Message],
        tools: [Tool],
        stream: Bool
    ) async throws -> AsyncStream<MessageChunk>
}

struct Message: Codable {
    let role: Role
    let content: [ContentBlock]
}

enum ContentBlock: Codable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: Any])
    case toolResult(id: String, content: String)
}
```

**流式处理**：
- 使用URLSession的`bytes`属性
- 解析Server-Sent Events格式
- 增量解析JSON

---

## 开发阶段规划

### 阶段1：项目脚手架（1周）

**目标**：建立项目结构，配置开发环境。

**任务**：
- 创建Swift Package
- 配置依赖（ArgumentParser, Swift NIO等）
- 实现基础CLI框架
- 设置测试环境
- 实现Configuration加载

**验收标准**：
- 可以运行`swift run claude-code --version`
- 可以加载settings.json配置
- 单元测试框架就绪

---

### 阶段2：Query Engine核心（1.5周）

**目标**：实现核心查询循环，不包含工具执行。

**任务**：
- 实现ClaudeAPIClient
- 实现QueryEngine基础结构
- 实现消息流处理
- 实现简单的REPL（无TUI）

**验收标准**：
- 可以发送消息给Claude并接收响应
- 支持流式输出
- 可以进行多轮对话

---

### 阶段3：基础工具系统（1周）

**目标**：实现工具协议和3个核心工具。

**任务**：
- 定义ToolProtocol
- 实现ToolRegistry
- 实现Read, Write, Bash工具
- 集成工具到QueryEngine

**验收标准**：
- Claude可以调用Read读取文件
- Claude可以调用Write创建文件
- Claude可以调用Bash执行命令

---

### 阶段4：权限系统（3天）

**目标**：实现工具权限检查和用户确认。

**任务**：
- 实现PermissionManager
- 实现权限模式（always-allow, always-ask, prompt-based）
- 实现用户确认UI

**验收标准**：
- 危险操作需要用户确认
- 可以配置权限模式
- 权限决策可以持久化

---

### 阶段5：完整REPL（1周）

**目标**：实现完整的终端UI。

**任务**：
- 集成swift-term或选定的TUI库
- 实现消息显示组件
- 实现工具执行状态显示
- 实现输入处理

**验收标准**：
- 有美观的终端界面
- 可以显示思考过程
- 可以显示工具执行状态
- 支持多行输入

---

### 阶段6：内存系统（1周）

**目标**：实现会话历史和持久化。

**任务**：
- 实现SessionMemory
- 实现FileMemoryStorage
- 实现上下文压缩
- 实现Auto Memory

**验收标准**：
- 会话历史可以持久化
- 重启后可以恢复会话
- 长对话可以自动压缩
- Auto Memory可以跨会话使用

---

### 阶段7：完整工具集（2周）

**目标**：实现剩余27个工具。

**任务**：
- 文件操作：Edit, Glob, Grep
- Agent系统：Agent, SendMessage
- 任务管理：TaskCreate, TaskUpdate, TaskList, TaskGet
- Web：WebFetch, WebSearch
- 其他：AskUserQuestion, Cron, Skill等

**验收标准**：
- 所有30+工具可用
- 每个工具有单元测试
- 工具行为与TypeScript版本一致

---

### 阶段8：MCP Client - Stdio（1周）

**目标**：实现MCP协议的stdio传输。

**任务**：
- 实现MCP消息协议
- 实现StdioTransport
- 实现MCPClient核心
- 实现工具发现和调用

**验收标准**：
- 可以连接stdio MCP服务器
- 可以列出服务器提供的工具
- 可以调用MCP工具

---

### 阶段9：MCP Client - 网络传输（1.5周）

**目标**：实现SSE, WebSocket, HTTP传输。

**任务**：
- 实现SSETransport（基于URLSession）
- 实现WebSocketTransport（基于Swift NIO）
- 实现HTTPTransport
- 实现连接池和重连

**验收标准**：
- 支持所有4种传输方式
- 网络错误可以自动重连
- 支持并发连接多个服务器

---

### 阶段10：MCP OAuth（3天）

**目标**：实现OAuth认证流程。

**任务**：
- 实现OAuth 2.0流程
- 集成ASWebAuthenticationSession
- 实现token存储和刷新
- 实现step-up检测

**验收标准**：
- 可以通过OAuth连接MCP服务器
- Token可以安全存储
- Token过期可以自动刷新

---

### 阶段11：Skills系统（1周）

**目标**：实现技能加载和执行。

**任务**：
- 实现Skill加载器
- 实现Skill执行
- 移植核心Skills
- 实现Skill工具

**验收标准**：
- 可以加载和执行Skills
- 核心Skills可用（commit, review-pr等）
- Skill工具可以调用Skills

---

### 阶段12：远程执行和Bridge（1周）

**目标**：实现分布式执行能力。

**任务**：
- 实现Remote协议
- 实现Bridge服务器
- 实现远程工具调用
- 实现会话同步

**验收标准**：
- 可以在远程机器执行工具
- 会话状态可以同步
- 支持多客户端连接

---

## 技术细节

### Swift Concurrency使用

**async/await模式**：
```swift
// TypeScript async generator
async function* query() {
    yield { type: 'thinking' }
    const result = await callAPI()
    yield { type: 'response', content: result }
}

// Swift AsyncStream
func query() -> AsyncStream<QueryEvent> {
    AsyncStream { continuation in
        Task {
            continuation.yield(.thinking)
            let result = await callAPI()
            continuation.yield(.response(result))
            continuation.finish()
        }
    }
}
```

**并行工具调用**：
```swift
await withTaskGroup(of: ToolOutput.self) { group in
    for tool in parallelTools {
        group.addTask {
            try await tool.execute(input: input, context: context)
        }
    }
    
    for await result in group {
        results.append(result)
    }
}
```

### 错误处理

**使用Result类型**：
```swift
enum ToolError: Error {
    case invalidInput(String)
    case executionFailed(String)
    case permissionDenied
    case timeout
}

func executeTool() async -> Result<ToolOutput, ToolError> {
    do {
        let output = try await tool.execute()
        return .success(output)
    } catch {
        return .failure(.executionFailed(error.localizedDescription))
    }
}
```

### 进程管理

**使用Process API**：
```swift
actor ProcessExecutor {
    func execute(command: String, args: [String]) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessOutput(stdout: output, stderr: error, exitCode: process.terminationStatus))
            }
        }
    }
}
```

### JSON Schema处理

**使用Codable + 动态类型**：
```swift
struct JSONSchema: Codable {
    let type: String
    let properties: [String: PropertySchema]?
    let required: [String]?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    // 实现Codable协议...
}
```

---

## 测试策略

### 单元测试

**每个模块都有对应的测试**：
- `QueryEngineTests`
- `ToolRegistryTests`
- `MCPClientTests`
- 每个工具的测试

**使用XCTest框架**：
```swift
final class QueryEngineTests: XCTestCase {
    func testBasicQuery() async throws {
        let engine = QueryEngine(apiClient: MockAPIClient())
        let stream = try await engine.execute(query: "Hello")
        
        var events: [QueryEvent] = []
        for await event in stream {
            events.append(event)
        }
        
        XCTAssertTrue(events.contains { 
            if case .response = $0 { return true }
            return false
        })
    }
}
```

### 集成测试

**测试完整流程**：
- 用户输入 → 工具调用 → 结果返回
- MCP连接 → 工具发现 → 工具调用
- 会话持久化 → 恢复 → 继续对话

### Mock策略

**Mock外部依赖**：
```swift
class MockAPIClient: ClaudeAPIClient {
    var responses: [String] = []
    
    override func createMessage() async throws -> AsyncStream<MessageChunk> {
        // 返回预设响应
    }
}
```

---

## 依赖管理

### Swift Package Manager

**Package.swift**：
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeCode",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "claude-code", targets: ["ClaudeCode"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.62.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.19.0"),
        // TUI库（待选定）
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCode",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "ClaudeCodeTests",
            dependencies: ["ClaudeCode"]
        )
    ]
)
```

### 关键依赖

| 依赖 | 用途 | 版本 |
|------|------|------|
| swift-argument-parser | CLI参数解析 | 1.3+ |
| swift-nio | 异步网络 | 2.62+ |
| async-http-client | HTTP客户端 | 1.19+ |
| swift-term (TBD) | TUI框架 | TBD |

---

## 风险和挑战

### 高风险项

1. **TUI框架选择**
   - 风险：现有Swift TUI库可能不成熟
   - 缓解：提前调研，必要时自建简化版本

2. **MCP协议复杂度**
   - 风险：4种传输方式实现工作量大
   - 缓解：分阶段实现，先stdio后网络

3. **异步流处理**
   - 风险：Swift Concurrency与TypeScript async generator语义差异
   - 缓解：深入学习AsyncStream，编写原型验证

### 中风险项

4. **进程管理**
   - 风险：Swift Process API功能有限
   - 缓解：必要时使用C库封装

5. **性能优化**
   - 风险：Swift版本可能比Node.js慢
   - 缓解：使用Instruments分析，优化热点

6. **跨平台兼容**
   - 风险：初期只支持macOS
   - 缓解：设计时考虑跨平台，使用协议抽象

---

## 成功标准

### 功能完整性
- [ ] 所有30+工具可用
- [ ] MCP协议完整支持
- [ ] 会话持久化和恢复
- [ ] Skills系统可用
- [ ] 远程执行可用

### 性能指标
- [ ] 启动时间 < 1秒
- [ ] 工具调用延迟 < 100ms
- [ ] 内存占用 < 200MB（空闲）
- [ ] CPU占用 < 10%（空闲）

### 代码质量
- [ ] 单元测试覆盖率 > 70%
- [ ] 所有公开API有文档
- [ ] 无编译警告
- [ ] 通过SwiftLint检查

### 用户体验
- [ ] 终端UI流畅无卡顿
- [ ] 错误信息清晰易懂
- [ ] 支持中断和恢复
- [ ] 配置简单直观

---

## 后续扩展

### 短期（3-6个月）
- iOS应用版本
- 更多内置工具
- 性能优化
- 更好的错误处理

### 长期（6-12个月）
- Linux支持
- 插件系统
- 图形界面
- 分布式执行优化

---

## 参考资料

### 源码分析
- `/tmp/claude-code-analysis/` - TypeScript源码分析
- `/tmp/claude-code-analysis/analysis/` - 架构文档

### Swift资源
- Swift Concurrency官方文档
- Swift NIO文档
- Swift Package Manager指南

### 协议规范
- MCP协议规范
- Claude API文档
- Server-Sent Events规范

