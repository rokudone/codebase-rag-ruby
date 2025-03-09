# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # クエリ拡張
      # 質問を分析し、関連するキーワードを追加して検索の幅を広げるサービス
      module QueryExpander
        module_function

        # 質問を拡張する
        # @param question [String] 元の質問
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        # @return [String] 拡張された質問
        def expand_query(question, llm_service)
          system_prompt = <<~PROMPT
            あなたは検索クエリを拡張するエキスパートです。
            与えられた質問を分析し、Rubyコードベース検索に役立つキーワードやフレーズを抽出してください。
            元の質問の意図を保ちながら、関連する技術用語、クラス名、メソッド名、概念などを追加してください。

            出力形式:
            1. 元の質問をそのまま出力
            2. 改行
            3. 関連キーワードをスペースで区切って列挙（5-10個程度）

            例:
            質問: 「ユーザー認証の仕組みはどうなっていますか？」
            出力:
            ユーザー認証の仕組みはどうなっていますか？
            authenticate login password session token bcrypt devise secure_password credentials oauth
          PROMPT

          context = ""
          result = llm_service.generate_answer(system_prompt, context, question)

          # 結果を解析
          lines = result.strip.split("\n")
          return question if lines.size < 2

          # 元の質問と拡張キーワードを結合
          expanded_keywords = lines[1..-1].join(" ").strip

          # 元の質問を保持しつつ、拡張キーワードを追加
          "#{question} #{expanded_keywords}"
        end
      end
    end
  end
end
