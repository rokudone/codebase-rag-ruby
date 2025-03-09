# frozen_string_literal: true

require "fileutils"
require "json"
require "digest/md5"

module CodebaseRag
  module Domain
    module Services
      # フィードバックコレクター
      # ユーザーからのフィードバックを収集するサービス
      module FeedbackCollector
        module_function

        # フィードバックを記録する
        # @param question [String] 質問
        # @param answer [String] 回答
        # @param rating [Integer] 評価（1-5）
        # @param comment [String, nil] コメント
        # @param log_file [String] ログファイルパス
        # @return [String] フィードバックID
        def record_feedback(question, answer, rating, comment, log_file)
          # フィードバックIDを生成
          feedback_id = generate_feedback_id(question, answer)

          # フィードバックエントリを作成
          feedback_entry = {
            id: feedback_id,
            timestamp: Time.now.iso8601,
            question: question,
            answer: answer,
            rating: rating,
            comment: comment
          }

          # ディレクトリが存在しない場合は作成
          log_dir = File.dirname(log_file)
          FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)

          # ログファイルに追記
          File.open(log_file, "a") do |f|
            f.puts(JSON.generate(feedback_entry))
          end

          feedback_id
        end

        # フィードバックIDを生成する
        # @param question [String] 質問
        # @param answer [String] 回答
        # @return [String] フィードバックID
        def generate_feedback_id(question, answer)
          Digest::MD5.hexdigest("#{question}:#{answer}")[0, 8]
        end

        # フィードバックを取得する
        # @param feedback_id [String] フィードバックID
        # @param log_file [String] ログファイルパス
        # @return [Hash, nil] フィードバック
        def get_feedback(feedback_id, log_file)
          return nil unless File.exist?(log_file)

          File.foreach(log_file) do |line|
            feedback = JSON.parse(line, symbolize_names: true)
            return feedback if feedback[:id] == feedback_id
          end

          nil
        end

        # フィードバックを集計する
        # @param log_file [String] ログファイルパス
        # @return [Hash] 集計結果
        def aggregate_feedback(log_file)
          return {} unless File.exist?(log_file)

          entries = []
          File.foreach(log_file) do |line|
            entries << JSON.parse(line, symbolize_names: true)
          end

          return {} if entries.empty?

          # 評価の分布を計算
          ratings = entries.map { |e| e[:rating] }
          rating_counts = Hash.new(0)
          ratings.each { |r| rating_counts[r] += 1 }

          # 平均評価を計算
          average_rating = ratings.sum.to_f / ratings.size

          # 最高評価と最低評価の例を取得
          best_entries = entries.select { |e| e[:rating] == 5 }
          worst_entries = entries.select { |e| e[:rating] == 1 }

          {
            count: entries.size,
            average_rating: average_rating,
            rating_distribution: rating_counts,
            best_examples: best_entries.take(3),
            worst_examples: worst_entries.take(3)
          }
        end
      end
    end
  end
end
