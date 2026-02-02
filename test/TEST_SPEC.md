# Auto Close テスト仕様書

## 概要

redmine_auto_close プラグインのテスト仕様。全ての子チケットがクローズされた時に、親チケットを自動的にクローズ（またはステータス変更/担当者変更/コメント追加）する機能。

## 環境パラメータ

パスから自動判定:
- `redmine_5.1.11` → コンテナ名: `redmine_5.1.11`, ポート: `3051`
- `redmine_6.1.1` → コンテナ名: `redmine_6.1.1`, ポート: `3061`

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_auto_close` |
| コントローラ | `AutoClosesController` |
| エンドポイント | `/auto_closes` (RESTful) |
| モデル | `AutoClose` |
| DBテーブル | `auto_closes` |
| Issue パッチ | `RedmineAutoClose::IssuePatch` |
| サービス | `RedmineAutoClose::AutoCloseService` |
| 管理メニュー | `:auto_closes` |

---

## 設定項目一覧

| カテゴリ | 項目 | 設定値 |
|----------|------|--------|
| **基本** | タイトル | 任意テキスト（必須） |
| | 有効 | ON/OFF |
| | プロジェクト | 複数選択可 / 未指定 |
| **トリガ** | トリガ種類 | 全子チケット終了時 |
| | トラッカー | 指定 / 未指定 |
| | 題名のパターン | 正規表現 / 未指定 |
| | ステータス | 指定 / 未指定 |
| | カスタムフィールド | 真偽値CF / 未指定 |
| | 値 | true / false |
| **アクション** | ステータスを変更 | 指定 / 未指定 |
| | 担当者を変更 | ユーザー指定 / 未指定 |
| | カスタムフィールドで指定 | ユーザー型CF / 未指定 |
| | コメントを追加 | テキスト / 未指定 |
| | 親チケットにも追加 | ON / OFF |

---

## テスト実行フロー

### フェーズ 1: 登録確認テスト

プラグインの登録状態を確認する。

1. [1-1] ～ [1-6] を実行

### フェーズ 2: 機能テスト

自動クローズ機能の動作を確認する。

1. テストデータをセットアップ
2. [2-A] ～ [2-D] の各テストケースを実行
3. テストデータをクリーンアップ

---

## 1. 登録確認テスト

### [1-1] プラグイン登録確認

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_auto_close)
puts plugin.name
puts plugin.version
```

**期待結果:**
- name: `Redmine Auto Close plugin`
- version: `2.1.1`

### [1-2] 管理メニュー登録確認

**確認方法:**
```ruby
menu_items = Redmine::MenuManager.items(:admin_menu).map(&:name)
puts menu_items.include?(:auto_closes)
```

**期待結果:** `true` が出力される

### [1-3] ルーティング確認

**確認方法:**
```ruby
routes = [
  { path: '/auto_closes', method: :get, expected: { controller: 'auto_closes', action: 'index' } },
  { path: '/auto_closes/new', method: :get, expected: { controller: 'auto_closes', action: 'new' } },
  { path: '/auto_closes', method: :post, expected: { controller: 'auto_closes', action: 'create' } },
  { path: '/auto_closes/1', method: :get, expected: { controller: 'auto_closes', action: 'show', id: '1' } },
  { path: '/auto_closes/1/edit', method: :get, expected: { controller: 'auto_closes', action: 'edit', id: '1' } },
  { path: '/auto_closes/1', method: :patch, expected: { controller: 'auto_closes', action: 'update', id: '1' } },
  { path: '/auto_closes/1', method: :delete, expected: { controller: 'auto_closes', action: 'destroy', id: '1' } },
]

results = routes.map do |r|
  recognized = Rails.application.routes.recognize_path(r[:path], method: r[:method])
  r[:expected].all? { |k, v| recognized[k].to_s == v.to_s }
end

puts results.all?
```

**期待結果:** `true` が出力される

### [1-4] コントローラ確認

**確認方法:**
```ruby
puts defined?(AutoClosesController)
puts AutoClosesController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-5] Issue パッチ適用確認

**確認方法:**
```ruby
puts Issue.included_modules.include?(RedmineAutoClose::IssuePatch)
```

**期待結果:** `true` が出力される

### [1-6] AutoClose モデル確認

**確認方法:**
```ruby
puts defined?(AutoClose)
puts AutoClose.ancestors.include?(ActiveRecord::Base)

