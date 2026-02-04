# Auto Close テスト仕様書

## 概要

redmine_auto_close プラグインのテスト仕様。以下の2つのトリガーをサポート:

1. **全子チケット終了時**: 全ての子チケットがクローズされた時に、親チケットを自動的にクローズ（またはステータス変更/担当者変更/コメント追加）する機能。
2. **期限切れ時**: 期限日を過ぎたチケットを自動的に処理する機能（rake タスクによる定期実行）。

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
| **トリガー** | トリガー種類 | 全子チケット終了時 / 期限切れ時 |
| | トラッカー | 指定 / 未指定 |
| | 題名のパターン | 正規表現 / 未指定 |
| | ステータス | 指定 / 未指定 |
| | カスタムフィールド | 真偽値CF / 未指定 |
| | 値 | true / false |
| | 一度に処理する最大件数 | 数値（期限切れ時のみ、デフォルト: 50） |
| **アクション** | 実行ユーザー | 担当者/作成者/親担当者/固定ユーザー（期限切れ時のみ必須） |
| | ステータスを変更 | 指定 / 未指定 |
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
2. 以下の各テストケースを実行

**共通:**
- [2-I] rake タスク（install / uninstall）

**全子チケット終了時:**
- [2-A] 基本動作テスト
- [2-B] トリガー条件テスト
- [2-C] アクションテスト
- [2-D] エッジケーステスト

**期限切れ時:**
- [2-E] 基本動作テスト
- [2-F] トリガー条件テスト
- [2-G] アクションテスト
- [2-H] エッジケーステスト

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
puts ac.action_user == 'assignee'
puts ac.max_issues_per_run == 50
```

**期待結果:**
- `constant` が出力される
- `true` が出力される（4回）

---

## 2. 機能テスト

### テストデータ

テスト実行時に以下のデータを自動作成する:

**プロジェクト:**
- auto-close-test-1（テスト用プロジェクト1）
- auto-close-test-2（テスト用プロジェクト2）

**ユーザー:**
- autoclose-testuser1（担当者変更テスト用）
- autoclose-testuser2（担当者変更テスト用）

**カスタムフィールド:**
- AutoClose_BoolField（真偽値型、トリガー条件用）
- AutoClose_UserField（ユーザー型、担当者指定用）

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

### [2-B] トリガー条件テスト

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

> **注記:** カスタムフィールドを使用するテストでは StaleObjectError が発生することがあります。
> その場合、`RedmineAutoClose::AutoCloseService.matches?(project, parent, rule)` を直接呼び出してトリガー条件のマッチングを検証してください。

**条件:**
- ルール: trigger_custom_field=AutoClose_BoolField, trigger_custom_field_boolean=true
- 親チケット: AutoClose_BoolField=true

**期待結果:**
- 自動クローズが発動する（`matches?` が `true` を返す）

#### [2-B-11] カスタムフィールド条件不一致 → 発動しない

**条件:**
- ルール: trigger_custom_field=AutoClose_BoolField, trigger_custom_field_boolean=true
- 親チケット: AutoClose_BoolField=false

**期待結果:**
- 自動クローズが発動しない（`matches?` が `false` を返す）

---

### [2-C] アクションテスト

> **注記:** カスタムフィールドを使用するテスト（[2-C-3], [2-C-4] など）では、子チケットのクローズ時に auto_close コールバックが親チケットを更新するため、楽観的ロック（StaleObjectError）が発生することがあります。
> この場合、`RedmineAutoClose::AutoCloseService.apply_rule(rule, parent)` を直接呼び出してアクションのロジックを検証してください。

#### [2-C-1] ステータス変更

**条件:**
- ルール: action_status=終了

**期待結果:**
- 親チケットのステータスが「終了」になる

#### [2-C-2] 担当者変更（直接指定）

**条件:**
- ルール: action_assigned_to=autoclose-testuser1

**期待結果:**
- 親チケットの担当者が autoclose-testuser1 になる

#### [2-C-3] 担当者変更（カスタムフィールドで指定）

**条件:**
- ルール: action_assigned_to_custom_field=AutoClose_UserField
- 親チケット: AutoClose_UserField=autoclose-testuser2

**期待結果:**
- 親チケットの担当者が autoclose-testuser2 になる

#### [2-C-4] 担当者変更（両方指定 → 直接指定が優先）

**条件:**
- ルール: action_assigned_to=autoclose-testuser1, action_assigned_to_custom_field=AutoClose_UserField
- 親チケット: AutoClose_UserField=autoclose-testuser2

**期待結果:**
- 親チケットの担当者が autoclose-testuser1 になる（直接指定が優先）

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
- ルール: action_status=終了, action_assigned_to=autoclose-testuser1, action_comment=`完了`

**期待結果:**
- 親チケットのステータスが「終了」になる
- 親チケットの担当者が autoclose-testuser1 になる
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

### [2-E] 期限切れトリガーテスト

#### [2-E-1] 期限切れトリガーのバリデーション（条件必須）

**条件:**
- ルール: trigger_type=expired, 条件なし

**手順:**
1. 期限切れトリガーのルールを条件なしで作成しようとする

**期待結果:**
- バリデーションエラーが発生する
- 「少なくとも1つの条件を設定してください」エラーメッセージ

#### [2-E-2] 期限切れトリガーのバリデーション（action_user 必須）

**条件:**
- ルール: trigger_type=expired, trigger_tracker=バグ, action_user=nil

**手順:**
1. 期限切れトリガーのルールを action_user なしで作成しようとする

**期待結果:**
- バリデーションエラーが発生する

#### [2-E-2a] max_issues_per_run のバリデーション

**条件:**
- ルール: max_issues_per_run に不正な値を設定

**手順:**
```ruby
# 空の場合
ac = AutoClose.new(title: 'Test', trigger_type: 'expired', action_status: 1, action_user: 'author', max_issues_per_run: nil)
puts ac.valid? # false

