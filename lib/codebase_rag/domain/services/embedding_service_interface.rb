# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # エンベディングサービスインターフェース
      # テキストからエンベディングベクトルを生成するサービスのインターフェース
      module EmbeddingServiceInterface
        # エンベディングを生成
        # @param text [String] テキスト
        # @return [CodebaseRag::Domain::Entities::EmbeddingResult] エンベディング結果
        def generate_embedding(text)
          raise NotImplementedError, "#{self.class}#generate_embedding is not implemented"
        end

        # バッチエンベディングを生成
        # @param texts [Array<Hash>] テキストの配列（id, contentを含むハッシュ）
        # @return [Array<CodebaseRag::Domain::Entities::EmbeddingResult>] エンベディング結果の配列
        def generate_batch_embeddings(texts)
          raise NotImplementedError, "#{self.class}#generate_batch_embeddings is not implemented"
        end
      end
    end
  end
end
