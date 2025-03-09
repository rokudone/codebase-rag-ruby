# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # 階層可視化
      # コードチャンクの階層構造を視覚化するサービス
      module HierarchyVisualizer
        module_function

        # チャンクの階層構造を視覚化する
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        # @return [String] 階層構造の文字列表現
        def visualize_hierarchy(chunks)
          # ファイルごとにチャンクをグループ化
          file_groups = chunks.group_by { |chunk| chunk.file_path }

          result = []

          file_groups.each do |file_path, file_chunks|
            result << "# #{file_path}"

            # ルートレベルのチャンク（親を持たないチャンク）を抽出
            root_chunks = file_chunks.select { |chunk| !chunk.has_parent? }

            # ファイル全体のチャンクは除外
            root_chunks = root_chunks.reject { |chunk| chunk.type == "file" }

            # ルートレベルのチャンクを処理
            root_chunks.each do |chunk|
              result << build_hierarchy_tree(chunk, file_chunks, 0)
            end

            result << ""
          end

          result.join("\n")
        end

        # 階層ツリーを構築する
        # @param chunk [CodebaseRag::Domain::Entities::CodeChunk] チャンク
        # @param all_chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] 全チャンクの配列
        # @param level [Integer] 階層レベル
        # @return [String] 階層ツリーの文字列表現
        def build_hierarchy_tree(chunk, all_chunks, level)
          indent = "  " * level

          # チャンク情報
          result = ["#{indent}- #{chunk.type}: #{chunk.name} (#{chunk.start_line}-#{chunk.end_line})"]

          # 依存関係
          if chunk.has_dependencies?
            result << "#{indent}  依存: #{chunk.dependencies.join(', ')}"
          end

          # 子チャンクを検索
          children = all_chunks.select { |c| c.parent_id == chunk.id }

          # 子チャンクを処理
          children.each do |child|
            result << build_hierarchy_tree(child, all_chunks, level + 1)
          end

          result.join("\n")
        end

        # チャンクの階層情報をJSONとして出力する
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        # @param output_path [String] 出力先ファイルパス
        # @return [void]
        def export_hierarchy_json(chunks, output_path)
          # ファイルごとにチャンクをグループ化
          file_groups = chunks.group_by { |chunk| chunk.file_path }

          hierarchy = {}

          file_groups.each do |file_path, file_chunks|
            hierarchy[file_path] = {
              chunks: file_chunks.map do |chunk|
                {
                  id: chunk.id,
                  type: chunk.type,
                  name: chunk.name,
                  start_line: chunk.start_line,
                  end_line: chunk.end_line,
                  parent_id: chunk.parent_id,
                  parent_type: chunk.parent_type,
                  parent_name: chunk.parent_name,
                  dependencies: chunk.dependencies
                }
              end
            }
          end

          File.write(output_path, JSON.pretty_generate(hierarchy))
        end
      end
    end
  end
end