# 0の場合
ac.max_issues_per_run = 0
puts ac.valid? # false

# 負の数の場合
ac.max_issues_per_run = -1
puts ac.valid? # false

# 小数の場合
ac.max_issues_per_run = 1.5
puts ac.valid? # false

# 正の整数の場合
ac.max_issues_per_run = 1
puts ac.valid? # true
```

**期待結果:**
- 空、0、負の数、小数の場合はバリデーションエラー
- 正の整数の場合は有効

#### [2-E-3] 期限切れチケットの検出

**条件:**
- ルール: trigger_type=expired, trigger_tracker=バグ, action_status=終了, action_user=assignee
- チケット1: due_date=昨日, tracker=バグ, status=新規
- チケット2: due_date=明日, tracker=バグ, status=新規
- チケット3: due_date=昨日, tracker=機能, status=新規

**手順:**
1. ルールと各チケットを作成
2. `find_expired_issues` を実行

**期待結果:**
- チケット1のみが検出される

#### [2-E-4] 既に対象ステータスのチケットは除外

**条件:**
- ルール: trigger_type=expired, trigger_tracker=バグ, action_status=終了
- チケット1: due_date=昨日, status=新規
- チケット2: due_date=昨日, status=終了

**期待結果:**
- チケット1のみが検出される（チケット2は既に終了ステータス）

#### [2-E-5] 閾値超過時は処理スキップ

**条件:**
- ルール: trigger_type=expired, max_issues_per_run=2
- 期限切れチケット: 5件

**期待結果:**
- 処理がスキップされる（1件もクローズされない）
- ログに警告が出力される

#### [2-E-6] action_user の解決（対象チケットの担当者）

**条件:**
- ルール: action_user=assignee
- チケット: assigned_to=autoclose-testuser1

**期待結果:**
- autoclose-testuser1 が実行ユーザーとして使用される

#### [2-E-7] action_user の解決（対象チケットの作成者）

**条件:**
- ルール: action_user=author
- チケット: author=autoclose-testuser2

**期待結果:**
- autoclose-testuser2 が実行ユーザーとして使用される

#### [2-E-8] action_user の解決（親チケットの担当者）

**条件:**
- ルール: action_user=parent_assignee
- 親チケット: assigned_to=autoclose-testuser1
- 子チケット: 期限切れ

**期待結果:**
- autoclose-testuser1 が実行ユーザーとして使用される

#### [2-E-9] action_user の解決（固定ユーザー）

**条件:**
- ルール: action_user=<ユーザーID>

**期待結果:**
- 指定されたユーザーが実行ユーザーとして使用される

#### [2-E-10] check_expired の統合テスト

**概要:**
rake タスク `check_expired` を実行し、期限切れチケットの検出からアクション適用までの一連の処理が正常に動作することを確認する。

**条件:**
- 有効な期限切れルールが存在
- 期限切れチケットが存在

**手順:**
1. `bundle exec rake redmine_auto_close:check_expired` を実行

**期待結果:**
- 期限切れチケットのステータスが変更される
- ログにサマリーが出力される

---

### [2-F] 期限切れトリガー条件テスト

#### [2-F-1] プロジェクト指定あり → 対象プロジェクトで発動

**条件:**
- ルール: trigger_type=expired, project_ids=[プロジェクト1のID], action_user=author
- チケット: プロジェクト1に作成、期限切れ

**期待結果:**
- チケットが処理される

#### [2-F-2] プロジェクト指定あり → 対象外プロジェクトで発動しない

**条件:**
- ルール: trigger_type=expired, project_ids=[プロジェクト1のID], action_user=author
- チケット: プロジェクト2に作成、期限切れ

**期待結果:**
- チケットが処理されない

#### [2-F-2a] トラッカー指定あり → 対象トラッカーで発動

**条件:**
- ルール: trigger_type=expired, trigger_tracker=バグ, action_user=author
- チケット: tracker=バグ、期限切れ

**期待結果:**
- チケットが処理される

#### [2-F-2b] トラッカー指定あり → 対象外トラッカーで発動しない

**条件:**
- ルール: trigger_type=expired, trigger_tracker=バグ, action_user=author
- チケット: tracker=機能、期限切れ

**期待結果:**
- チケットが処理されない

#### [2-F-3] ステータス指定あり → 対象ステータスで発動

**条件:**
- ルール: trigger_type=expired, trigger_status=新規, action_user=author
- チケット: status=新規、期限切れ

**期待結果:**
- チケットが処理される

#### [2-F-4] ステータス指定あり → 対象外ステータスで発動しない

**条件:**
- ルール: trigger_type=expired, trigger_status=新規, action_user=author
- チケット: status=進行中、期限切れ

**期待結果:**
- チケットが処理されない

#### [2-F-5] 題名パターン一致 → 発動

**条件:**
- ルール: trigger_type=expired, trigger_subject_pattern=`テスト.*`, action_user=author
- チケット: subject=`テスト期限切れ`、期限切れ

**期待結果:**
- チケットが処理される

#### [2-F-6] 題名パターン不一致 → 発動しない

**条件:**
- ルール: trigger_type=expired, trigger_subject_pattern=`テスト.*`, action_user=author
- チケット: subject=`本番期限切れ`、期限切れ

**期待結果:**
- チケットが処理されない

#### [2-F-7] カスタムフィールド条件一致 → 発動

**条件:**
- ルール: trigger_type=expired, trigger_custom_field=AutoClose_BoolField, trigger_custom_field_boolean=true, action_user=author
- チケット: AutoClose_BoolField=true、期限切れ

**期待結果:**
- チケットが処理される

#### [2-F-8] カスタムフィールド条件不一致 → 発動しない

**条件:**
- ルール: trigger_type=expired, trigger_custom_field=AutoClose_BoolField, trigger_custom_field_boolean=true, action_user=author
- チケット: AutoClose_BoolField=false、期限切れ

**期待結果:**
- チケットが処理されない

---

### [2-G] 期限切れトリガーアクションテスト

#### [2-G-1] ステータス変更

**条件:**
- ルール: trigger_type=expired, action_status=終了, action_user=author

**期待結果:**
- チケットのステータスが「終了」になる
- ジャーナルにステータス変更が記録される

#### [2-G-2] 担当者変更（直接指定）

**条件:**
- ルール: trigger_type=expired, action_assigned_to=autoclose-testuser1, action_user=author

**期待結果:**
- チケットの担当者が autoclose-testuser1 になる

#### [2-G-3] 担当者変更（カスタムフィールドで指定）

**条件:**
- ルール: trigger_type=expired, action_assigned_to_custom_field=AutoClose_UserField, action_user=author
- チケット: AutoClose_UserField=autoclose-testuser2

**期待結果:**
- チケットの担当者が autoclose-testuser2 になる

#### [2-G-4] コメント追加

**条件:**
- ルール: trigger_type=expired, action_comment=`期限切れのため自動クローズ`, action_user=author

**期待結果:**
- チケットに「期限切れのため自動クローズ」コメントが追加される
- コメントの作成者は action_user で指定したユーザー

#### [2-G-5] コメント追加 + 親チケットにも追加

**条件:**
- ルール: trigger_type=expired, action_comment=`期限切れ`, is_action_comment_parent=true, action_user=author
- チケット構造: 親 → 子（子が期限切れ）

**期待結果:**
- 子チケットにコメントが追加される
- 親チケットにもコメントが追加される

#### [2-G-6] 複合アクション

**条件:**
- ルール: trigger_type=expired, action_status=終了, action_assigned_to=autoclose-testuser1, action_comment=`完了`, action_user=author

**期待結果:**
- チケットのステータスが「終了」になる
- チケットの担当者が autoclose-testuser1 になる
- チケットに「完了」コメントが追加される

---

### [2-H] 期限切れトリガーエッジケーステスト

#### [2-H-1] action_user が解決できない場合（担当者未設定）

**条件:**
- ルール: trigger_type=expired, action_user=assignee
- チケット: assigned_to=nil（担当者未設定）、期限切れ

**期待結果:**
- チケットは処理されない（スキップ）
- ログにエラーが出力される
- 後続のチケットは正常に処理される

#### [2-H-2] action_user が解決できない場合（親チケットなし）

**条件:**
- ルール: trigger_type=expired, action_user=parent_assignee
- チケット: parent_id=nil（親チケットなし）、期限切れ

**期待結果:**
- チケットは処理されない（スキップ）
- ログにエラーが出力される

#### [2-H-3] 複数ルールがマッチ → 最初のルールのみ適用

**条件:**
- ルール1: trigger_type=expired, action_comment=`ルール1`, action_user=author
- ルール2: trigger_type=expired, action_comment=`ルール2`, action_user=author
- 両ルールの条件に一致するチケット

**期待結果:**
- チケットのコメントは「ルール1」のみ（ID が小さい方が優先）
- チケットは1回のみ処理される
- ログに「Issue #XX already processed by rule #1, skipping rule #2」が出力される
- サマリーに「skipped (already processed)」が含まれる

#### [2-H-4] 処理中にエラーが発生しても後続は継続

**条件:**
- ルール: trigger_type=expired, action_user=assignee
- チケット1: assigned_to=nil（エラー発生）
- チケット2: assigned_to=autoclose-testuser1（正常）

**期待結果:**
- チケット1はスキップ（エラーログ出力）
- チケット2は正常に処理される
- サマリーに processed: 1, failed: 1 と出力

---

## [2-I] rake タスク（install / uninstall）

プラグインのセットアップ・アンインストール用 rake タスクのテスト。

### [2-I-1] install タスクの実行

**手順:**
1. `bundle exec rake redmine_auto_close:install` を実行
2. `crontab -l` で cron 登録を確認

**期待結果:**
- エラーなく完了する
- ログに「Installation completed」が出力される
- `redmine_auto_close:check_expired` を含む cron エントリが存在する
- 実行時刻が `0 3 * * *`（毎日3時）である

**備考:**
- 登録した cron エントリはテスト後も削除しない
- 実際の cron 実行は本番環境でログを確認して検証する

### [2-I-2] uninstall タスクの動作確認

**手順:**
1. `bundle exec rake redmine_auto_close:uninstall` を実行
2. `crontab -l` で cron が解除されていることを確認
3. `auto_closes` テーブルが削除されていることを確認

**期待結果:**
- エラーなく完了する
- ログに「Uninstallation completed」が出力される
- cron エントリが削除されている
- `auto_closes` テーブルが存在しない

**備考:**
- uninstall は DB ロールバック（`auto_closes` テーブル削除）を行う
- 他のテーブル（Redmine 本体、他プラグイン）には影響しない
- 通常のテストでは実行しない（プラグイン削除時のみ使用）
- 実行後はプラグインが動作しなくなるため、再度 `install` が必要

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
| [4-3] | トリガー種類による表示切り替え（JavaScript） |
| [4-4] | バリデーションエラー時のメッセージ表示 |

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 1: 登録確認テスト実行
2. フェーズ 2: 機能テスト実行（セットアップ → テスト）

テストデータの管理は CLAUDE.md の「テストデータの管理」ルールに従う。

### Runner テスト実行時の注意事項

bash 経由での `!` エスケープ問題については、CLAUDE.md の「Runner テスト」セクションを参照。
