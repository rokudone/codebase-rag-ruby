# frozen_string_literal: true

require "json"
require "time"
require_relative "todo_item"

module TodoApp
  # Todoリストクラス
  # Todoアイテムのコレクションを管理するクラス
  class TodoList
    # @return [Array<TodoApp::TodoItem>] Todoアイテムの配列
    attr_reader :items

    # @return [String] データファイルのパス
    attr_reader :file_path

    # 初期化
    # @param file_path [String] データファイルのパス
    def initialize(file_path = nil)
      @items = []
      @file_path = file_path
      load_from_file if @file_path && File.exist?(@file_path)
    end

    # アイテムを追加する
    # @param title [String] タイトル
    # @param description [String] 説明
    # @return [TodoApp::TodoItem] 追加されたTodoアイテム
    def add(title, description = "")
      item = TodoItem.new(title: title, description: description)
      @items << item
      save_to_file if @file_path
      item
    end

    # IDでアイテムを取得する
    # @param id [String] ID
    # @return [TodoApp::TodoItem, nil] 見つかったTodoアイテム、または見つからなかった場合はnil
    def get(id)
      @items.find { |item| item.id == id }
    end

    # IDでアイテムを削除する
    # @param id [String] ID
    # @return [TodoApp::TodoItem, nil] 削除されたTodoアイテム、または見つからなかった場合はnil
    def remove(id)
      item_index = @items.find_index { |item| item.id == id }
      return nil unless item_index

      removed_item = @items.delete_at(item_index)
      save_to_file if @file_path
      removed_item
    end

    # IDでアイテムの完了状態を切り替える
    # @param id [String] ID
    # @return [Boolean, nil] 新しい完了状態、または見つからなかった場合はnil
    def toggle_completed(id)
      item = get(id)
      return nil unless item

      result = item.toggle_completed
      save_to_file if @file_path
      result
    end

    # 完了済みのアイテムを取得する
    # @return [Array<TodoApp::TodoItem>] 完了済みのTodoアイテムの配列
    def completed_items
      @items.select(&:completed)
    end

    # 未完了のアイテムを取得する
    # @return [Array<TodoApp::TodoItem>] 未完了のTodoアイテムの配列
    def pending_items
      @items.reject(&:completed)
    end

    # キーワードでアイテムを検索する
    # @param keyword [String] 検索キーワード
    # @return [Array<TodoApp::TodoItem>] 検索結果のTodoアイテムの配列
    def search(keyword)
      keyword_downcase = keyword.to_s.downcase
      @items.select do |item|
        item.title.downcase.include?(keyword_downcase) ||
          item.description.downcase.include?(keyword_downcase)
      end
    end

    # ファイルに保存する
    # @param file_path [String] 保存先のファイルパス（指定しない場合は初期化時に指定したパス）
    # @return [Boolean] 保存に成功した場合はtrue
    def save_to_file(file_path = nil)
      file_path ||= @file_path
      return false unless file_path

      # ディレクトリが存在しない場合は作成
      dir_path = File.dirname(file_path)
      Dir.mkdir(dir_path) unless Dir.exist?(dir_path)

      File.open(file_path, "w") do |file|
        file.write(JSON.pretty_generate(to_h))
      end
      true
    end

    # ファイルから読み込む
    # @param file_path [String] 読み込むファイルパス（指定しない場合は初期化時に指定したパス）
    # @return [Boolean] 読み込みに成功した場合はtrue
    def load_from_file(file_path = nil)
      file_path ||= @file_path
      return false unless file_path && File.exist?(file_path)

      begin
        data = JSON.parse(File.read(file_path), symbolize_names: true)
        @items = data[:items].map { |item_data| TodoItem.from_h(item_data) }
        true
      rescue JSON::ParserError
        false
      end
    end

    # ハッシュに変換する
    # @return [Hash] ハッシュ
    def to_h
      {
        items: @items.map(&:to_h)
      }
    end

    # JSONに変換する
    # @return [String] JSON文字列
    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
