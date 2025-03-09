# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # LLMサービスインターフェース
      # 大規模言語モデルを使用して回答を生成するサービスのインターフェース
      module LLMServiceInterface
        # 回答を生成
        # @param system_prompt [String] システムプロンプト
        # @param context [String] コンテキスト
        # @param question [String] 質問
        # @return [String] 回答
        def generate_answer(system_prompt, context, question)
          raise NotImplementedError, "#{self.class}#generate_answer is not implemented"
        end
      end
    end
  end
end
