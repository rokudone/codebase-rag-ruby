# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Repositories
      # ベクトルストアインターフェース
      # ベクトルデータベースの操作を定義するインターフェース
      module VectorStoreInterface
        # 初期化
        # @return [void]
        def initialize
          raise NotImplementedError, "#{self.class}#initialize is not implemented"
        end

        # チャンクを追加
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] コードチャンク
        # @param embeddings [Array<Array<Float>>] エンベディングベクトル
        # @return [void]
        def add_chunks(chunks, embeddings)
          raise NotImplementedError, "#{self.class}#add_chunks is not implemented"
        end

        # 類似チャンクを検索
        # @param query_embedding [Array<Float>] クエリのエンベディングベクトル
        # @param limit [Integer] 取得する最大数
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] 類似チャンク
        def search_similar_chunks(query_embedding, limit = 5)
          raise NotImplementedError, "#{self.class}#search_similar_chunks is not implemented"
        end

        # ファイルに保存
        # @param file_path [String] ファイルパス
        # @return [void]
        def save_to_file(file_path)
          raise NotImplementedError, "#{self.class}#save_to_file is not implemented"
        end

        # ファイルから読み込み
        # @param file_path [String] ファイルパス
        # @return [void]
        def load_from_file(file_path)
          raise NotImplementedError, "#{self.class}#load_from_file is not implemented"
        end
      end
    end
  end
end