# デフォルト値の確認
ac = AutoClose.new
puts ac.trigger_type == 'children closed'
```

**期待結果:**
- `constant` が出力される
- `true` が出力される（2回）

---

## 2. 機能テスト

### テストデータ

テスト実行時に以下のデータを自動作成する:

**プロジェクト:**
- auto-close-test-1（テスト用プロジェクト1）
- auto-close-test-2（テスト用プロジェクト2）

**ユーザー:**
- ac-testuser1（担当者変更テスト用）
- ac-testuser2（担当者変更テスト用）

**カスタムフィールド:**
- AC_BoolField（真偽値型、トリガ条件用）
- AC_UserField（ユーザー型、担当者指定用）

**トラッカー:**
- 既存のトラッカーを使用

**ステータス:**
- 既存の「新規」「終了」ステータスを使用

---

### [2-A] 基本動作テスト

#### [2-A-1] 最小構成で動作

**条件:**
- ルール: ステータス変更のみ設定
- 親チケット1件、子チケット2件

**手順:**
1. ルールを作成（action_status=終了）
2. 親チケットと子チケット2件を作成
3. 子チケット1をクローズ
4. 親チケットのステータスを確認（変化なし）
5. 子チケット2をクローズ
6. 親チケットのステータスを確認

**期待結果:**
- 全子チケットクローズ後、親チケットのステータスが「終了」になる

#### [2-A-2] ルール無効時は動作しない

**条件:**
- ルール: is_enabled=false

**手順:**
1. 無効なルールを作成
2. 親チケットと子チケットを作成
3. 子チケットを全てクローズ
4. 親チケットのステータスを確認

**期待結果:**
- 親チケットのステータスは変化しない

---

### [2-B] トリガ条件テスト

#### [2-B-1] プロジェクト指定あり → 対象プロジェクトで発動

**条件:**
- ルール: project_ids=[プロジェクト1のID]
- チケット: プロジェクト1に作成

**期待結果:**
- 自動クローズが発動する

#### [2-B-2] プロジェクト指定あり → 対象外プロジェクトで発動しない

**条件:**
- ルール: project_ids=[プロジェクト1のID]
- チケット: プロジェクト2に作成

**期待結果:**
- 自動クローズが発動しない

#### [2-B-3] プロジェクト未指定 → 全プロジェクトで発動

**条件:**
- ルール: project_ids=[]（未指定）
- チケット: プロジェクト2に作成

**期待結果:**
- 自動クローズが発動する

#### [2-B-4] トラッカー指定あり → 対象トラッカーで発動

**条件:**
- ルール: trigger_tracker=バグ
- 親チケット: トラッカー=バグ

**期待結果:**
- 自動クローズが発動する

#### [2-B-5] トラッカー指定あり → 対象外トラッカーで発動しない

**条件:**
- ルール: trigger_tracker=バグ
- 親チケット: トラッカー=機能

**期待結果:**
- 自動クローズが発動しない

#### [2-B-6] 題名パターン一致 → 発動

**条件:**
- ルール: trigger_subject_pattern=`テスト.*`
- 親チケット: subject=`テスト親チケット`

**期待結果:**
- 自動クローズが発動する

#### [2-B-7] 題名パターン不一致 → 発動しない

**条件:**
- ルール: trigger_subject_pattern=`テスト.*`
- 親チケット: subject=`本番親チケット`

**期待結果:**
- 自動クローズが発動しない

#### [2-B-8] ステータス指定あり → 対象ステータスで発動

**条件:**
- ルール: trigger_status=新規
- 親チケット: status=新規

**期待結果:**
- 自動クローズが発動する

#### [2-B-9] ステータス指定あり → 対象外ステータスで発動しない

**条件:**
- ルール: trigger_status=新規
- 親チケット: status=進行中

**期待結果:**
- 自動クローズが発動しない

#### [2-B-10] カスタムフィールド条件一致 → 発動

**条件:**
- ルール: trigger_custom_field=AC_BoolField, trigger_custom_field_boolean=true
- 親チケット: AC_BoolField=true

**期待結果:**
- 自動クローズが発動する

#### [2-B-11] カスタムフィールド条件不一致 → 発動しない

**条件:**
- ルール: trigger_custom_field=AC_BoolField, trigger_custom_field_boolean=true
- 親チケット: AC_BoolField=false

**期待結果:**
- 自動クローズが発動しない

---

### [2-C] アクションテスト

#### [2-C-1] ステータス変更

**条件:**
- ルール: action_status=終了

**期待結果:**
- 親チケットのステータスが「終了」になる

#### [2-C-2] 担当者変更（直接指定）

**条件:**
- ルール: action_assigned_to=ac-testuser1

**期待結果:**
- 親チケットの担当者が ac-testuser1 になる

#### [2-C-3] 担当者変更（カスタムフィールドで指定）

**条件:**
- ルール: action_assigned_to_custom_field=AC_UserField
- 親チケット: AC_UserField=ac-testuser2

**期待結果:**
- 親チケットの担当者が ac-testuser2 になる

#### [2-C-4] 担当者変更（両方指定 → 直接指定が優先）

**条件:**
- ルール: action_assigned_to=ac-testuser1, action_assigned_to_custom_field=AC_UserField
- 親チケット: AC_UserField=ac-testuser2

**期待結果:**
- 親チケットの担当者が ac-testuser1 になる（直接指定が優先）

#### [2-C-5] コメント追加

**条件:**
- ルール: action_comment=`自動クローズしました`

**期待結果:**
- 親チケットに「自動クローズしました」コメントが追加される

#### [2-C-6] コメント追加 + 親チケットにも追加

**条件:**
- ルール: action_comment=`自動クローズしました`, is_action_comment_parent=true
- チケット構造: 祖父 → 親 → 子

**期待結果:**
- 親チケットにコメントが追加される
- 祖父チケットにもコメントが追加される

#### [2-C-7] 複合アクション

**条件:**
- ルール: action_status=終了, action_assigned_to=ac-testuser1, action_comment=`完了`

**期待結果:**
- 親チケットのステータスが「終了」になる
- 親チケットの担当者が ac-testuser1 になる
- 親チケットに「完了」コメントが追加される

---

### [2-D] エッジケーステスト

#### [2-D-1] 子チケットが1つだけ

**条件:**
- 親チケット1件、子チケット1件

**期待結果:**
- 子チケットをクローズすると、親チケットも自動クローズされる

#### [2-D-2] 子チケットが多数

**条件:**
- 親チケット1件、子チケット10件

**期待結果:**
- 全ての子チケットをクローズすると、親チケットも自動クローズされる
- 9件クローズ時点では親チケットは変化しない

#### [2-D-3] 孫チケットがある場合

**条件:**
- チケット構造: 親 → 子 → 孫

**期待結果:**
- 孫チケットをクローズ → 子チケットが自動クローズ
- 子チケットが自動クローズ → 親チケットも自動クローズ

#### [2-D-4] 複数ルールがマッチ → 最初のルールのみ適用

**条件:**
- ルール1: action_status=終了, action_comment=`ルール1`
- ルール2: action_status=終了, action_comment=`ルール2`

**期待結果:**
- 親チケットのコメントは「ルール1」（ID が小さい方が優先）

---

## 3. HTTP テスト

> **注記:** 現時点では HTTP テストは実施しない。
> 理由: 管理画面の CRUD 操作は標準的な Rails の実装であり、今回のリファクタリング（モデル・サービス・パッチの変更）では影響を受けない。
> 将来、コントローラのロジックを変更した場合や、redmine_studio_plugin に統合する際に追加を検討する。

### 確認可能な項目（参考）

| ID | 確認内容 |
|----|----------|
| [3-1] | 管理画面一覧（管理者） → 200 |
| [3-2] | 管理画面一覧（非管理者） → 302（リダイレクト） |
| [3-3] | ルール作成（POST） |
| [3-4] | ルール詳細表示（GET） |
| [3-5] | ルール更新（PATCH） |
| [3-6] | ルール削除（DELETE） |

---

## 4. ブラウザテスト

> **注記:** 現時点ではブラウザテストは実施しない。
> 理由: 今回のリファクタリングはバックエンドのロジック変更のみであり、UI には影響しない。
> 将来、UI を変更した場合や、JavaScript の動作確認が必要な場合に追加を検討する。

### 確認可能な項目（参考）

| ID | 確認内容 |
|----|----------|
| [4-1] | 管理画面でルール一覧表示 |
| [4-2] | ルール作成フォームの表示・入力・保存 |
| [4-3] | トリガ種類による表示切り替え（JavaScript） |
| [4-4] | バリデーションエラー時のメッセージ表示 |

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 1: 登録確認テスト実行
2. フェーズ 2: 機能テスト実行（セットアップ → テスト → クリーンアップ）

テスト実行時に必要なプロジェクト、ユーザー、チケット、カスタムフィールドなどは自動作成し、テスト終了後にクリーンアップする。
