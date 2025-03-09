# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # 再ランキング
      # 検索結果をLLMで再評価し、より関連性の高い順に並べ替えるサービス
      module Reranker
        module_function

        # チャンクを再ランキングする
        # @param question [String] 質問
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] 再ランキングされたチャンクの配列
        def rerank_chunks(question, chunks, llm_service)
          return chunks if chunks.empty?

          # バッチ処理のためにチャンクをグループ化（5チャンクずつ）
          chunk_groups = chunks.each_slice(5).to_a
          reranked_chunks = []

          chunk_groups.each do |group|
            # 各チャンクの関連性をスコアリング
            chunk_texts = group.map.with_index do |chunk, i|
              # チャンク情報を簡潔に表示（長すぎる場合は切り詰める）
              content_preview = chunk.content.length > 500 ? "#{chunk.content[0..500]}..." : chunk.content
              "チャンク#{i + 1}:\nファイル: #{chunk.file_path}\n種類: #{chunk.type}\n名前: #{chunk.name}\n\n#{content_preview}"
            end

            system_prompt = <<~PROMPT
              あなたはコードチャンクの関連性を評価するエキスパートです。
              与えられた質問に対して、各コードチャンクの関連性を0から10のスケールで評価してください。
              10は非常に関連性が高く、0は全く関連性がないことを意味します。

              評価基準:
              - 質問に直接答えるコードや情報を含むチャンクは高いスコア
              - 質問のトピックに関連するが直接答えではないチャンクは中程度のスコア
              - 質問と関連性が低いチャンクは低いスコア

              各チャンクに対して、スコアとその理由を簡潔に説明してください。
              出力形式は以下の通りです：

              チャンク1: スコア（理由）
              チャンク2: スコア（理由）
              ...
            PROMPT

            context = chunk_texts.join("\n\n---\n\n")
            result = llm_service.generate_answer(system_prompt, context, question)

            # スコアを抽出
            scores = []
            result.scan(/チャンク(\d+):\s*(\d+)/) do |index, score|
              i = index.to_i - 1
              if i >= 0 && i < group.size
                scores << [group[i], score.to_i]
              end
            end

            # スコアが抽出できなかった場合のフォールバック
            if scores.empty?
              scores = group.map.with_index { |chunk, i| [chunk, 5] } # デフォルトスコア5
            end

            # スコア順にソート
            reranked_chunks.concat(scores.sort_by { |_, score| -score }.map(&:first))
          end

          reranked_chunks
        end
      end
    end
  end
end
