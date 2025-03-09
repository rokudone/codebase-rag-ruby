# frozen_string_literal: true

module CodebaseRag
  module Domain
    module Services
      # セマンティックチャンカー
      # 関連するコードをグループ化して意味のあるチャンクを生成するサービス
      module SemanticChunker
        module_function

        # セマンティックチャンクを作成する
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] 元のチャンク配列
        # @param llm_service [CodebaseRag::Domain::Services::LLMServiceInterface] LLMサービス
        # @param verbose [Boolean] 詳細な進捗を表示するかどうか
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] セマンティックチャンクの配列
        def create_semantic_chunks(chunks, llm_service, verbose = true)
          # 関連するチャンクをグループ化
          file_groups = chunks.group_by { |chunk| chunk.file_path }
          semantic_chunks = []

          total_files = file_groups.size
          puts "セマンティックチャンクを生成しています（#{total_files}ファイル）..." if verbose

          file_groups.each_with_index do |(file_path, file_chunks), index|
            if verbose
              progress = ((index + 1).to_f / total_files * 100).round(1)
              puts "  処理中: #{File.basename(file_path)} (#{index + 1}/#{total_files}, #{progress}%)"
            end
            # メソッドチャンクを抽出
            method_chunks = file_chunks.select { |chunk| chunk.type == "method" }

            # メソッドが少ない場合はスキップ
            if method_chunks.size < 3
              puts "    スキップ: メソッド数が少なすぎます（#{method_chunks.size}個）" if verbose
              next
            end

            # メソッド数を表示
            puts "    メソッド数: #{method_chunks.size}個" if verbose

            # メソッドの内容を結合
            methods_content = method_chunks.map do |chunk|
              "#{chunk.name}: #{chunk.content[0..200]}..."
            end.join("\n\n")

            # LLMを使用してメソッドをグループ化
            system_prompt = <<~PROMPT
              あなたはRubyコードを分析するエキスパートです。
              与えられたメソッドのリストを機能的に関連するグループに分類してください。
              各グループには、関連するメソッドと、そのグループが表す機能の簡潔な説明を含めてください。

              出力形式は以下の通りです：

              グループ1: [機能の説明]
              - メソッド名1
              - メソッド名2

              グループ2: [機能の説明]
              - メソッド名3
              - メソッド名4
            PROMPT

            puts "    LLMを使用してメソッドをグループ化しています..." if verbose
            result = llm_service.generate_answer(system_prompt, methods_content, "これらのメソッドを機能的に関連するグループに分類してください。")

            # グループを抽出
            current_group = nil
            current_methods = []
            groups = []

            puts "    グループを抽出しています..." if verbose

            result.each_line do |line|
              line = line.strip

              if line.start_with?("グループ") && line.include?(":")
                # 前のグループを保存
                if current_group && !current_methods.empty?
                  groups << [current_group, current_methods.dup]
                end

                # 新しいグループを開始
                current_group = line.split(":", 2)[1].strip
                current_methods = []
              elsif line.start_with?("-") && current_group
                method_name = line[1..-1].strip
                current_methods << method_name
              end
            end

            # 最後のグループを保存
            if current_group && !current_methods.empty?
              groups << [current_group, current_methods.dup]
            end

            # 抽出されたグループ数を表示
            if verbose
              puts "    #{groups.size}個のグループを抽出しました:"
              groups.each_with_index do |(group_name, methods), i|
                puts "      グループ#{i+1}: #{group_name} (#{methods.size}個のメソッド)"
              end
            end

            # グループごとにチャンクを作成
            groups.each_with_index do |(group_name, methods), index|
              if verbose
                puts "    グループ#{index+1}のチャンクを作成しています: #{group_name} (#{methods.size}個のメソッド)"
              end
              create_method_group_chunk(group_name, methods, file_path, file_chunks, semantic_chunks, verbose)
            end
          end

          # 生成されたセマンティックチャンクの数を表示
          if verbose && !semantic_chunks.empty?
            puts "セマンティックチャンク生成完了: #{semantic_chunks.size}個のチャンクを生成しました"
          end

          semantic_chunks
        end

        # メソッドグループからチャンクを作成する
        # @param group_name [String] グループ名
        # @param method_names [Array<String>] メソッド名の配列
        # @param file_path [String] ファイルパス
        # @param all_chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] 全チャンクの配列
        # @param semantic_chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] セマンティックチャンクの配列
        # @param verbose [Boolean] 詳細な進捗を表示するかどうか
        # @return [void]
        def create_method_group_chunk(group_name, method_names, file_path, all_chunks, semantic_chunks, verbose = true)
          # 指定されたメソッド名に一致するチャンクを検索
          method_chunks = all_chunks.select do |chunk|
            chunk.type == "method" && method_names.include?(chunk.name)
          end

          if method_chunks.empty?
            puts "      警告: 一致するメソッドが見つかりませんでした" if verbose
            return
          end

          # 見つかったメソッド数を表示
          if verbose
            found_methods = method_chunks.map(&:name)
            not_found = method_names - found_methods

            puts "      #{method_chunks.size}/#{method_names.size}個のメソッドが見つかりました"
            puts "      見つからなかったメソッド: #{not_found.join(', ')}" unless not_found.empty?
          end

          # メソッドの内容を結合
          content = method_chunks.map do |chunk|
            "# #{chunk.name} (行: #{chunk.start_line}-#{chunk.end_line})\n#{chunk.content}"
          end.join("\n\n")

          # 開始行と終了行を計算
          start_line = method_chunks.map(&:start_line).min
          end_line = method_chunks.map(&:end_line).max

          # 親クラス/モジュールを特定
          parent_info = find_parent_info(method_chunks)

          # 依存関係を結合
          dependencies = method_chunks.flat_map(&:dependencies).uniq

          # セマンティックチャンクを作成
          chunk_id = Digest::MD5.hexdigest("#{file_path}:semantic:#{group_name}")[0, 12]

          semantic_chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
            id: chunk_id,
            content: content,
            file_path: file_path,
            start_line: start_line,
            end_line: end_line,
            type: "semantic_group",
            name: "機能グループ: #{group_name}",
            context: "関連するメソッドのグループ: #{method_names.join(', ')}",
            parent_id: parent_info ? parent_info[0] : nil,
            parent_type: parent_info ? parent_info[1] : nil,
            parent_name: parent_info ? parent_info[2] : nil,
            dependencies: dependencies
          )
        end

        # 親情報を見つける
        # @param method_chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] メソッドチャンクの配列
        # @return [Array, nil] 親情報 [id, type, name]
        def find_parent_info(method_chunks)
          # 最も多く出現する親を選択
          parent_counts = Hash.new(0)

          method_chunks.each do |chunk|
            if chunk.has_parent?
              parent_key = [chunk.parent_id, chunk.parent_type, chunk.parent_name]
              parent_counts[parent_key] += 1
            end
          end

          return nil if parent_counts.empty?

          # 最も多く出現する親を返す
          parent_counts.max_by { |_, count| count }[0]
        end
      end
    end
  end
end
