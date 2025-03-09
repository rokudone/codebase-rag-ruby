# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "codebase_rag/version"

Gem::Specification.new do |spec|
  spec.name          = "codebase-rag-ruby"
  spec.version       = CodebaseRag::VERSION
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "Rubyコードベース用のRAG（Retrieval-Augmented Generation）システム"
  spec.description   = "Rubyコードベースを解析してベクトルデータベースを構築し、自然言語の質問に対して関連するコードを参照しながら回答を生成します。"
  spec.homepage      = "https://github.com/username/codebase-rag-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # 実行ファイルを指定
  spec.bindir        = "bin"
  spec.executables   = ["rb-rag"]

  # ライブラリファイルを指定
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  # 依存関係
  spec.add_dependency "parser", "~> 3.2.0"       # Rubyコードの解析
  spec.add_dependency "thor", "~> 1.2.0"         # CLIフレームワーク
  spec.add_dependency "faraday", "~> 2.7.0"      # HTTPクライアント
  spec.add_dependency "dotenv", "~> 2.8.0"       # 環境変数の管理
  spec.add_dependency "json", "~> 2.6.0"         # JSONの処理
  spec.add_dependency "modelcontextprotocol"     # MCP SDK

  # 開発時の依存関係
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12.0"
  spec.add_development_dependency "rubocop", "~> 1.50.0"
  spec.add_development_dependency "yard", "~> 0.9.0"
end
