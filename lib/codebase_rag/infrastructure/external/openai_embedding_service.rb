# frozen_string_literal: true

require "faraday"
require "json"

module CodebaseRag
  module Infrastructure
    module External
      # OpenAIエンベディングサービス
      # OpenAI APIを使用してエンベディングを生成するサービス
      class OpenAIEmbeddingService
        include CodebaseRag::Domain::Services::EmbeddingServiceInterface

        # @return [String] APIキー
        attr_reader :api_key

        # @return [String] モデル名
        attr_reader :model_name

        # 初期化
        # @param api_key [String] APIキー
        # @param model_name [String] モデル名
        def initialize(api_key, model_name = "text-embedding-3-small")
          @api_key = api_key
          @model_name = model_name
        end

        # エンベディングを生成
        # @param text [String] テキスト
        # @return [CodebaseRag::Domain::Entities::EmbeddingResult] エンベディング結果
        def generate_embedding(text)
          response = client.post("/v1/embeddings") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = {
              model: @model_name,
              input: text
            }.to_json
          end

          if response.status == 200
            data = JSON.parse(response.body, symbolize_names: true)
            embedding = data[:data][0][:embedding]
            CodebaseRag::Domain::Entities::EmbeddingResult.new(
              Digest::MD5.hexdigest(text)[0, 12],
              embedding
            )
          else
            raise response.inspect
          end
        end

        # バッチエンベディングを生成
        # @param texts [Array<Hash>] テキストの配列（id, contentを含むハッシュ）
        # @return [Array<CodebaseRag::Domain::Entities::EmbeddingResult>] エンベディング結果の配列
        def generate_batch_embeddings(texts)
          # トークン制限の80%を目標とする
          max_tokens_per_batch = (8192 * 0.8).to_i
          results = []

          # 動的バッチ処理
          current_batch = []
          current_batch_ids = []
          current_batch_tokens = 0

          texts.each do |text|
            # テキストのトークン数を概算（3文字で1トークン）
            text_tokens = estimate_token_count(text[:content])

            # 現在のバッチにテキストを追加するとトークン制限を超える場合
            if current_batch_tokens + text_tokens > max_tokens_per_batch && !current_batch.empty?
              # 現在のバッチを処理
              process_batch(current_batch, current_batch_ids, results)

              # 新しいバッチを開始
              current_batch = []
              current_batch_ids = []
              current_batch_tokens = 0
            end

            # テキストをバッチに追加
            current_batch << text[:content]
            current_batch_ids << text[:id]
            current_batch_tokens += text_tokens
          end

          # 残りのバッチを処理
          unless current_batch.empty?
            process_batch(current_batch, current_batch_ids, results)
          end

          results
        end

        private

        # バッチを処理する
        # @param batch [Array<String>] テキストの配列
        # @param batch_ids [Array<String>] テキストIDの配列
        # @param results [Array<CodebaseRag::Domain::Entities::EmbeddingResult>] 結果を格納する配列
        # @return [void]
        def process_batch(batch, batch_ids, results)
          puts "エンベディングを生成中: #{batch_ids.first} など #{batch.size}件"

          # バッチリクエスト
          response = client.post("/v1/embeddings") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = {
              model: @model_name,
              input: batch
            }.to_json
          end

          if response.status == 200
            data = JSON.parse(response.body, symbolize_names: true)

            # 各テキストのエンベディングを取得
            data[:data].each_with_index do |item, index|
              embedding = item[:embedding]
              results << CodebaseRag::Domain::Entities::EmbeddingResult.new(
                batch_ids[index],
                embedding
              )
            end
          else
            pp batch
            raise response.body
          end
        end

        # テキストのトークン数を概算する（3文字で1トークン）
        # @param text [String] テキスト
        # @return [Integer] トークン数
        def estimate_token_count(text)
          return 0 if text.nil? || text.empty?
          (text.length / 3.0).ceil
        end

        # Faradayクライアントを取得
        # @return [Faraday::Connection] Faradayクライアント
        def client
          @client ||= Faraday.new(url: "https://api.openai.com") do |conn|
            conn.headers["Content-Type"] = "application/json"
            conn.headers["Authorization"] = "Bearer #{@api_key}"
            # HTTP/2 のサポートを無効化（問題が発生する場合があるため）
            conn.adapter :net_http
          end
        end
      end
    end
  end
end
