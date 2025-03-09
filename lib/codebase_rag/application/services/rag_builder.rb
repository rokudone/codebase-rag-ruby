# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "../../domain/services/semantic_chunker"
require_relative "../../domain/services/hierarchy_visualizer"

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
          # APIキーをオプションに追加
          options[:api_key] ||= embedding_service.api_key
          # 出力ディレクトリの作成
          FileUtils.mkdir_p(options[:output_dir])

          # コードチャンキング
          chunks = CodebaseRag::Domain::Services::Chunker.chunk_codebase(options[:source_dir])

          # セマンティックチャンキング（一時的に無効化）
          # puts "セマンティックチャンキングを開始します..."
          # llm_service = CodebaseRag::Infrastructure::External::OpenAILLMService.new(
          #   options[:api_key],
          #   "gpt-4o"
          # )

          # # 進捗表示を有効にしてセマンティックチャンクを生成
          # semantic_chunks = CodebaseRag::Domain::Services::SemanticChunker.create_semantic_chunks(
          #   chunks,
          #   llm_service,
          #   true # verbose = true
          # )

          # puts "セマンティックチャンキング完了: #{semantic_chunks.length}個のセマンティックチャンクを生成しました"

          # # 通常のチャンクとセマンティックチャンクを結合
          # all_chunks = chunks + semantic_chunks

          # セマンティックチャンキングを無効化したため、通常のチャンクのみを使用
          all_chunks = chunks
          puts "セマンティックチャンキングは一時的に無効化されています"

          # チャンクデータの準備
          chunk_data = all_chunks.map do |chunk|
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

          # 階層構造の視覚化
          hierarchy_text = CodebaseRag::Domain::Services::HierarchyVisualizer.visualize_hierarchy(all_chunks)
          File.write(
            File.join(options[:output_dir], "hierarchy.md"),
            hierarchy_text
          )

          # 階層構造のJSON出力
          CodebaseRag::Domain::Services::HierarchyVisualizer.export_hierarchy_json(
            all_chunks,
            File.join(options[:output_dir], "hierarchy.json")
          )

          puts "階層構造を出力しました"

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
