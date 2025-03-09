# frozen_string_literal: true

require "fileutils"
require "json"

module CodebaseRag
  module Application
    module Services
      # RAGビルダー
      # コードベースからRAGシステムを構築するサービス
      module RagBuilder
        module_function

        # RAGシステムを構築する
        # @param options [Hash] オプション
        # @param embedding_service [CodebaseRag::Domain::Services::EmbeddingServiceInterface] エンベディングサービス
        # @param vector_store [CodebaseRag::Domain::Repositories::VectorStoreInterface] ベクトルストア
        # @return [Hash] 構築結果
        def build_rag_system(options, embedding_service, vector_store)
          # 出力ディレクトリの作成
          FileUtils.mkdir_p(options[:output_dir])

          # コードチャンキング
          chunks = CodebaseRag::Domain::Services::Chunker.chunk_codebase(options[:source_dir])

          # チャンクデータの準備
          chunk_data = chunks.map do |chunk|
            {
              id: chunk.id,
              content: chunk.content
            }
          end

          # エンベディング生成
          embeddings = embedding_service.generate_batch_embeddings(chunk_data)

          # ベクトルデータベース構築
          vector_store.reset

          embedding_vectors = embeddings.map(&:embedding)
          vector_store.add_chunks(chunks, embedding_vectors)

          # 永続化
          vector_store_path = File.join(options[:output_dir], "vector-store.json")
          vector_store.save_to_file(vector_store_path)

          # メタデータの保存
          metadata = CodebaseRag::Domain::Entities::RagMetadata.new(
            Time.now,
            chunks.length,
            File.expand_path(options[:source_dir])
          )

          File.write(
            File.join(options[:output_dir], "metadata.json"),
            JSON.pretty_generate(JSON.parse(metadata.to_json))
          )

          {
            chunk_count: chunks.length,
            embedding_count: embeddings.length,
            output_path: File.expand_path(options[:output_dir])
          }
        end
      end
    end
  end
end
