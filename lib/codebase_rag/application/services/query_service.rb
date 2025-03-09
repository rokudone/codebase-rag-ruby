# frozen_string_literal: true

require_relative "../../domain/services/query_expander"
require_relative "../../domain/services/reranker"
require_relative "../../domain/services/keyword_search"
require_relative "../../domain/services/context_builder"
require_relative "../../domain/services/evaluator"
require_relative "../../domain/services/feedback_collector"
require "fileutils"

module CodebaseRag
  module Application
    module Services
      # クエリエンジン
      # ベクトルデータベースから関連するコードチャンクを検索し、回答を生成する
      class QueryService
        # @return [CodebaseRag::Domain::Repositories::VectorStoreInterface] ベクトルストア
        attr_reader :vector_store

        # @return [CodebaseRag::Domain::Services::EmbeddingServiceInterface] エンベディングサービス
        attr_reader :embedding_service

        # @return [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        attr_reader :llm_service

        # @return [Integer] コンテキストの最大長（トークン数の近似値）
        attr_reader :max_context_length

        # @return [Boolean] 評価モードかどうか
        attr_reader :evaluation_mode

        # @return [String, nil] 評価ログファイルパス
        attr_reader :evaluation_log_file

        # @return [Boolean] フィードバックモードかどうか
        attr_reader :feedback_mode

        # @return [String, nil] フィードバックログファイルパス
        attr_reader :feedback_log_file

        # 初期化
        # @param vector_store [CodebaseRag::Domain::Repositories::VectorStoreInterface] ベクトルストア
        # @param embedding_service [CodebaseRag::Domain::Services::EmbeddingServiceInterface] エンベディングサービス
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        # @param options [Hash] オプション
        # @option options [Boolean] :evaluation_mode 評価モードかどうか
        # @option options [String] :evaluation_log_file 評価ログファイルパス
        def initialize(vector_store, embedding_service, llm_service, options = {})
          @vector_store = vector_store
          @embedding_service = embedding_service
          @llm_service = llm_service
          @max_context_length = 8000 # コンテキストの最大長（トークン数の近似値）
          @evaluation_mode = options[:evaluation_mode] || false
          @evaluation_log_file = options[:evaluation_log_file] || "rag_evaluation.jsonl"
          @feedback_mode = options[:feedback_mode] || false
          @feedback_log_file = options[:feedback_log_file] || "rag_feedback.jsonl"
        end

        # 質問に対する回答を生成する
        # @param question [String] 質問
        # @return [String] 回答
        def query(question)
          begin
            # 質問を拡張
            expanded_question = CodebaseRag::Domain::Services::QueryExpander.expand_query(question, @llm_service)

            # 拡張された質問のエンベディングを生成
            question_embedding = @embedding_service.generate_embedding(expanded_question).embedding

            # ベクトル検索
            vector_chunks = @vector_store.search_similar_chunks(question_embedding, 20)

            # キーワード検索
            keywords = CodebaseRag::Domain::Services::KeywordSearch.extract_keywords(question, @llm_service)
            keyword_chunks = CodebaseRag::Domain::Services::KeywordSearch.search_by_keywords(
              keywords,
              @vector_store.chunks.values
            ).take(15) # 上位15件を取得

            if vector_chunks.empty? && keyword_chunks.empty?
              return "関連するコードが見つかりませんでした。質問を具体的にするか、別の質問を試してください。"
            end

            # 結果の統合（重複を除去）
            combined_chunks = []
            seen_ids = Set.new

            # ベクトル検索結果を優先
            vector_chunks.each do |chunk|
              combined_chunks << chunk
              seen_ids.add(chunk.id)
            end

            # キーワード検索結果を追加（重複を除去）
            keyword_chunks.each do |chunk|
              unless seen_ids.include?(chunk.id)
                combined_chunks << chunk
                seen_ids.add(chunk.id)
                break if combined_chunks.size >= 30
              end
            end

            # 検索結果を再ランキング
            relevant_chunks = CodebaseRag::Domain::Services::Reranker.rerank_chunks(
              question,
              combined_chunks,
              @llm_service
            )

            # 上位20件を使用
            top_chunks = relevant_chunks.take(20)

            # 改善されたコンテキスト構築
            context = CodebaseRag::Domain::Services::ContextBuilder.build_context(
              top_chunks,
              @max_context_length
            )

            # システムプロンプトを構築
            system_prompt = <<~PROMPT
              あなたはRubyコードベースに関する質問に答えるエキスパートアシスタントです。

              以下のコードコンテキストを参考に、質問に具体的かつ正確に回答してください。
              コードの詳細を説明する際は、関連するファイル名や行番号を引用し、具体的な実装の詳細を含めてください。

              回答の構成:
              1. 最初に質問に直接答える簡潔な要約を提供してください
              2. 次に関連するコードの詳細な説明を提供してください
              3. 必要に応じて、コードの使用例や実行フローを説明してください
              4. 回答の最後に、関連する他のコンポーネントや注意点があれば言及してください

              わからない場合は、正直に「わかりません」と答えてください。推測や不確かな情報は提供しないでください。
              コードの意図や設計理由について説明する際は、コードの構造や命名規則から推測できる情報を活用してください。
            PROMPT

            # LLMサービスを使用して回答を生成
            answer = @llm_service.generate_answer(system_prompt, context, question)

            # 評価モードが有効な場合は回答を評価
            if @evaluation_mode
              evaluation = CodebaseRag::Domain::Services::Evaluator.evaluate_answer(
                question,
                answer,
                context,
                @llm_service
              )

              # 評価結果をログに記録
              CodebaseRag::Domain::Services::Evaluator.log_evaluation(
                question,
                answer,
                context,
                evaluation,
                @evaluation_log_file
              )

              # 評価情報を回答に追加（デバッグ用）
              if ENV["RAG_DEBUG"] == "true"
                evaluation_text = "評価結果:\n"
                evaluation.each do |metric, data|
                  if metric == "改善提案"
                    evaluation_text += "#{metric}: #{data}\n"
                  elsif data.is_a?(Hash) && data[:score]
                    evaluation_text += "#{metric}: #{data[:score]} - #{data[:explanation]}\n"
                  end
                end

                answer += "\n\n---\n\n[デバッグ情報]\n#{evaluation_text}"
              end
            end

            # フィードバックモードが有効な場合はフィードバックIDを生成
            if @feedback_mode
              feedback_id = CodebaseRag::Domain::Services::FeedbackCollector.generate_feedback_id(question, answer)

              # フィードバック案内を追加
              feedback_guide = <<~GUIDE

              ---
              この回答は役に立ちましたか？ フィードバックを提供するには:
              `rb-rag feedback #{feedback_id} [1-5] --comment "コメント"`
              GUIDE

              answer += feedback_guide
            end

            answer
          rescue => e
            "エラーが発生しました: #{e.message}"
          end
        end
      end
    end
  end
end
