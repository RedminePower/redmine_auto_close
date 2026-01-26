# redmine_auto_close

## 機能

- このプラグインインは、特定のトリガで、該当チケットのステータスを終了にしたり、担当者を変更したりすることができます。
  - 現在は「全子チケット終了時」のトリガのみをサポートしています。
  - 今後は「期限切れ時」のトリガもサポート予定です。
- 主に [Redmine Studio](https://www.redmine-power.com/) のレビュー機能と、合わせて使うことで、効果を発揮することができます。
  - 「Redmine Studio」のレビュー機能では、レビュー対象の配下に、レビュー依頼のチケットおよび、レビュー指摘のチケットが作成されます。
  - 全員がレビューを実施済みになり、すべてのレビュー指摘が終了になったら、レビュー開催のチケットを自動で終了にすることができます。 

## 対応Redmine
- V4.x (V4.2.3にて動作確認済み)
- V5.x (V5.0.3にて動作確認済み)
- V6.x (V6.0.3にて動作確認済み)

## インストール
Redmineのプラグインのフォルダにて、以下を実行し、Redmineを再起動してください。

```
$ cd /var/lib/redmine/plugins
$ git clone https://github.com/RedminePower/redmine_auto_close.git
$ bundle exec rake redmine:plugins:migrate NAME=redmine_auto_close RAILS_ENV=production
```

## アップグレード方法

### V1.x から V2.0 へのアップグレード

既存のインストールをRedmine 6.x対応版にアップグレードする場合:

1. プラグインのコードを更新:
```
$ cd /var/lib/redmine/plugins/redmine_auto_close
$ git pull
```

2. Redmineを再起動:
```
$ sudo systemctl restart redmine
```

**重要**: V2.0では、Redmine 6.xとの互換性のために内部実装を変更しましたが、データベーススキーマの変更はありません。マイグレーションの実行は不要です。既存の自動クローズ設定は、そのまま動作します。

### V2.0での主な変更点

- Redmine 6.x (Rails 7.0) に対応
- 内部実装をコントローラーフックからモデルコールバックに変更
- より安定した動作を実現
- 既存のデータベーススキーマと設定には影響なし

## 使用方法
1. プラグインをインストールすると、管理者メニューに「自動クローズ」が追加されます。
![image](https://user-images.githubusercontent.com/87136359/226633071-159626ee-aca0-4724-b651-187ca66de7b2.png)
1. 「自動クローズ」を押下すると、一覧画面に遷移します。
![image](https://user-images.githubusercontent.com/87136359/226633407-4cac6c54-d2fe-4d13-95fb-3c60c7ad765a.png)
1. 「新しい自動クローズ」を押下し、各種項目を入力し、「作成」ボタンを押下してください。
![image](https://github.com/user-attachments/assets/5973718c-a95b-4c38-836f-9bbad8b97e5a)
![image](https://github.com/user-attachments/assets/c8958af1-2a6a-4d52-b907-f96265a3c1f8)
1. 「トリガ」で設定した条件を満たした場合に、「アクション」で指定した内容を実行します。

## アンインストール

以下のコマンドを実行して、追加したDBを削除し、プラグインのフォルダを削除してください。

```
$ cd /var/lib/redmine/plugins
$ bundle exec rake redmine:plugins:migrate NAME=redmine_auto_close VERSION=0 RAILS_ENV=production
$ rm -rf redmine_auto_close
```


