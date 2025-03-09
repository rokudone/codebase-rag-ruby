# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # 評価器
      # RAGシステムの性能を評価するサービス
      module Evaluator
        module_function

        # 回答を評価する
        # @param question [String] 質問
        # @param answer [String] 回答
        # @param context [String] コンテキスト
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        # @return [Hash] 評価結果
        def evaluate_answer(question, answer, context, llm_service)
          system_prompt = <<~PROMPT
            あなたはRAGシステムの回答を評価するエキスパートです。
            与えられた質問、回答、およびコンテキストを分析し、以下の指標で評価してください：

            1. 関連性（0-10）: 回答が質問に関連しているか
            2. 正確性（0-10）: 回答がコンテキストに基づいて正確か
            3. 完全性（0-10）: 回答が質問のすべての側面に対応しているか
            4. 簡潔性（0-10）: 回答が簡潔で理解しやすいか
            5. コード参照（0-10）: 回答が適切にコードを参照しているか

            各指標について、スコアと簡単な説明を提供してください。
            最後に、総合スコア（0-10）と改善のための提案を提供してください。

            出力形式:
            関連性: [スコア] - [説明]
            正確性: [スコア] - [説明]
            完全性: [スコア] - [説明]
            簡潔性: [スコア] - [説明]
            コード参照: [スコア] - [説明]

            総合スコア: [スコア]

            改善提案:
            [提案内容]
          PROMPT

          evaluation_context = <<~CONTEXT
            質問:
            #{question}

            コンテキスト（一部）:
            #{context[0..1000]}...

            回答:
            #{answer}
          CONTEXT

          result = llm_service.generate_answer(system_prompt, evaluation_context, "この回答を評価してください。")

          # 評価結果をパース
          scores = {}

          result.scan(/([^:]+):\s*(\d+)\s*-\s*(.+)/) do |metric, score, explanation|
            scores[metric.strip] = {
              score: score.to_i,
              explanation: explanation.strip
            }
          end

          # 総合スコアを抽出
          if result =~ /総合スコア:\s*(\d+)/
            scores["総合スコア"] = { score: $1.to_i, explanation: "" }
          end

          # 改善提案を抽出
          if result =~ /改善提案:\s*(.+)/m
            scores["改善提案"] = $1.strip
          end

          scores
        end

        # 評価結果をログに記録する
        # @param question [String] 質問
        # @param answer [String] 回答
        # @param context [String] コンテキスト
        # @param evaluation [Hash] 評価結果
        # @param log_file [String] ログファイルパス
        # @return [void]
        def log_evaluation(question, answer, context, evaluation, log_file)
          log_entry = {
            timestamp: Time.now.iso8601,
            question: question,
            answer: answer,
            context_length: context.length,
            evaluation: evaluation
          }

          # ディレクトリが存在しない場合は作成
          log_dir = File.dirname(log_file)
          FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)

          # ログファイルに追記
          File.open(log_file, "a") do |f|
            f.puts(JSON.generate(log_entry))
          end
        end

        # 評価結果を集計する
        # @param log_file [String] ログファイルパス
        # @return [Hash] 集計結果
        def aggregate_evaluations(log_file)
          return {} unless File.exist?(log_file)

          entries = []
          File.foreach(log_file) do |line|
            entries << JSON.parse(line, symbolize_names: true)
          end

          return {} if entries.empty?

          # 各指標の平均スコアを計算
          metrics = ["関連性", "正確性", "完全性", "簡潔性", "コード参照", "総合スコア"]
          aggregated = {}

          metrics.each do |metric|
            scores = entries.map { |e| e[:evaluation][metric]&.dig(:score) }.compact
            next if scores.empty?

            aggregated[metric] = {
              average: scores.sum.to_f / scores.size,
              count: scores.size,
              min: scores.min,
              max: scores.max
            }
          end

          # 質問と回答の例を追加
          if entries.any?
            best_entry = entries.max_by { |e| e[:evaluation]["総合スコア"]&.dig(:score) || 0 }
            worst_entry = entries.min_by { |e| e[:evaluation]["総合スコア"]&.dig(:score) || 10 }

            aggregated[:examples] = {
              best: {
                question: best_entry[:question],
                answer: best_entry[:answer],
                score: best_entry[:evaluation]["総合スコア"]&.dig(:score)
              },
              worst: {
                question: worst_entry[:question],
                answer: worst_entry[:answer],
                score: worst_entry[:evaluation]["総合スコア"]&.dig(:score)
              }
            }
          end

          aggregated
        end
      end
    end
  end
end
