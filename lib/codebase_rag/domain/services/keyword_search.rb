# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # キーワード検索
      # テキストベースのキーワード検索を行うサービス
      module KeywordSearch
        module_function

        # 質問からキーワードを抽出する
        # @param question [String] 質問
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        # @return [Array<String>] キーワードの配列
        def extract_keywords(question, llm_service)
          system_prompt = <<~PROMPT
            あなたは検索キーワードを抽出するエキスパートです。
            与えられた質問から、Rubyコードベース検索に役立つキーワードを抽出してください。
            クラス名、メソッド名、変数名、技術用語などを特に重視してください。

            出力はキーワードのリストのみとし、各キーワードは改行で区切ってください。
            キーワードは単語単位で、5〜10個程度抽出してください。
          PROMPT

          result = llm_service.generate_answer(system_prompt, "", question)

          # 結果を解析
          keywords = result.strip.split("\n").map(&:strip).reject(&:empty?)

          # キーワードが少なすぎる場合は、単純に質問を単語に分割
          if keywords.size < 3
            # 簡易的な単語分割（英数字の連続をキーワードとして抽出）
            additional_keywords = question.scan(/[a-zA-Z0-9_]+/).select { |w| w.length > 2 }
            keywords.concat(additional_keywords)
            keywords.uniq!
          end

          keywords
        end

        # キーワード検索を行う
        # @param keywords [Array<String>] キーワードの配列
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] 検索対象のチャンク配列
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] 検索結果のチャンク配列
        def search_by_keywords(keywords, chunks)
          return [] if keywords.empty?

          # 各キーワードに対する正規表現を作成
          regexps = keywords.map { |keyword| Regexp.new(Regexp.escape(keyword), Regexp::IGNORECASE) }

          # 各チャンクに対してキーワードマッチングを実行
          chunks_with_scores = chunks.map do |chunk|
            # 各キーワードのマッチ回数をカウント
            score = regexps.sum { |regexp| chunk.content.scan(regexp).count }

            # ファイルパスや名前にもマッチするとボーナススコア
            metadata_text = "#{chunk.file_path} #{chunk.name} #{chunk.type}"
            metadata_score = regexps.sum { |regexp| metadata_text.scan(regexp).count } * 2

            [chunk, score + metadata_score]
          end

          # スコア順にソート（スコアが0のチャンクは除外）
          chunks_with_scores.select { |_, score| score > 0 }
                           .sort_by { |_, score| -score }
                           .map(&:first)
        end
      end
    end
  end
end
