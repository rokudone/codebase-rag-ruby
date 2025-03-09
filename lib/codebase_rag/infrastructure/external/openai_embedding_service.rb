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
          # 小さなバッチに分割して処理（APIの制限を考慮）
          batch_size = 10
          results = []

          texts.each_slice(batch_size) do |batch|
            batch_texts = batch.map { |text| text[:content] }
            batch_ids = batch.map { |text| text[:id] }

            puts "エンベディングを生成中: #{batch_ids.first} など #{batch.size}件"

            # バッチリクエスト
            response = client.post("/v1/embeddings") do |req|
              req.headers["Content-Type"] = "application/json"
              req.body = {
                model: @model_name,
                input: batch_texts
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
              raise response.inspect
            end
          end

          results
        end

        private

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
