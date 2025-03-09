# frozen_string_literal: true

require "time"

module TodoApp
  # Todoアイテムクラス
  # Todoの個々のアイテムを表現するクラス
  class TodoItem
    # @return [String] ID
    attr_reader :id

    # @return [String] タイトル
    attr_accessor :title

    # @return [String] 説明
    attr_accessor :description

    # @return [Boolean] 完了状態
    attr_reader :completed

    # @return [Time] 作成日時
    attr_reader :created_at

    # @return [Time] 更新日時
    attr_reader :updated_at

    # 初期化
    # @param id [String] ID
    # @param title [String] タイトル
    # @param description [String] 説明
    # @param completed [Boolean] 完了状態
    # @param created_at [Time] 作成日時
    # @param updated_at [Time] 更新日時
    def initialize(id: nil, title:, description: "", completed: false, created_at: nil, updated_at: nil)
      @id = id || generate_id
      @title = title
      @description = description
      @completed = completed
      @created_at = created_at || Time.now
      @updated_at = updated_at || Time.now
    end

    # 完了状態を切り替える
    # @return [Boolean] 新しい完了状態
    def toggle_completed
      @completed = !@completed
      @updated_at = Time.now
      @completed
    end

    # 完了状態を設定する
    # @param value [Boolean] 設定する完了状態
    # @return [Boolean] 設定された完了状態
    def completed=(value)
      @completed = !!value
      @updated_at = Time.now
      @completed
    end

    # ハッシュに変換する
    # @return [Hash] ハッシュ
    def to_h
      {
        id: @id,
        title: @title,
        description: @description,
        completed: @completed,
        created_at: @created_at.iso8601,
        updated_at: @updated_at.iso8601
      }
    end

    # JSONに変換する
    # @return [String] JSON文字列
    def to_json(*args)
      to_h.to_json(*args)
    end

    # ハッシュから作成する
    # @param hash [Hash] ハッシュ
    # @return [TodoApp::TodoItem] Todoアイテム
    def self.from_h(hash)
      new(
        id: hash[:id] || hash["id"],
        title: hash[:title] || hash["title"],
        description: hash[:description] || hash["description"] || "",
        completed: hash[:completed] || hash["completed"] || false,
        created_at: Time.parse(hash[:created_at] || hash["created_at"]),
        updated_at: Time.parse(hash[:updated_at] || hash["updated_at"])
      )
    end

    private

    # IDを生成する
    # @return [String] 生成されたID
    def generate_id
      Time.now.to_i.to_s + rand(1000..9999).to_s
    end
  end
end
