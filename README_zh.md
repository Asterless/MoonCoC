# MoonCoc | [ENGLISH](README.md)

一个用 [MoonBit](https://docs.moonbitlang.com) 编写的极简构造演算 (CoC) 内核。它既可以作为库在您自己的项目中使用，也可以作为独立的交互式应用运行。

## 特性

- **纯函数内核**: 包含 `Term` ADT、替换、归约和可转换性检查等核心功能。
- **类型推断**: 实现了一个轻量级的类型检查器，支持宇宙层级和清晰的错误报告。
- **双使用模式**:
  1. **作为库**: 通过 `moon add` 集成到任何 MoonBit 项目中。
  2. **作为独立应用**: `git clone` 仓库后，可直接运行一个交互式 REPL。

## 使用方式

您可以根据需求选择以下任一方式使用 MoonCoc。

### 1. 作为独立的交互式应用 (用于快速体验和开发)

如果您想快速体验 CoC 内核或进行二次开发，建议直接克隆本仓库。

**步骤:**

1. **克隆仓库**

  ```bash
  git clone https://github.com/Asterless/MoonCoc.git
  cd MoonCoc
  ```

2. **运行 REPL**

  仓库的 `cmd/main.mbt` 文件提供了一个简单的 REPL ，使用 `repl_run_script` 方法输入 CoC 命令：
  
  ```moonbit
    let outputs = @coc.repl_run_script([
    "def id lam x sort 0 var x",
    "normalize app var id var y",
    ])
    println("Outputs: " + outputs.join(", "))
  ```

  确认命令完整无误后使用如下命令运行 `main.mbt`：
  
  ```bash
  moon run cmd/main.mbt
  ```

### 2. 作为库集成到您的项目中

如果想在您自己的 MoonBit 项目中使用 MoonCoc 的 API，请添加此包作为依赖。

**步骤:**

1. **添加依赖**

  ```bash
  moon add Asterless/MoonCoc
  ```

  在 `moon.pkg.json` 中添加：

  ```json
  {
    "import": [
        {
            "path": "Asterless/MoonCoc/src",
            "alias": "coc"
        }
    ],
  }
  ```

2. **在代码中使用**
  您可以调用 `repl_init`, `repl_process` 等函数来驱动 CoC 内核。

  ```moonbit
  fn my_app() {
    // 初始化 REPL 状态
    let state = @coc.repl_init()

    // 定义一个术语
    let step1 = @coc.repl_process(state, "def id lam x sort 0 var x")
    println(step1.output) // 输出: "Defined: id : Pi(x,Sort(0),Sort(0))"

    // 推断其类型
    let step2 = @coc.repl_process(step1.state, "infer var id")
    println(step2.output) // 输出: "Pi(x,Sort(0),Sort(0))"
  }
  ```

## 项目结构

```text
src/
  term.mbt          # Term 数据类型及相关操作 (Eq, Show, 构造函数)
  errors.mbt        # 自定义错误类型
  utils.mbt         # 辅助函数 (如宇宙层级计算)
  typing.mbt        # 类型上下文和类型推断核心逻辑
  repl.mbt          # REPL 实现
  test.mbt          # 测试用例
cmd/
  main.mbt          # 交互式 REPL 的入口文件
```

## 开发与贡献

欢迎参与贡献！请遵循以下约定：

- 修改代码后，请运行 `moon info && moon fmt` 来更新接口并格式化代码。
- 提交前，请运行 `moon test` 以确保所有测试用例都能通过。
- 如果您发现了 Bug 或有任何建议，欢迎提交 Issue。

## 许可证

本项目基于 [Apache-2.0](./LICENSE) 许可证。
