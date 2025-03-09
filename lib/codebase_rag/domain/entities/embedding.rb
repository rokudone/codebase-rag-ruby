# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Entities
      # エンベディング結果
      # エンベディングベクトルを表す
      class EmbeddingResult
        # @return [String] ID
        attr_reader :id

        # @return [Array<Float>] エンベディングベクトル
        attr_reader :embedding

        # 初期化
        # @param id [String] ID
        # @param embedding [Array<Float>] エンベディングベクトル
        def initialize(id, embedding)
          @id = id
          @embedding = embedding
        end

        # JSONに変換
        # @return [Hash] JSON形式のハッシュ
        def to_json(*_args)
          {
            id: @id,
            embedding: @embedding
          }.to_json
        end

        # ハッシュに変換
        # @return [Hash] ハッシュ
        def to_h
          {
            id: @id,
            embedding: @embedding
          }
        end

        # コサイン類似度を計算
        # @param other [Array<Float>] 比較対象のベクトル
        # @return [Float] コサイン類似度
        def cosine_similarity(other)
          dot_product = 0.0
          magnitude_a = 0.0
          magnitude_b = 0.0

          @embedding.each_with_index do |a, i|
            b = other[i]
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
