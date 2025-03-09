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
        module_function

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

        # ファイルをチャンクに分割する
        # @param file_path [String] ファイルパス
        # @return [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        def parse_file_to_chunks(file_path)
          content = File.read(file_path)
          lines = content.split("\n")
          chunks = []

          begin
            # ASTパーサーを使用してファイルを解析
            buffer = Parser::Source::Buffer.new(file_path)
            buffer.source = content
            parser = Parser::CurrentRuby.new
            ast = parser.parse(buffer)

            # ASTからチャンクを抽出
            extract_chunks_from_ast(ast, file_path, lines, chunks)
          rescue => e
            puts "ファイル #{file_path} の解析中にエラーが発生しました: #{e.message}"
          end

          # ファイル全体も1つのチャンクとして追加
          if lines.length > 0
            chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
              id: generate_chunk_id(file_path, content, 1, lines.length),
              content: content,
              file_path: file_path,
              start_line: 1,
              end_line: lines.length,
              type: "other",
              name: File.basename(file_path),
              context: "Full file #{File.basename(file_path)}"
            )
          end

          chunks
        end

        # ASTからチャンクを抽出する
        # @param node [Parser::AST::Node] ASTノード
        # @param file_path [String] ファイルパス
        # @param lines [Array<String>] ファイルの行の配列
        # @param chunks [Array<CodebaseRag::Domain::Entities::CodeChunk>] チャンクの配列
        # @return [void]
        def extract_chunks_from_ast(node, file_path, lines, chunks)
          return unless node.is_a?(Parser::AST::Node)

          case node.type
          when :class
            # クラス定義
            if node.children[0].is_a?(Parser::AST::Node) && node.children[0].type == :const
              class_name = extract_const_name(node.children[0])
              start_line = node.loc.line
              end_line = node.loc.last_line
              class_content = lines[(start_line - 1)..(end_line - 1)].join("\n")

              chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
                id: generate_chunk_id(file_path, class_content, start_line, end_line),
                content: class_content,
                file_path: file_path,
                start_line: start_line,
                end_line: end_line,
                type: "class",
                name: class_name,
                context: "Class #{class_name} in #{File.basename(file_path)}"
              )

              # クラス内のメソッドも抽出
              node.children[2]&.children&.each do |child|
                extract_chunks_from_ast(child, file_path, lines, chunks)
              end
            end
          when :module
            # モジュール定義
            if node.children[0].is_a?(Parser::AST::Node) && node.children[0].type == :const
              module_name = extract_const_name(node.children[0])
              start_line = node.loc.line
              end_line = node.loc.last_line
              module_content = lines[(start_line - 1)..(end_line - 1)].join("\n")

              chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
                id: generate_chunk_id(file_path, module_content, start_line, end_line),
                content: module_content,
                file_path: file_path,
                start_line: start_line,
                end_line: end_line,
                type: "module",
                name: module_name,
                context: "Module #{module_name} in #{File.basename(file_path)}"
              )

              # モジュール内のメソッドも抽出
              node.children[1]&.children&.each do |child|
                extract_chunks_from_ast(child, file_path, lines, chunks)
              end
            end
          when :def
            # メソッド定義
            method_name = node.children[0].to_s
            start_line = node.loc.line
            end_line = node.loc.last_line
            method_content = lines[(start_line - 1)..(end_line - 1)].join("\n")

            chunks << CodebaseRag::Domain::Entities::CodeChunk.new(
              id: generate_chunk_id(file_path, method_content, start_line, end_line),
              content: method_content,
              file_path: file_path,
              start_line: start_line,
              end_line: end_line,
              type: "method",
              name: method_name,
              context: "Method #{method_name} in #{File.basename(file_path)}"
            )
          else
            # その他のノードは子ノードを再帰的に処理
            node.children.each do |child|
              extract_chunks_from_ast(child, file_path, lines, chunks)
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
