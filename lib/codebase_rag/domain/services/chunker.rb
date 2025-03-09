# frozen_string_literal: true

require "parser/current"
require "digest/md5"
require "find"

module CodebaseRag
  module Domain
    module Services
      # コードチャンカー
      # Rubyコードを解析して意味のある単位でチャンクに分割するサービス
      module Chunker
        # 最大トークン数（7000を超えないようにする）
        MAX_TOKENS = 7000

        module_function

        # テキストのトークン数を概算する（3文字で1トークン）
        # @param text [String] テキスト
        # @return [Integer] トークン数
        def estimate_token_count(text)
          return 0 if text.nil? || text.empty?

          # 3文字で1トークンとして計算
          (text.length / 3.0).ceil
        end

        # 指定されたディレクトリ内のすべてのRubyファイルとMarkdownファイルを検索する
        # @param root_dir [String] 検索対象のルートディレクトリ
        # @return [Array<String>] ファイルのパスの配列
        def find_all_ruby_files(root_dir)
          files = []

          Find.find(root_dir) do |path|
            # node_modules, dist, build, .next などのディレクトリはスキップ
            if File.directory?(path) && [
              "node_modules", "dist", "build", ".next", "tmp", "log", "coverage", "vendor"
            ].include?(File.basename(path))
              Find.prune
            elsif File.file?(path) && (path.end_with?(".rb") || path.end_with?(".md"))
              files << path
            end
          end

          files
        end

        # ファイルの内容からチャンクIDを生成する
        # @param file_path [String] ファイルパス
        # @param content [String] コンテンツ
        # @param start_line [Integer] 開始行
        # @param end_line [Integer] 終了行
        # @return [String] チャンクID
        def generate_chunk_id(file_path, content, start_line, end_line)
          hash = Digest::MD5.hexdigest("#{file_path}:#{start_line}-#{end_line}:#{content}")
          hash[0, 12] # 短いIDを使用
        end

        # チャンクを分割する
        # @param chunk [CodebaseRag::Domain::Entities::CodeChunk] 分割対象のチャンク
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] 分割されたチャンクの配列
        def split_chunk(chunk)
          # 行単位で分割
          lines = chunk.content.split("\n")
          chunks = []

          # 必要な分割数を計算
          num_parts = (chunk.token_count / MAX_TOKENS.to_f).ceil
          lines_per_part = (lines.size / num_parts.to_f).ceil

          # 分割して新しいチャンクを作成
          parts = lines.each_slice(lines_per_part).to_a
          parts.each_with_index do |part_lines, index|
            part_start_line = chunk.start_line + (index * lines_per_part)
            part_end_line = [part_start_line + part_lines.size - 1, chunk.end_line].min
            part_content = part_lines.join("\n")

            chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
              id: generate_chunk_id(chunk.file_path, part_content, part_start_line, part_end_line),
              content: part_content,
              file_path: chunk.file_path,
              start_line: part_start_line,
              end_line: part_end_line,
              type: chunk.type,
              name: chunk.name,
              context: chunk.context,
              part_number: index + 1,
              total_parts: parts.size,
              original_chunk_id: chunk.id
            )
          end

          chunks
        end

        # ファイルをチャンクに分割する
        # @param file_path [String] ファイルパス
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        def parse_file_to_chunks(file_path)
          content = File.read(file_path)
          lines = content.split("\n")
          initial_chunks = []

          begin
            # ASTパーサーを使用してファイルを解析
            buffer = Parser::Source::Buffer.new(file_path)
            buffer.source = content
            parser = Parser::CurrentRuby.new
            ast = parser.parse(buffer)

            # ASTからチャンクを抽出
            extract_chunks_from_ast(ast, file_path, lines, initial_chunks)
          rescue => e
            puts "ファイル #{file_path} の解析中にエラーが発生しました: #{e.message}"
          end

          # ファイル全体も1つのチャンクとして追加
          if lines.length > 0
            initial_chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
              id: generate_chunk_id(file_path, content, 1, lines.length),
              content: content,
              file_path: file_path,
              start_line: 1,
              end_line: lines.length,
              type: "file",
              name: File.basename(file_path),
              context: "Full file #{File.basename(file_path)}"
            )
          end

          # 各チャンクのトークン数をチェックし、必要に応じて分割
          result_chunks = []
          initial_chunks.each do |chunk|
            if chunk.token_count <= MAX_TOKENS
              # トークン数が制限以下なら、そのまま追加
              result_chunks << chunk
            else
              # トークン数が制限を超える場合は、分割したチャンクを追加（元のチャンクは追加しない）
              split_chunks = split_chunk(chunk)
              result_chunks.concat(split_chunks)
            end
          end

          result_chunks
        end

        # ASTからチャンクを抽出する
        # @param node [Parser::AST::Node] ASTノード
        # @param file_path [String] ファイルパス
        # @param lines [Array<String>] ファイルの行の配列
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        # @param parent_info [Array, nil] 親情報 [id, type, name]
        # @return [void]
        def extract_chunks_from_ast(node, file_path, lines, chunks, parent_info = nil)
          return unless node.is_a?(Parser::AST::Node)

          case node.type
          when :class
            # クラス定義
            if node.children[0].is_a?(Parser::AST::Node) && node.children[0].type == :const
              class_name = extract_const_name(node.children[0])
              start_line = node.loc.line
              end_line = node.loc.last_line
              class_content = lines[(start_line - 1)..(end_line - 1)].join("\n")

              # 依存関係の抽出
              dependencies = extract_dependencies(node)

              # クラスチャンクを作成
              class_chunk_id = generate_chunk_id(file_path, class_content, start_line, end_line)

              class_chunk = CodebaseRag::Domain::Entities::CodeChunk.new(
                id: class_chunk_id,
                content: class_content,
                file_path: file_path,
                start_line: start_line,
                end_line: end_line,
                type: "class",
                name: class_name,
                context: "Class #{class_name} in #{File.basename(file_path)}",
                parent_id: parent_info ? parent_info[0] : nil,
                parent_type: parent_info ? parent_info[1] : nil,
                parent_name: parent_info ? parent_info[2] : nil,
                dependencies: dependencies
              )

              chunks << class_chunk

              # クラス内のメソッドも抽出（親情報を渡す）
              node.children[2]&.children&.each do |child|
                extract_chunks_from_ast(
                  child,
                  file_path,
                  lines,
                  chunks,
                  [class_chunk_id, "class", class_name]
                )
              end
            end
          when :module
            # モジュール定義
            if node.children[0].is_a?(Parser::AST::Node) && node.children[0].type == :const
              module_name = extract_const_name(node.children[0])
              start_line = node.loc.line
              end_line = node.loc.last_line
              module_content = lines[(start_line - 1)..(end_line - 1)].join("\n")

              # 依存関係の抽出
              dependencies = extract_dependencies(node)

              # モジュールチャンクを作成
              module_chunk_id = generate_chunk_id(file_path, module_content, start_line, end_line)

              module_chunk = CodebaseRag::Domain::Entities::CodeChunk.new(
                id: module_chunk_id,
                content: module_content,
                file_path: file_path,
                start_line: start_line,
                end_line: end_line,
                type: "module",
                name: module_name,
                context: "Module #{module_name} in #{File.basename(file_path)}",
                parent_id: parent_info ? parent_info[0] : nil,
                parent_type: parent_info ? parent_info[1] : nil,
                parent_name: parent_info ? parent_info[2] : nil,
                dependencies: dependencies
              )

              chunks << module_chunk

              # モジュール内のメソッドも抽出（親情報を渡す）
              node.children[1]&.children&.each do |child|
                extract_chunks_from_ast(
                  child,
                  file_path,
                  lines,
                  chunks,
                  [module_chunk_id, "module", module_name]
                )
              end
            end
          when :def
            # メソッド定義
            method_name = node.children[0].to_s
            start_line = node.loc.line
            end_line = node.loc.last_line
            method_content = lines[(start_line - 1)..(end_line - 1)].join("\n")

            # 依存関係の抽出（メソッド内で呼び出している他のメソッドなど）
            dependencies = extract_method_dependencies(node)

            # コンテキスト情報を強化
            context = if parent_info
                        "Method #{method_name} in #{parent_info[1]} #{parent_info[2]} (#{File.basename(file_path)})"
                      else
                        "Method #{method_name} in #{File.basename(file_path)}"
                      end

            chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
              id: generate_chunk_id(file_path, method_content, start_line, end_line),
              content: method_content,
              file_path: file_path,
              start_line: start_line,
              end_line: end_line,
              type: "method",
              name: method_name,
              context: context,
              parent_id: parent_info ? parent_info[0] : nil,
              parent_type: parent_info ? parent_info[1] : nil,
              parent_name: parent_info ? parent_info[2] : nil,
              dependencies: dependencies
            )
          else
            # その他のノードは子ノードを再帰的に処理
            node.children.each do |child|
              extract_chunks_from_ast(child, file_path, lines, chunks, parent_info)
            end
          end
        end

        # 定数名を抽出する
        # @param node [Parser::AST::Node] 定数ノード
        # @return [String] 定数名
        def extract_const_name(node)
          return node.children[1].to_s if node.type == :const && node.children[0].nil?

          parent = extract_const_name(node.children[0])
          "#{parent}::#{node.children[1]}"
        end

        # クラスやモジュールの依存関係を抽出する
        # @param node [Parser::AST::Node] ASTノード
        # @return [Array<String>] 依存関係の配列
        def extract_dependencies(node)
          dependencies = []

          # 継承関係の抽出
          if node.type == :class && node.children[1]
            if node.children[1].is_a?(Parser::AST::Node) && node.children[1].type == :const
              superclass = extract_const_name(node.children[1])
              dependencies << "inherits from #{superclass}" unless superclass.empty?
            end
          end

          # includeやextendの抽出
          body_node = node.type == :class ? node.children[2] : node.children[1]
          if body_node.is_a?(Parser::AST::Node)
            body_node.children.each do |child|
              if child.is_a?(Parser::AST::Node) && child.type == :send
                if [:include, :extend, :prepend].include?(child.children[1])
                  if child.children[2].is_a?(Parser::AST::Node) && child.children[2].type == :const
                    module_name = extract_const_name(child.children[2])
                    dependencies << "#{child.children[1]}s #{module_name}" unless module_name.empty?
                  end
                end
              end
            end
          end

          dependencies
        end

        # メソッドの依存関係を抽出する
        # @param node [Parser::AST::Node] ASTノード
        # @return [Array<String>] 依存関係の配列
        def extract_method_dependencies(node)
          dependencies = []

          # メソッド呼び出しの抽出
          extract_method_calls(node, dependencies)

          dependencies.uniq
        end

        # メソッド呼び出しを抽出する（再帰的）
        # @param node [Parser::AST::Node] ASTノード
        # @param dependencies [Array<String>] 依存関係の配列
        # @return [void]
        def extract_method_calls(node, dependencies)
          return unless node.is_a?(Parser::AST::Node)

          # メソッド呼び出し
          if node.type == :send && !node.children[1].nil?
            method_name = node.children[1].to_s

            # 一般的なRubyメソッドやプライベートメソッドは除外
            unless %w[new initialize attr_reader attr_writer attr_accessor private protected public].include?(method_name)
              dependencies << method_name
            end
          end

          # 子ノードを再帰的に処理
          node.children.each do |child|
            extract_method_calls(child, dependencies)
          end
        end

        # コードベース全体をチャンクに分割する
        # @param root_dir [String] ルートディレクトリ
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        def chunk_codebase(root_dir)
          files = find_all_ruby_files(root_dir)
          all_chunks = []

          puts "#{files.length}個のRubyファイルが見つかりました"

          files.each do |file|
            chunks = parse_file_to_chunks(file)
            all_chunks.concat(chunks)
          end

          puts "合計#{all_chunks.length}個のコードチャンクを抽出しました"

          all_chunks
        end
      end
    end
  end
end
