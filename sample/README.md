# サンプルTodoアプリケーション

シンプルなコマンドラインTodoアプリケーションです。このアプリケーションは、Ruby Codebase RAGシステムのサンプルプロジェクトとして作成されました。

## 機能

- Todoアイテムの追加
- Todoアイテムの一覧表示
- Todoアイテムの詳細表示
- Todoアイテムの完了/未完了の切り替え
- Todoアイテムの削除
- Todoアイテムの検索
- データのJSON形式での保存と読み込み

## 使い方

### Todoの追加

```bash
./bin/todo add "牛乳を買う"
./bin/todo add "レポートを書く" -d "明日までに提出する必要がある"
```

### Todoの一覧表示

```bash
# 未完了のTodoのみ表示
./bin/todo list

# 全てのTodoを表示（完了済みを含む）
./bin/todo list -a
```

### Todoの詳細表示

```bash
./bin/todo show ID
```

### Todoの完了/未完了の切り替え

```bash
./bin/todo toggle ID
```

### Todoの削除

```bash
./bin/todo remove ID
```

### Todoの検索

```bash
./bin/todo search "キーワード"
```

## ファイル構造

```
sample-todo-app/
├── lib/
│   ├── todo_app.rb    # アプリケーションのメインクラス
│   ├── todo_item.rb   # Todoアイテムクラス
│   └── todo_list.rb   # Todoリストクラス
├── bin/
│   └── todo           # コマンドラインインターフェース
└── README.md
```

## データ保存

Todoデータは、ユーザーのホームディレクトリに `.todo_app_data.json` というファイル名で保存されます。

## RAGシステムでの利用方法

このサンプルアプリケーションのコードベースに対して、Ruby Codebase RAGシステムを使用することができます。

### RAGシステムの構築

```bash
bundle exec rake rag:build ./sample ./rag-data
```

### 質問応答の実行

```bash
bundle exec rake rag:query "このTodoアプリケーションの機能は何ですか？" ./rag-data
```

### MCPサーバーの起動（オプション）

```bash
bundle exec rake rag:mcp_server ./rag-data
```

## サンプル質問

以下は、RAGシステムに対して質問できる例です：

- このTodoアプリケーションの機能は何ですか？
- Todoアイテムはどのようにデータを保存していますか？
- Todoリストクラスの主要なメソッドは何ですか？
- コマンドラインインターフェースはどのように実装されていますか？
