# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Entities
      # コードチャンク
      # コードベースから抽出された意味のある単位（クラス、モジュール、メソッドなど）を表す
      class CodeChunk
        # @return [String] チャンクのID
        attr_reader :id

        # @return [String] コードの内容
        attr_reader :content

        # @return [String] ファイルパス
        attr_reader :file_path

        # @return [Integer] 開始行
        attr_reader :start_line

        # @return [Integer] 終了行
        attr_reader :end_line

        # @return [String] チャンクの種類（class, module, method, other）
        attr_reader :type

        # @return [String] チャンクの名前
        attr_reader :name

        # @return [String] コンテキスト情報
        attr_reader :context

        # 初期化
        # @param options [Hash] オプション
        # @option options [String] :id チャンクのID
        # @option options [String] :content コードの内容
        # @option options [String] :file_path ファイルパス
        # @option options [Integer] :start_line 開始行
        # @option options [Integer] :end_line 終了行
        # @option options [String] :type チャンクの種類
        # @option options [String] :name チャンクの名前
        # @option options [String] :context コンテキスト情報
        def initialize(options)
          @id = options[:id]
          @content = options[:content]
          @file_path = options[:file_path]
          @start_line = options[:start_line]
          @end_line = options[:end_line]
          @type = options[:type]
          @name = options[:name]
          @context = options[:context]
        end

        # メタデータを取得
        # @return [Hash] メタデータ
        def metadata
          {
            file_path: @file_path,
            start_line: @start_line,
            end_line: @end_line,
            type: @type,
            name: @name
          }
        end

        # JSONに変換
        # @return [Hash] JSON形式のハッシュ
        def to_json(*_args)
          {
            id: @id,
            content: @content,
            metadata: metadata
          }.to_json
        end

        # ハッシュに変換
        # @return [Hash] ハッシュ
        def to_h
          {
            id: @id,
            content: @content,
            file_path: @file_path,
            start_line: @start_line,
            end_line: @end_line,
            type: @type,
            name: @name,
            context: @context
          }
        end
      end
    end
  end
end
