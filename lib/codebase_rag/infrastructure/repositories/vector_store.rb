# frozen_string_literal: true

require "json"

module CodebaseRag
  module Infrastructure
    module Repositories
      # ベクトルストア
      # ベクトルデータベースの実装
      class VectorStore
        include CodebaseRag::Domain::Repositories::VectorStoreInterface

        # @return [String] コレクション名
        attr_reader :collection_name

        # @return [String] APIキー
        attr_reader :api_key

        # @return [Hash] チャンクデータ（id => チャンク）
        attr_reader :chunks

        # @return [Hash] エンベディングデータ（id => エンベディングベクトル）
        attr_reader :embeddings

        # 初期化
        # @param collection_name [String] コレクション名
        # @param api_key [String] APIキー
        def initialize(collection_name, api_key)
          @collection_name = collection_name
          @api_key = api_key
          @chunks = {}
          @embeddings = {}
        end

        # データをリセット
        # @return [void]
        def reset
          @chunks = {}
          @embeddings = {}
        end

        # チャンクを追加
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] コードチャンク
        # @param embeddings [Array<Array<Float>>] エンベディングベクトル
        # @return [void]
        def add_chunks(chunks, embeddings)
          chunks.each_with_index do |chunk, index|
            @chunks[chunk.id] = chunk
            @embeddings[chunk.id] = embeddings[index]
          end
        end

        # 類似チャンクを検索
        # @param query_embedding [Array<Float>] クエリのエンベディングベクトル
        # @param limit [Integer] 取得する最大数
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] 類似チャンク
        def search_similar_chunks(query_embedding, limit = 5)
          # コサイン類似度を計算して類似度の高い順にソート
          similarities = @embeddings.map do |id, embedding|
            similarity = cosine_similarity(query_embedding, embedding)
            [id, similarity]
          end

          # 類似度の高い順にソート
          sorted_similarities = similarities.sort_by { |_, similarity| -similarity }

          # 上位N件のチャンクを取得
          result = sorted_similarities.take(limit).map do |id, _|
            # idがシンボルの場合は文字列に変換
            string_id = id.to_s
            @chunks[string_id]
          end.compact

          result
        end

        # ファイルに保存
        # @param file_path [String] ファイルパス
        # @return [void]
        def save_to_file(file_path)
          data = {
            chunks: @chunks.values.map(&:to_h),
            embeddings: @embeddings
          }

          File.write(file_path, JSON.generate(data))
        end

        # ファイルから読み込み
        # @param file_path [String] ファイルパス
        # @return [void]
        def load_from_file(file_path)
          data = JSON.parse(File.read(file_path), symbolize_names: true)

          @chunks = {}
          @embeddings = {}

          data[:chunks].each do |chunk_data|
            chunk = CodebaseRag::Domain::Entities::CodeChunk.new(
              id: chunk_data[:id],
              content: chunk_data[:content],
              file_path: chunk_data[:file_path],
              start_line: chunk_data[:start_line],
              end_line: chunk_data[:end_line],
              type: chunk_data[:type],
              name: chunk_data[:name],
              context: chunk_data[:context],
              part_number: chunk_data[:part_number],
              total_parts: chunk_data[:total_parts],
              original_chunk_id: chunk_data[:original_chunk_id]
            )
            @chunks[chunk.id] = chunk
          end

          data[:embeddings].each do |id, embedding|
            @embeddings[id] = embedding
          end
        end

        private

        # コサイン類似度を計算
        # @param vec_a [Array<Float>] ベクトルA
        # @param vec_b [Array<Float>] ベクトルB
        # @return [Float] コサイン類似度
        def cosine_similarity(vec_a, vec_b)
          dot_product = 0.0
          magnitude_a = 0.0
          magnitude_b = 0.0

          vec_a.each_with_index do |a, i|
            b = vec_b[i]
            dot_product += a * b
            magnitude_a += a * a
            magnitude_b += b * b
          end

          magnitude_a = Math.sqrt(magnitude_a)
          magnitude_b = Math.sqrt(magnitude_b)

          return 0.0 if magnitude_a.zero? || magnitude_b.zero?

          dot_product / (magnitude_a * magnitude_b)
        end
      end
    end
  end
end
