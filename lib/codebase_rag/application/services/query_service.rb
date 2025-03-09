# frozen_string_literal: true

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

        # 初期化
        # @param vector_store [CodebaseRag::Domain::Repositories::VectorStoreInterface] ベクトルストア
        # @param embedding_service [CodebaseRag::Domain::Services::EmbeddingServiceInterface] エンベディングサービス
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        def initialize(vector_store, embedding_service, llm_service)
          @vector_store = vector_store
          @embedding_service = embedding_service
          @llm_service = llm_service
          @max_context_length = 8000 # コンテキストの最大長（トークン数の近似値）
        end

        # 質問に対する回答を生成する
        # @param question [String] 質問
        # @return [String] 回答
        def query(question)
          begin
            # 質問のエンベディングを生成
            question_embedding = @embedding_service.generate_embedding(question).embedding

            # 類似チャンクを検索
            relevant_chunks = @vector_store.search_similar_chunks(question_embedding, 10)

            if relevant_chunks.empty?
              return "関連するコードが見つかりませんでした。質問を具体的にするか、別の質問を試してください。"
            end

            # コンテキストを構築（最大コンテキスト長を考慮）
            context_parts = []
            current_length = 0

            # 分割されたチャンクを元のチャンクIDでグループ化
            chunk_groups = {}
            relevant_chunks.each do |chunk|
              next if chunk.nil?

              # 分割されたチャンクの場合
              if chunk.part?
                group_key = chunk.original_chunk_id || chunk.id
                chunk_groups[group_key] ||= []
                chunk_groups[group_key] << chunk
              else
                # 分割されていないチャンクの場合
                chunk_groups[chunk.id] = [chunk]
              end
            end

            # グループごとに処理
            chunk_groups.each do |_, chunks|
              # パート番号でソート
              chunks.sort_by! { |c| c.part_number || 0 }

              chunks.each do |chunk|
                # チャンク情報を構築
                chunk_context = "ファイル: #{chunk.file_path}\n行: #{chunk.start_line}-#{chunk.end_line}\n種類: #{chunk.type}\n名前: #{chunk.name}"

                # 分割情報がある場合は追加
                if chunk.part?
                  chunk_context += "\n分割: #{chunk.part_number}/#{chunk.total_parts}"
                end

                chunk_context += "\n\n#{chunk.content}"
                chunk_length = chunk_context.length / 3 # 3文字で1トークンとして計算

                if current_length + chunk_length <= @max_context_length
                  context_parts << chunk_context
                  current_length += chunk_length
                else
                  break
                end
              end
            end

            context = context_parts.join("\n\n---\n\n")

            # システムプロンプトを構築
            system_prompt = <<~PROMPT
              あなたはRubyコードベースに関する質問に答えるエキスパートアシスタントです。
              以下のコードコンテキストを参考に、質問に具体的かつ正確に回答してください。
              コードの詳細を説明する際は、関連するファイル名や行番号を引用し、具体的な実装の詳細を含めてください。
              わからない場合は、正直に「わかりません」と答えてください。推測や不確かな情報は提供しないでください。
            PROMPT

            # LLMサービスを使用して回答を生成
            answer = @llm_service.generate_answer(system_prompt, context, question)

            answer
          rescue => e
            "エラーが発生しました: #{e.message}"
          end
        end
      end
    end
  end
end
