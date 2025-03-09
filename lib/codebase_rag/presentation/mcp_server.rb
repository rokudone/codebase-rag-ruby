#!/usr/bin/env ruby
# frozen_string_literal: true

require "thor"
require "io/console"
require "dotenv"

# .envファイルを読み込む
Dotenv.load

module CodebaseRag
  module Presentation
    # MCPサーバーコマンド
    # MCPサーバーを起動するためのコマンド
    class MCPServerCommand < Thor::Group
      include Thor::Actions

      # コマンドの説明
      desc "コードベースRAG用のMCPサーバーを起動します"

      # オプション
      class_option :data, type: :string, aliases: "-d", default: "./rag-data", desc: "RAGデータのディレクトリ"
      class_option :api_key, type: :string, aliases: "-k", desc: "OpenRouter API Key", default: ENV["OPENROUTER_API_KEY"]

      # 実行
      def run
        # APIキーの確認
        api_key = options[:api_key]
        if api_key.nil? || api_key.empty?
          api_key = ask_for_api_key
        end

        puts "MCPサーバーを起動しています..."
        puts "データディレクトリ: #{options[:data]}"
        puts "Clineからこのサーバーを利用するには、Clineの設定ファイルに以下を追加してください:"
        puts <<~JSON
          {
            "mcpServers": {
              "codebase-rag": {
                "command": "rb-rag",
                "args": ["mcp-server", "--data", "#{options[:data]}"],
                "cwd": "#{Dir.pwd}",
                "env": {
                  "OPENROUTER_API_KEY": "#{api_key}"
                }
              }
            }
          }
        JSON

        server = CodebaseRag::Infrastructure::Server::CodebaseRagServer.new(
          data_dir: options[:data],
          api_key: api_key
        )

        server.run
      rescue => e
        puts "エラーが発生しました: #{e.message}"
        exit 1
      end

      private

      # APIキーを入力させる
      # @return [String] APIキー
      def ask_for_api_key
        print "OpenRouter API Keyを入力してください: "
        api_key = STDIN.noecho(&:gets).chomp
        puts
        if api_key.empty?
          puts "API Keyは必須です"
          exit 1
        end
        api_key
      end
    end
  end
end

# スタンドアロンで実行された場合のみMCPサーバーを起動
if $PROGRAM_NAME == __FILE__
  CodebaseRag::Presentation::MCPServerCommand.start(ARGV)
end
