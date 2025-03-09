# Ruby Codebase RAG

Rubyコードベース用のRAG（Retrieval-Augmented Generation）システム。コードベースを解析してベクトルデータベースを構築し、自然言語の質問に対して関連するコードを参照しながら回答を生成します。

## 特徴

- **コードチャンキング**: Rubyファイルを意味のある単位（クラス、モジュール、メソッドなど）で分割
- **エンベディング生成**: OpenRouter APIを使用してコードの意味を表すベクトルを生成
- **ベクトルデータベース**: 高速な類似検索のためのインデックスを構築
- **質問応答**: 自然言語の質問に対して関連コードを参照した回答を生成
- **MCPサーバー**: Clineから直接利用可能なインターフェース

## インストール

```bash
# リポジトリのクローン
git clone https://github.com/username/codebase-rag-ruby.git
cd codebase-rag-ruby

# 依存関係のインストール
bundle install
```

## 環境設定

APIキーは以下の方法で指定できます：

1. コマンドラインオプション: `--api-key` または `-k`
2. 環境変数: `OPENROUTER_API_KEY`
3. .envファイル: プロジェクトのルートに`.env`ファイルを作成

`.env`ファイルの例:

```
# OpenRouter API Key
OPENROUTER_API_KEY=your_api_key_here
```

## 使用方法

```bash
# RAGシステムの構築
bundle exec rake "rag:build[./lib,./rag-data]"

# 質問
bundle exec rake "rag:query[このプロジェクトのルーティングはどのように実装されていますか？,./rag-data]"

# MCPサーバーの起動
bundle exec rake "rag:mcp_server[./rag-data]"
```

パラメータの説明:
- `rag:build[ソースディレクトリ,出力先]`
- `rag:query[質問文,RAGデータディレクトリ]`
- `rag:mcp_server[RAGデータディレクトリ]`

デフォルト値:
- ソースディレクトリ: カレントディレクトリ (`.`)
- 出力先: `./rag-data`
- RAGデータディレクトリ: `./rag-data`

### Clineからの利用（MCPサーバー）

1. MCPサーバーを起動：

```bash
bundle exec rake "rag:mcp_server[./rag-data]"
```

2. Clineの設定ファイルに以下を追加：

```json
{
  "mcpServers": {
    "codebase-rag": {
      "command": "bundle",
      "args": ["exec", "rake", "rag:mcp_server[./rag-data]"],
      "cwd": "/path/to/codebase-rag-ruby",
      "env": {
        "OPENROUTER_API_KEY": "your-api-key"
      }
    }
  }
}
```

3. Clineから以下のように利用：

```
use_mcp_tool
server_name: codebase-rag
tool_name: query_codebase
arguments: {
  "question": "このプロジェクトのルーティングはどのように実装されていますか？"
}
```

## オプション

### buildコマンド

- `--src, -s`: ソースコードのルートディレクトリ（必須）
- `--output, -o`: RAGデータの出力先（デフォルト: `./rag-data`）
- `--api-key, -k`: OpenRouter API Key（環境変数 `OPENROUTER_API_KEY` でも設定可能）

### queryコマンド

- `<question>`: 質問文（必須）
- `--data, -d`: RAGデータのディレクトリ（デフォルト: `./rag-data`）
- `--api-key, -k`: OpenRouter API Key（環境変数 `OPENROUTER_API_KEY` でも設定可能）

### mcp-serverコマンド

- `--data, -d`: RAGデータのディレクトリ（デフォルト: `./rag-data`）
- `--api-key, -k`: OpenRouter API Key（環境変数 `OPENROUTER_API_KEY` でも設定可能）

## ライセンス

MIT
