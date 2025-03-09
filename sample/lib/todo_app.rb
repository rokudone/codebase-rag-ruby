# frozen_string_literal: true

require_relative "todo_item"
require_relative "todo_list"

module TodoApp
  # Todoアプリケーションクラス
  # アプリケーションのメインクラス
  class App
    # @return [TodoApp::TodoList] Todoリスト
    attr_reader :todo_list

    # 初期化
    # @param data_file [String] データファイルのパス
    def initialize(data_file = nil)
      data_file ||= File.join(Dir.home, ".todo_app_data.json")
      @todo_list = TodoList.new(data_file)
    end

    # Todoアイテムを追加する
    # @param title [String] タイトル
    # @param description [String] 説明
    # @return [TodoApp::TodoItem] 追加されたTodoアイテム
    def add_todo(title, description = "")
      @todo_list.add(title, description)
    end

    # Todoアイテムを一覧表示する
    # @param show_completed [Boolean] 完了済みのアイテムを表示するかどうか
    # @return [Array<TodoApp::TodoItem>] Todoアイテムの配列
    def list_todos(show_completed = true)
      if show_completed
        @todo_list.items
      else
        @todo_list.pending_items
      end
    end

    # Todoアイテムの完了状態を切り替える
    # @param id [String] ID
    # @return [Boolean, nil] 新しい完了状態、または見つからなかった場合はnil
    def toggle_todo(id)
      @todo_list.toggle_completed(id)
    end

    # Todoアイテムを削除する
    # @param id [String] ID
    # @return [TodoApp::TodoItem, nil] 削除されたTodoアイテム、または見つからなかった場合はnil
    def remove_todo(id)
      @todo_list.remove(id)
    end

    # キーワードでTodoアイテムを検索する
    # @param keyword [String] 検索キーワード
    # @return [Array<TodoApp::TodoItem>] 検索結果のTodoアイテムの配列
    def search_todos(keyword)
      @todo_list.search(keyword)
    end

    # Todoアイテムの詳細を取得する
    # @param id [String] ID
    # @return [TodoApp::TodoItem, nil] 見つかったTodoアイテム、または見つからなかった場合はnil
    def get_todo(id)
      @todo_list.get(id)
    end

    # データを保存する
    # @return [Boolean] 保存に成功した場合はtrue
    def save
      @todo_list.save_to_file
    end

    # データを読み込む
    # @return [Boolean] 読み込みに成功した場合はtrue
    def load
      @todo_list.load_from_file
    end
  end
end
