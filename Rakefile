# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :rag do
  desc "Build RAG system"
  task :build do
    if ARGV.length < 3
      puts "エラー: 引数が不足しています"
      puts "使用方法: bundle exec rake rag:build SOURCE_DIR OUTPUT_DIR"
      exit 1
    end

    src = ARGV[1]
    output = ARGV[2]

    # 引数を処理した後、ARGVをクリアする（他のタスクが実行されないように）
    ARGV.each { |a| task a.to_sym do ; end }

    puts "ソースディレクトリ: #{src}"
    puts "出力先: #{output}"

    # 直接Rubyコードを実行
    require "codebase_rag"
    require "dotenv"
    Dotenv.load

    # サービスの初期化
    api_key = ENV["OPENAI_API_KEY"]
    embedding_service = CodebaseRag::Infrastructure::External::OpenAIEmbeddingService.new(api_key)
    vector_store = CodebaseRag::Infrastructure::Repositories::VectorStore.new("code-chunks", api_key)

    # RAGシステムの構築
    puts "コードをチャンキングしています..."
    begin
      result = CodebaseRag::Application::Services::RagBuilder.build_rag_system(
        {
          source_dir: src,
          output_dir: output
        },
        embedding_service,
        vector_store
      )

      puts "RAGシステムの構築が完了しました"
      puts "\n出力ディレクトリ: #{result[:output_path]}"
    rescue => e
      puts "エラーが発生しました: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end

  desc "Query RAG system"
  task :query do
    if ARGV.length < 3
      puts "エラー: 引数が不足しています"
      puts "使用方法: bundle exec rake rag:query DATA_DIR QUESTION"
      exit 1
    end

    data = ARGV[1]
    question = ARGV[2]

    # 引数を処理した後、ARGVをクリアする（他のタスクが実行されないように）
    ARGV.each { |a| task a.to_sym do ; end }

    puts "質問: #{question}"
    puts "データディレクトリ: #{data}"

    # 直接Rubyコードを実行
    require "codebase_rag"
    require "dotenv"
    Dotenv.load

    # サービスの初期化
    api_key = ENV["OPENAI_API_KEY"]
    embedding_service = CodebaseRag::Infrastructure::External::OpenAIEmbeddingService.new(api_key)
    llm_service = CodebaseRag::Infrastructure::External::OpenAILLMService.new(api_key)

    # ベクトルストアファクトリ関数
    vector_store_factory = lambda do |collection_name|
      vector_store = CodebaseRag::Infrastructure::Repositories::VectorStore.new(collection_name, api_key)
      vector_store.reset
      vector_store
    end

    # 質問処理
    puts "回答を生成しています..."
    begin
      answer = CodebaseRag::Application::Services::RagQuery.query_rag_system(
        {
          question: question,
          data_dir: data
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
      puts e.backtrace.join("\n")
      exit 1
    end
  end

  desc "Start MCP server"
  task :mcp_server do
    if ARGV.length < 2
      puts "エラー: 引数が不足しています"
      puts "使用方法: bundle exec rake rag:mcp_server DATA_DIR"
      exit 1
    end

    data = ARGV[1]

    # 引数を処理した後、ARGVをクリアする（他のタスクが実行されないように）
    ARGV.each { |a| task a.to_sym do ; end }

    puts "データディレクトリ: #{data}"

    # 直接Rubyコードを実行
    require "codebase_rag"
    require "dotenv"
    Dotenv.load

    # サービスの初期化
    api_key = ENV["OPENAI_API_KEY"]

    puts "MCPサーバーを起動しています..."
    begin
      server = CodebaseRag::Infrastructure::Server::CodebaseRagServer.new(
        data_dir: data,
        api_key: api_key
      )

      server.run
    rescue => e
      puts "エラーが発生しました: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end
end
