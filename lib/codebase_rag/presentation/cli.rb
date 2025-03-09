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
      option :evaluate, type: :boolean, aliases: "-e", default: false, desc: "回答を評価する"
      option :evaluation_log, type: :string, default: nil, desc: "評価ログファイルパス（デフォルトは{data_dir}/evaluation.jsonl）"
      option :feedback, type: :boolean, aliases: "-f", default: false, desc: "フィードバックを有効にする"
      option :feedback_log, type: :string, default: nil, desc: "フィードバックログファイルパス（デフォルトは{data_dir}/feedback.jsonl）"
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
          "gpt-4o"
        )

        # ベクトルストアファクトリ関数
        vector_store_factory = lambda do |collection_name|
          vector_store = CodebaseRag::Infrastructure::Repositories::VectorStore.new(collection_name, api_key)
          vector_store.reset
          vector_store
        end

        # 評価ログファイルパスの設定
        evaluation_log_file = options[:evaluation_log] || File.join(options[:data], "evaluation.jsonl")

        # フィードバックログファイルパスの設定
        feedback_log_file = options[:feedback_log] || File.join(options[:data], "feedback.jsonl")

        # 評価モードが有効な場合はメッセージを表示
        if options[:evaluate]
          puts "評価モードが有効です（ログファイル: #{evaluation_log_file}）"
        end

        # フィードバックモードが有効な場合はメッセージを表示
        if options[:feedback]
          puts "フィードバックモードが有効です（ログファイル: #{feedback_log_file}）"
        end

        # 質問処理
        puts "回答を生成しています..."
        answer = CodebaseRag::Application::Services::RagQuery.query_rag_system(
          {
            question: question,
            data_dir: options[:data],
            evaluation_mode: options[:evaluate],
            evaluation_log_file: evaluation_log_file,
            feedback_mode: options[:feedback],
            feedback_log_file: feedback_log_file
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

      desc "evaluate", "RAGシステムの評価結果を集計して表示する"
      option :data, type: :string, aliases: "-d", default: "./rag-data", desc: "RAGデータのディレクトリ"
      option :log, type: :string, aliases: "-l", default: nil, desc: "評価ログファイルパス（デフォルトは{data_dir}/evaluation.jsonl）"
      def evaluate
        # 評価ログファイルパスの設定
        log_file = options[:log] || File.join(options[:data], "evaluation.jsonl")

        # ログファイルが存在しない場合はエラー
        unless File.exist?(log_file)
          puts "評価ログファイルが見つかりません: #{log_file}"
          puts "先に評価モードで質問を実行してください: rb-rag query \"質問\" --data #{options[:data]} --evaluate"
          exit 1
        end

        # 評価結果を集計
        puts "評価結果を集計しています..."
        results = CodebaseRag::Domain::Services::Evaluator.aggregate_evaluations(log_file)

        if results.empty?
          puts "評価結果がありません"
          exit 1
        end

        # 集計結果を表示
        puts "\n評価結果の集計:"
        puts "----------------"

        metrics = ["関連性", "正確性", "完全性", "簡潔性", "コード参照", "総合スコア"]
        metrics.each do |metric|
          if results[metric]
            puts "#{metric}: 平均 #{results[metric][:average].round(2)} (#{results[metric][:count]}件, 最小 #{results[metric][:min]}, 最大 #{results[metric][:max]})"
          end
        end

        # 最高評価と最低評価の例を表示
        if results[:examples]
          puts "\n最高評価の例:"
          puts "質問: #{results[:examples][:best][:question]}"
          puts "スコア: #{results[:examples][:best][:score]}"

          puts "\n最低評価の例:"
          puts "質問: #{results[:examples][:worst][:question]}"
          puts "スコア: #{results[:examples][:worst][:score]}"
        end

        puts "\n評価ログファイル: #{log_file}"
      rescue => e
        puts "エラーが発生しました: #{e.message}"
        exit 1
      end

      desc "feedback FEEDBACK_ID RATING", "RAGシステムの回答にフィードバックを提供する"
      option :data, type: :string, aliases: "-d", default: "./rag-data", desc: "RAGデータのディレクトリ"
      option :log, type: :string, aliases: "-l", default: nil, desc: "フィードバックログファイルパス（デフォルトは{data_dir}/feedback.jsonl）"
      option :comment, type: :string, aliases: "-c", desc: "フィードバックコメント"
      def feedback(feedback_id, rating)
        # 評価値を整数に変換
        rating = rating.to_i

        # 評価値の範囲チェック
        unless (1..5).include?(rating)
          puts "評価は1から5の整数で指定してください"
          exit 1
        end

        # フィードバックログファイルパスの設定
        log_file = options[:log] || File.join(options[:data], "feedback.jsonl")

        # フィードバックを記録
        begin
          feedback_id = CodebaseRag::Domain::Services::FeedbackCollector.record_feedback(
            "", # 質問（フィードバックIDから取得するため空）
            "", # 回答（フィードバックIDから取得するため空）
            rating,
            options[:comment],
            log_file
          )

          puts "フィードバックを記録しました（ID: #{feedback_id}, 評価: #{rating}）"
          puts "コメント: #{options[:comment]}" if options[:comment]
        rescue => e
          puts "エラーが発生しました: #{e.message}"
          exit 1
        end
      end

      desc "feedback-stats", "RAGシステムのフィードバック統計を表示する"
      option :data, type: :string, aliases: "-d", default: "./rag-data", desc: "RAGデータのディレクトリ"
      option :log, type: :string, aliases: "-l", default: nil, desc: "フィードバックログファイルパス（デフォルトは{data_dir}/feedback.jsonl）"
      def feedback_stats
        # フィードバックログファイルパスの設定
        log_file = options[:log] || File.join(options[:data], "feedback.jsonl")

        # ログファイルが存在しない場合はエラー
        unless File.exist?(log_file)
          puts "フィードバックログファイルが見つかりません: #{log_file}"
          puts "先にフィードバックを提供してください: rb-rag feedback [ID] [1-5] --comment \"コメント\""
          exit 1
        end

        # フィードバックを集計
        puts "フィードバックを集計しています..."
        results = CodebaseRag::Domain::Services::FeedbackCollector.aggregate_feedback(log_file)

        if results.empty?
          puts "フィードバックがありません"
          exit 1
        end

        # 集計結果を表示
        puts "\nフィードバック統計:"
        puts "----------------"
        puts "フィードバック数: #{results[:count]}"
        puts "平均評価: #{results[:average_rating].round(2)}"

        puts "\n評価分布:"
        results[:rating_distribution].sort.each do |rating, count|
          puts "#{rating}星: #{count}件 (#{(count.to_f / results[:count] * 100).round(1)}%)"
        end

        # 最高評価と最低評価の例を表示
        if results[:best_examples] && !results[:best_examples].empty?
          puts "\n最高評価の例:"
          results[:best_examples].each do |example|
            puts "ID: #{example[:id]}, 評価: #{example[:rating]}"
            puts "コメント: #{example[:comment]}" if example[:comment]
            puts
          end
        end

        if results[:worst_examples] && !results[:worst_examples].empty?
          puts "\n最低評価の例:"
          results[:worst_examples].each do |example|
            puts "ID: #{example[:id]}, 評価: #{example[:rating]}"
            puts "コメント: #{example[:comment]}" if example[:comment]
            puts
          end
        end

        puts "\nフィードバックログファイル: #{log_file}"
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
