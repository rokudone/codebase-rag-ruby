# frozen_string_literal: true

require "modelcontextprotocol"

module CodebaseRag
  module Infrastructure
    module Server
      # コードベースRAG用MCPサーバー
      # Clineからの質問を受け取り、RAGシステムを使用して回答を生成する
      class CodebaseRagServer
        # @return [Server] MCPサーバー
        attr_reader :server

        # @return [CodebaseRag::Application::Services::QueryService] クエリエンジン
        attr_reader :query_engine

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
          @server = ModelContextProtocol::Server.new(
            {
              name: "codebase-rag-server",
              version: "0.1.0"
            },
            {
              capabilities: {
                tools: {}
              }
            }
          )

          @data_dir = options[:data_dir]
          @api_key = options[:api_key]
          @base_url = options[:base_url] || "https://openrouter.ai/api/v1"
          @query_engine = nil

          setup_tool_handlers

          # エラーハンドリング
          @server.onerror = lambda { |error| puts "[MCP Error] #{error}" }
          trap("INT") do
            @server.close
            exit 0
          end
        end

        # クエリエンジンを初期化する
        # 必要に応じてベクトルストア、エンベディングサービス、LLMサービスを初期化する
        # @return [void]
        def initialize_query_engine
          return if @query_engine

          vector_store_path = File.join(@data_dir, "vector-store.json")
          unless File.exist?(vector_store_path)
            raise "RAGデータが見つかりません: #{vector_store_path}"
          end

          # ベクトルストアの初期化
          vector_store = CodebaseRag::Infrastructure::Repositories::VectorStore.new("code-chunks", @api_key)
          vector_store.initialize
          vector_store.load_from_file(vector_store_path)

          # エンベディングサービスの初期化
          embedding_service = CodebaseRag::Infrastructure::External::OpenAIEmbeddingService.new(
            @api_key,
            @base_url
          )

          # LLMサービスの初期化
          llm_service = CodebaseRag::Infrastructure::External::OpenAILLMService.new(
            @api_key,
            @base_url,
            "openai/gpt-4o"
          )

          # クエリエンジンの初期化
          @query_engine = CodebaseRag::Application::Services::QueryService.new(
            vector_store,
            embedding_service,
            llm_service
          )
        end

        # ツールハンドラーを設定する
        # @return [void]
        def setup_tool_handlers
          # ツール一覧を返すハンドラー
          @server.set_request_handler(ModelContextProtocol::ListToolsRequestSchema) do
            {
              tools: [
                {
                  name: "query_codebase",
                  description: "コードベースに関する質問に回答します",
                  input_schema: {
                    type: "object",
                    properties: {
                      question: {
                        type: "string",
                        description: "コードベースに関する質問"
                      }
                    },
                    required: ["question"]
                  }
                }
              ]
            }
          end

          # ツール呼び出しハンドラー
          @server.set_request_handler(ModelContextProtocol::CallToolRequestSchema) do |request|
            if request.params["name"] != "query_codebase"
              raise ModelContextProtocol::McpError.new(
                ModelContextProtocol::ErrorCode::MethodNotFound,
                "Unknown tool: #{request.params['name']}"
              )
            end

            args = request.params["arguments"]
            unless args["question"]
              raise ModelContextProtocol::McpError.new(
                ModelContextProtocol::ErrorCode::InvalidParams,
                "Question is required"
              )
            end

            begin
              puts "[MCP] 質問を受信: #{args['question']}"

              # クエリエンジンを初期化
              initialize_query_engine

              # 質問に回答
              answer = @query_engine.query(args["question"])
              puts "[MCP] 回答を生成しました"

              {
                content: [
                  {
                    type: "text",
                    text: answer
                  }
                ]
              }
            rescue => e
              puts "[MCP] コードベース検索中にエラーが発生しました: #{e.message}"
              {
                content: [
                  {
                    type: "text",
                    text: "エラーが発生しました: #{e.message}"
                  }
                ],
                is_error: true
              }
            end
          end
        end

        # サーバーを実行する
        # @return [void]
        def run
          begin
            transport = ModelContextProtocol::StdioServerTransport.new
            @server.connect(transport)
            puts "Codebase RAG MCP server running on stdio"
          rescue => e
            puts "[MCP] サーバー起動中にエラーが発生しました: #{e.message}"
            exit 1
          end
        end
      end
    end
  end
end
