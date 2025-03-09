# frozen_string_literal: true

require "time"

module CodebaseRag
  module Domain
    module Entities
      # RAGメタデータ
      # RAGシステムのメタデータを表す
      class RagMetadata
        # @return [Time] 作成日時
        attr_reader :created_at

        # @return [Integer] チャンク数
        attr_reader :chunk_count

        # @return [String] ソースディレクトリ
        attr_reader :source_dir

        # @return [String] モデル名
        attr_reader :model_name

        # 初期化
        # @param created_at [Time] 作成日時
        # @param chunk_count [Integer] チャンク数
        # @param source_dir [String] ソースディレクトリ
        # @param model_name [String] モデル名
        def initialize(created_at, chunk_count, source_dir, model_name = "openai/text-embedding-3-small")
          @created_at = created_at
          @chunk_count = chunk_count
          @source_dir = source_dir
          @model_name = model_name
        end

        # JSONに変換
        # @return [Hash] JSON形式のハッシュ
        def to_json(*_args)
          {
            created_at: @created_at.iso8601,
            chunk_count: @chunk_count,
            source_dir: @source_dir,
            model_name: @model_name
          }.to_json
        end

        # ハッシュに変換
        # @return [Hash] ハッシュ
        def to_h
          {
            created_at: @created_at,
            chunk_count: @chunk_count,
            source_dir: @source_dir,
            model_name: @model_name
          }
        end
      end

      # MCPサーバーオプション
      # MCPサーバーの設定オプションを表す
      class CodebaseRagServerOptions
        # @return [String] データディレクトリ
        attr_reader :data_dir

        # @return [String] APIキー
        attr_reader :api_key

        # @return [String] ベースURL
        attr_reader :base_url

        # 初期化
        # @param options [Hash] オプション
        # @option options [String] :data_dir データディレクトリ
        # @option options [String] :api_key APIキー
        # @option options [String] :base_url ベースURL
        def initialize(options)
          @data_dir = options[:data_dir]
          @api_key = options[:api_key]
          @base_url = options[:base_url]
        end
      end
    end
  end
end
