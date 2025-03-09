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

        # @return [Integer, nil] 分割された場合のパート番号
        attr_reader :part_number

        # @return [Integer, nil] 分割された場合の総パート数
        attr_reader :total_parts

        # @return [String, nil] 分割元のチャンクID
        attr_reader :original_chunk_id

        # @return [Integer] トークン数
        attr_reader :token_count

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
        # @option options [Integer] :part_number 分割された場合のパート番号
        # @option options [Integer] :total_parts 分割された場合の総パート数
        # @option options [String] :original_chunk_id 分割元のチャンクID
        def initialize(options)
          @id = options[:id]
          @content = options[:content]
          @file_path = options[:file_path]
          @start_line = options[:start_line]
          @end_line = options[:end_line]
          @type = options[:type]
          @name = options[:name]
          @context = options[:context]
          @part_number = options[:part_number]
          @total_parts = options[:total_parts]
          @original_chunk_id = options[:original_chunk_id]
          @token_count = calculate_token_count(@content)
        end

        # チャンクが分割されたものかどうか
        # @return [Boolean] 分割されたチャンクかどうか
        def part?
          !@part_number.nil? && !@total_parts.nil?
        end

        # メタデータを取得
        # @return [Hash] メタデータ
        def metadata
          {
            file_path: @file_path,
            start_line: @start_line,
            end_line: @end_line,
            type: @type,
            name: @name,
            part_number: @part_number,
            total_parts: @total_parts,
            original_chunk_id: @original_chunk_id,
            token_count: @token_count
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
            context: @context,
            part_number: @part_number,
            total_parts: @total_parts,
            original_chunk_id: @original_chunk_id,
            token_count: @token_count
          }
        end

        private

        # トークン数を計算（3文字で1トークン）
        # @param text [String] テキスト
        # @return [Integer] トークン数
        def calculate_token_count(text)
          return 0 if text.nil? || text.empty?
          (text.length / 3.0).ceil
        end
      end
    end
  end
end
