# frozen_string_literal: true

require "fileutils"
require "json"

module CodebaseRag
  module Application
    module Services
      # RAGクエリ
      # RAGシステムに質問するサービス
      module RagQuery
        module_function

        # RAGシステムに質問する
        # @param options [Hash] オプション
        # @param embedding_service [CodebaseRag::Domain::Services::EmbeddingServiceInterface] エンベディングサービス
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        # @param vector_store_factory [Proc] ベクトルストアファクトリ関数
        # @return [String] 回答
        def query_rag_system(options, embedding_service, llm_service, vector_store_factory)
          # ベクトルストアの読み込み
          vector_store_path = File.join(options[:data_dir], "vector-store.json")

          unless File.exist?(vector_store_path)
            raise "RAGデータが見つかりません: #{vector_store_path}"
          end

          # ベクトルストアの初期化
          vector_store = vector_store_factory.call("code-chunks")
          vector_store.load_from_file(vector_store_path)

          # クエリエンジンの初期化
          query_engine = CodebaseRag::Application::Services::QueryService.new(
            vector_store,
            embedding_service,
            llm_service
          )

          # 質問処理
          answer = query_engine.query(options[:question])
          answer
        end
      end
    end
  end
end
