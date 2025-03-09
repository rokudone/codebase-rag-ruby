# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # コンテキストビルダー
      # 検索結果から情報密度の高いコンテキストを構築するサービス
      module ContextBuilder
        module_function

        # コンテキストを構築する
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        # @param max_context_length [Integer] コンテキストの最大長（トークン数の近似値）
        # @return [String] 構築されたコンテキスト
        def build_context(chunks, max_context_length)
          return "" if chunks.empty?

          context_parts = []
          current_length = 0

          # チャンクをグループ化（ファイルパスでグループ化）
          chunk_groups = chunks.group_by { |chunk| chunk.file_path }

          # ファイル概要セクションを追加
          file_overview = build_file_overview(chunk_groups)
          if (file_overview_length = estimate_token_count(file_overview)) <= max_context_length * 0.1
            context_parts << file_overview
            current_length += file_overview_length
          end

          # 各ファイルグループを処理
          chunk_groups.each do |file_path, file_chunks|
            # ファイル内のチャンクを種類と行番号でソート
            sorted_chunks = sort_chunks(file_chunks)

            # ファイルヘッダーを追加
            file_header = "## ファイル: #{file_path}\n"
            file_header_length = estimate_token_count(file_header)

            if current_length + file_header_length <= max_context_length
              context_parts << file_header
              current_length += file_header_length
            else
              break
            end

            # 各チャンクを処理
            sorted_chunks.each do |chunk|
              # チャンク情報を構築
              chunk_context = build_chunk_context(chunk)
              chunk_length = estimate_token_count(chunk_context)

              if current_length + chunk_length <= max_context_length
                context_parts << chunk_context
                current_length += chunk_length
              else
                # 残りのスペースが少ない場合は要約を追加
                if max_context_length - current_length > 100
                  summary = "#{chunk.type.capitalize} #{chunk.name}の内容は長すぎるため省略されました。"
                  context_parts << summary
                end
                break
              end
            end
          end

          context_parts.join("\n\n")
        end

        # ファイル概要を構築する
        # @param chunk_groups [Hash] ファイルパスごとにグループ化されたチャンク
        # @return [String] ファイル概要
        def build_file_overview(chunk_groups)
          overview = "# コードベース概要\n\n"

          chunk_groups.each do |file_path, chunks|
            # ファイル内の主要なクラス・モジュールを抽出
            main_entities = chunks.select { |c| ["class", "module"].include?(c.type) }
                                 .map(&:name)
                                 .uniq

            if main_entities.any?
              overview += "- #{file_path}: #{main_entities.join(', ')}\n"
            else
              # クラス・モジュールがない場合はメソッド名を表示
              method_names = chunks.select { |c| c.type == "method" }
                                  .map(&:name)
                                  .uniq
                                  .take(3)

              if method_names.any?
                overview += "- #{file_path}: メソッド #{method_names.join(', ')}\n"
              else
                overview += "- #{file_path}\n"
              end
            end
          end

          overview
        end

        # チャンクをソートする
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] ソートされたチャンクの配列
        def sort_chunks(chunks)
          # 種類の優先順位
          type_priority = {
            "file" => 0,
            "module" => 1,
            "class" => 2,
            "method" => 3,
            "semantic_group" => 4
          }

          # 種類と行番号でソート
          chunks.sort_by do |chunk|
            [
              type_priority.fetch(chunk.type, 999),
              chunk.start_line
            ]
          end
        end

        # チャンクコンテキストを構築する
        # @param chunk [CodebaseRag::Domain::Entities::CodeChunk] チャンク
        # @return [String] チャンクコンテキスト
        def build_chunk_context(chunk)
          context = "### #{chunk.type.capitalize}: #{chunk.name}\n"
          context += "行: #{chunk.start_line}-#{chunk.end_line}\n"

          # 分割情報がある場合は追加
          if chunk.part?
            context += "分割: #{chunk.part_number}/#{chunk.total_parts}\n"
          end

          # 親情報がある場合は追加
          if chunk.respond_to?(:parent_name) && chunk.parent_name
            context += "親: #{chunk.parent_type} #{chunk.parent_name}\n"
          end

          # コンテンツを追加（Markdownのコードブロックとして）
          context += "\n```ruby\n#{chunk.content}\n```"

          context
        end

        # テキストのトークン数を概算する（3文字で1トークン）
        # @param text [String] テキスト
        # @return [Integer] トークン数
        def estimate_token_count(text)
          return 0 if text.nil? || text.empty?
          (text.length / 3.0).ceil
        end
      end
    end
  end
end
