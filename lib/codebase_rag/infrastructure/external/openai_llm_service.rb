# frozen_string_literal: true

require "faraday"
require "json"

module CodebaseRag
  module Infrastructure
    module External
      # OpenAI LLMサービス
      # OpenAI APIを使用して回答を生成するサービス
      class OpenAILLMService
        include CodebaseRag::Domain::Services::LLMServiceInterface

        # @return [String] APIキー
        attr_reader :api_key

        # @return [String] モデル名
        attr_reader :model_name

        # 初期化
        # @param api_key [String] APIキー
        # @param model_name [String] モデル名
        def initialize(api_key, model_name = "gpt-4o-mini")
          @api_key = api_key
          @model_name = model_name
        end

        # 回答を生成
        # @param system_prompt [String] システムプロンプト
        # @param context [String] コンテキスト
        # @param question [String] 質問
        # @return [String] 回答
        def generate_answer(system_prompt, context, question)
          response = client.post("/v1/chat/completions") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = {
              model: @model_name,
              messages: [
                {
                  role: "system",
                  content: system_prompt
                },
                {
                  role: "user",
                  content: "コンテキスト:\n\n#{context}\n\n質問: #{question}"
                }
              ],
              temperature: 0.2,
              max_tokens: 2000
            }.to_json
          end

          if response.status == 200
            data = JSON.parse(response.body, symbolize_names: true)
            data[:choices][0][:message][:content]
          else
            raise response.inspect
          end
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
