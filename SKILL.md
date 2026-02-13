---
name: glm-plan-usage
displayName: GLM Plan Usage
version: 1.0.0
description: 查询 GLM 编码套餐使用统计，包括配额、模型使用和 MCP 工具使用情况
author: OpenClaw Community
license: MIT
tags:
  - glm
  - usage
  - monitoring
  - statistics
  - zhipu
  - chinese
requirements:
  - curl
  - jq
---

# GLM Plan Usage Skill

查询 GLM 编码套餐使用统计的 OpenClaw 技能。

## 功能特性

- **配额监控**: 查看 Token 使用量（5小时）和 MCP 使用量（1个月）
- **模型使用**: 显示 24 小时内的 Token 数和调用次数
- **工具使用**: 跟踪 24 小时内的 MCP 工具使用情况
- **自动检测**: 自动从 OpenClaw 配置中检测 GLM 编码套餐提供商
- **中文输出**: 专为智谱平台优化，提供中文输出

## 依赖要求

- **curl** - HTTP 客户端（通常预装）
- **jq** - JSON 处理器

如需安装 `jq`：
```bash
sudo apt-get install jq  # Linux
brew install jq           # macOS
```

## 安装

1. 将此仓库克隆到本地：
```bash
git clone https://github.com/OrientLuna/openclaw-glm-plan-usage.git
cd openclaw-glm-plan-usage
```

2. 复制技能文件到 OpenClaw 技能目录：
```bash
cp -r . ~/.openclaw/skills/glm-plan-usage/
chmod +x ~/.openclaw/skills/glm-plan-usage/scripts/query-usage.sh
```

3. 确保已配置 GLM 编码套餐提供商（见下方配置说明）

## 使用方法

### 直接运行脚本

```bash
bash ~/.openclaw/skills/glm-plan-usage/scripts/query-usage.sh
```

### 通过 OpenClaw 技能调用

```bash
openclaw /glm-plan-usage:usage-query
```

### 示例输出

```
📊 GLM 编码套餐使用统计

提供商: zhipu
统计时间: 2026-02-13 20:30:15

配额限制
---
  Token 使用 (5小时): 45.2%
  MCP 使用 (1个月):   12.3%  (15000/120000 秒) [LEVEL_4]

模型使用 (24小时)
---
  总 Token 数:  12,500,000
  总调用次数:  1,234

工具使用 (24小时)
---
  bash: 156 次
  file-read: 89 次
  web-search: 34 次
```

## 配置说明

技能会自动读取 `~/.openclaw/openclaw.json` 中的提供商配置。

### 示例配置

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "zhipu/glm-4-flash"
      }
    }
  },
  "models": {
    "providers": {
      "zhipu": {
        "baseUrl": "https://open.bigmodel.cn/api/coding/paas/v4",
        "apiKey": "your-api-key-here"
      }
    }
  }
}
```

**重要**: `baseUrl` 必须包含 `api/coding/paas/v4` 或 `open.bigmodel.cn`，技能才能识别其为 GLM 编码套餐提供商。

### 提供商检测逻辑

技能会检查以下条件来识别 GLM 编码套餐提供商：

1. `baseUrl` 包含 `api/coding/paas/v4` 或 `open.bigmodel.cn`
2. 提供商名称包含 `coding`、`glm-coding`、`zhipu` 或 `bigmodel`

## API 端点

技能查询三个监控端点：

| 端点 | 用途 |
|------|------|
| `/api/monitor/usage/quota/limit` | 配额百分比（5小时 Token，1个月 MCP） |
| `/api/monitor/usage/model-usage` | 24小时模型使用统计 |
| `/api/monitor/usage/tool-usage` | 24小时 MCP 工具使用 |

详见 [API 文档](references/api-endpoints.md)。

## 错误处理

脚本为常见问题提供友好的错误提示：

- 缺少依赖工具（curl、jq）
- 缺少或无效的 OpenClaw 配置
- 提供商未配置为 GLM 编码套餐
- API 认证失败
- 网络超时

## 故障排除

### "缺少依赖工具，请安装: jq"

使用包管理器安装 jq：
```bash
sudo apt-get install jq  # Linux
brew install jq           # macOS
```

### "未找到配置 GLM 编码套餐的提供商"

确保提供商的 `baseUrl` 包含 `api/coding/paas/v4`。更新配置：

```json
{
  "models": {
    "providers": {
      "your-provider": {
        "baseUrl": "https://open.bigmodel.cn/api/coding/paas/v4",
        "apiKey": "your-key"
      }
    }
  }
}
```

### "认证失败，请检查 API 密钥配置"

验证 API 密钥是否正确：
```bash
jq -r '.models.providers.zhipu.apiKey' ~/.openclaw/openclaw.json
```

## 贡献指南

欢迎贡献！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

## 致谢

- 原始实现: [zai-coding-plugins](https://github.com/zai-org/zai-coding-plugins)
- 参考实现: [opencode-glm-quota](https://github.com/guyinwonder168/opencode-glm-quota)
- OpenClaw 集成: 本技能

## 相关资源

- [OpenClaw 文档](https://openclaw.dev)
- [GLM 编码套餐](https://open.bigmodel.cn)
- [API 文档](references/api-endpoints.md)
- [安装指南](docs/INSTALLATION.md)
