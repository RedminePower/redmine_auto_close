# redmine_auto_close

## 機能

特定のトリガーで、該当チケットに対して、自動的にアクションを行うプラグインです。

**実行可能なアクション:**
- ステータス変更
- 担当者変更
- コメント追加

### トリガー種類

#### 全子チケット終了時
親チケットの全ての子チケットが終了されたときに、親チケットに対してアクションを実行します。

**特徴:**
- [Redmine Studio](https://www.redmine-power.com/) のレビュー機能と連携可能
  - レビュー機能では、レビュー開催チケットの配下に、レビュー依頼・レビュー指摘のチケットが作成される
  - レビュー依頼・レビュー指摘がすべて終了したら、レビュー開催チケットを自動で終了

**ユースケース:**
- 親チケットを複数のサブタスクに分解し、すべて完了したら親を自動で終了
- リリースチケット配下の機能追加・バグ修正がすべて完了したら、リリースを自動で終了

#### 期限切れ時
期限日を過ぎたチケットを定期的にチェックし、条件に一致するチケットに対してアクションを実行します。

**特徴:**
- cron による定期実行（毎日 3:00）
  - 手動で実行する場合
  ```
  $ bundle exec rake redmine_auto_close:check_expired RAILS_ENV=production
  ```
- 閾値設定により意図しない大量更新を防止
- アクションの実行ユーザーを指定可能（担当者/作成者/親チケットの担当者/固定ユーザー）

**ユースケース:**
- 放置チケットの整理 - 期限を過ぎても対応されないチケットを自動で終了し、チケット一覧をクリーンに保つ
- 期限超過時のエスカレーション - 期限切れチケットの担当者を上長や管理者に変更し、対応を促進
- 対応漏れの防止 - 期限切れチケットにリマインドコメントを追加し、関係者に注意喚起

## 対応バージョン
- Redmine 4.x（4.2.3 にて動作確認済み）
- Redmine 5.x（5.1.11 にて動作確認済み）
- Redmine 6.x（6.1.1 にて動作確認済み）

## インストール
以下を実行し、Redmineを再起動してください。

```
$ cd /path/to/redmine/plugins
$ git clone https://github.com/RedminePower/redmine_auto_close.git
$ bundle exec rake redmine_auto_close:install RAILS_ENV=production
```

`install` タスクは以下を実行します:
1. データベースマイグレーション
2. cron ジョブの登録（毎日 3:00 に期限切れチェックを実行）

## アップグレード
以下を実行し、Redmineを再起動してください。
既存の「自動クローズ」設定は、そのまま引き継がれます。

```
$ cd /path/to/redmine/plugins/redmine_auto_close
$ git pull
$ bundle exec rake redmine_auto_close:install RAILS_ENV=production
```

## 使用方法
1. プラグインをインストールすると、管理者メニューに「自動クローズ」が追加されます。
![image](https://user-images.githubusercontent.com/87136359/226633071-159626ee-aca0-4724-b651-187ca66de7b2.png)
2. 「自動クローズ」を押下すると、一覧画面に遷移します。
![image](https://user-images.githubusercontent.com/87136359/226633407-4cac6c54-d2fe-4d13-95fb-3c60c7ad765a.png)
3. 「新しい自動クローズ」を押下し、各種項目を入力し、「作成」ボタンを押下してください。
![image](https://github.com/user-attachments/assets/5973718c-a95b-4c38-836f-9bbad8b97e5a)
![image](https://github.com/user-attachments/assets/c8958af1-2a6a-4d52-b907-f96265a3c1f8)
4. 「トリガー」で設定した条件を満たした場合に、「アクション」で指定した内容を実行します。

## アンインストール

以下を実行し、Redmineを再起動してください。

```
$ cd /path/to/redmine
$ bundle exec rake redmine_auto_close:uninstall RAILS_ENV=production
$ rm -rf plugins/redmine_auto_close
```

`uninstall` タスクは以下を実行します:
1. cron ジョブの解除
2. データベースのロールバック

