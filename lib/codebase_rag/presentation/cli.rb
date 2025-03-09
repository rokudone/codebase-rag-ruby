#!/usr/bin/env ruby
# frozen_string_literal: true

require "thor"
require "io/console"
require "dotenv"

# .envファイルを読み込む
Dotenv.load

module CodebaseRag
  module Presentation
    # CLI
    # コマンドラインインターフェース
    class CLI < Thor
      # クラスオプションは定義しない

      desc "build", "コードベースからRAGシステムを構築"
      option :src, type: :string, aliases: "-s", required: true, desc: "ソースコードのルートディレクトリ"
      option :output, type: :string, aliases: "-o", default: "./rag-data", desc: "RAGデータの出力先"
      def build
        # APIキーの取得
        api_key = ENV["OPENAI_API_KEY"]
        if api_key.nil? || api_key.empty?
          api_key = ask_for_api_key
        end

        # スピナーの初期化（ここではシンプルなメッセージ出力）
        puts "コードをチャンキングしています..."

        # サービスの初期化
        embedding_service = CodebaseRag::Infrastructure::External::OpenAIEmbeddingService.new(
          api_key
        )

        vector_store = CodebaseRag::Infrastructure::Repositories::VectorStore.new("code-chunks", api_key)

        # RAGシステムの構築
        result = CodebaseRag::Application::Services::RagBuilder.build_rag_system(
          {
            source_dir: options[:src],
            output_dir: options[:output]
          },
          embedding_service,
          vector_store
        )

        puts "RAGシステムの構築が完了しました"
        puts "\n出力ディレクトリ: #{result[:output_path]}"
        puts "\n使用方法:"
        puts "  rb-rag query \"質問文\" --data #{options[:output]}"
        puts "  rb-rag mcp-server --data #{options[:output]} (Clineから利用する場合)"
      rescue => e
        puts "エラーが発生しました: #{e.message}"
        exit 1
      end

      desc "query QUESTION", "RAGシステムに質問する"
      option :data, type: :string, aliases: "-d", default: "./rag-data", desc: "RAGデータのディレクトリ"
      def query(question)
        # APIキーの取得
        api_key = ENV["OPENAI_API_KEY"]
        if api_key.nil? || api_key.empty?
          api_key = ask_for_api_key
        end

        # スピナーの初期化（ここではシンプルなメッセージ出力）
        puts "RAGデータを読み込んでいます..."

        # メタデータの読み込み
        metadata_path = File.join(options[:data], "metadata.json")
        if File.exist?(metadata_path)
          metadata_json = JSON.parse(File.read(metadata_path), symbolize_names: true)
          metadata = CodebaseRag::Domain::Entities::RagMetadata.new(
            Time.parse(metadata_json[:created_at]),
            metadata_json[:chunk_count],
            metadata_json[:source_dir],
            metadata_json[:model_name]
          )
          puts "RAGデータ情報: #{metadata.chunk_count}個のチャンク, 作成日時: #{metadata.created_at}"
        end

        # サービスの初期化
        embedding_service = CodebaseRag::Infrastructure::External::OpenAIEmbeddingService.new(
          api_key
        )

        llm_service = CodebaseRag::Infrastructure::External::OpenAILLMService.new(
          api_key,
          "gpt-4o-mini"
        )

        # ベクトルストアファクトリ関数
        vector_store_factory = lambda do |collection_name|
          vector_store = CodebaseRag::Infrastructure::Repositories::VectorStore.new(collection_name, api_key)
          vector_store.reset
          vector_store
        end

        # 質問処理
        puts "回答を生成しています..."
        answer = CodebaseRag::Application::Services::RagQuery.query_rag_system(
          {
            question: question,
            data_dir: options[:data]
          },
          embedding_service,
          llm_service,
          vector_store_factory
        )

        puts "\n質問:"
        puts question
        puts "\n回答:"
        puts answer
      rescue => e
        puts "エラーが発生しました: #{e.message}"
        exit 1
      end

      desc "mcp-server", "MCPサーバーを起動する"
      option :data, type: :string, aliases: "-d", default: "./rag-data", desc: "RAGデータのディレクトリ"
      def mcp_server
        # APIキーの取得
        api_key = ENV["OPENAI_API_KEY"]
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
                  "OPENAI_API_KEY": "#{api_key}"
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
        print "OpenAI API Keyを入力してください: "
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

# スタンドアロンで実行された場合のみCLIを起動
if $PROGRAM_NAME == __FILE__
  CodebaseRag::Presentation::CLI.start(ARGV)
end
