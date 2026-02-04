# frozen_string_literal: true

namespace :redmine_auto_close do
  desc '期限切れチケットの自動クローズを実行'
  task check_expired: :environment do
    processed_ids = []
    failed_ids = []
    skipped_rule_ids = []
    # 処理済みチケットを記録（issue_id => rule_id）
    already_processed = {}
    skipped_issue_ids = []

    rules = AutoClose.where(trigger_type: AutoClose::TRIGGER_TYPES_EXPIRED, is_enabled: true).order(:id)

    rules.each do |rule|
      issues = RedmineAutoClose::AutoCloseService.find_expired_issues(rule)

      # 閾値チェック
      if issues.count > rule.max_issues_per_run
        Rails.logger.warn "[redmine_auto_close] Warning: Rule ##{rule.id} '#{rule.title}' targets #{issues.count} issues > threshold #{rule.max_issues_per_run} -> skipped"
        skipped_rule_ids << rule.id
        next
      end

      issues.each do |issue|
        # 既に他のルールで処理済みの場合はスキップ
        if already_processed.key?(issue.id)
          Rails.logger.info "[redmine_auto_close] Info: Issue ##{issue.id} already processed by rule ##{already_processed[issue.id]}, skipping rule ##{rule.id}"
          skipped_issue_ids << issue.id unless skipped_issue_ids.include?(issue.id)
          next
        end

        begin
          # action_user を解決して User.current に設定
          action_user = RedmineAutoClose::AutoCloseService.resolve_action_user(rule, issue)
          if action_user.nil?
            Rails.logger.error "[redmine_auto_close] Error: Failed to process issue ##{issue.id}: Could not resolve action user"
            failed_ids << issue.id
            next
          end

          User.current = action_user
          RedmineAutoClose::AutoCloseService.apply_rule(rule, issue)
          processed_ids << issue.id
          already_processed[issue.id] = rule.id
        rescue => e
          Rails.logger.error "[redmine_auto_close] Error: Failed to process issue ##{issue.id}: #{e.message}"
          failed_ids << issue.id
        end
      end
    end

    summary = "[redmine_auto_close] Completed: #{processed_ids.size} processed / #{failed_ids.size} failed / #{skipped_issue_ids.size} skipped (already processed) / #{skipped_rule_ids.size} rules skipped"
    if processed_ids.any? || failed_ids.any? || skipped_issue_ids.any? || skipped_rule_ids.any?
      details = []
      details << "processed: #{processed_ids.map { |id| "##{id}" }.join(', ')}" if processed_ids.any?
      details << "failed: #{failed_ids.map { |id| "##{id}" }.join(', ')}" if failed_ids.any?
      details << "skipped: #{skipped_issue_ids.map { |id| "##{id}" }.join(', ')}" if skipped_issue_ids.any?
      details << "skipped rules: #{skipped_rule_ids.map { |id| "##{id}" }.join(', ')}" if skipped_rule_ids.any?
      summary += " (#{details.join(' / ')})"
    end
    Rails.logger.info summary
  end

  desc 'プラグインのセットアップ（DBマイグレーション + cron登録）'
  task install: :environment do
    puts '=== redmine_auto_close install ==='

    # 1. DBマイグレーション
    puts "\n[1/2] Running DB migration..."
    Rake::Task['redmine:plugins:migrate'].invoke
    puts 'Done'

    # 2. cron登録
    puts "\n[2/2] Registering cron job..."
    redmine_path = Rails.root
    cron_line = "0 3 * * * cd #{redmine_path} && bundle exec rake redmine_auto_close:check_expired RAILS_ENV=production >> log/auto_close.log 2>&1"
    current_cron = `crontab -l 2>/dev/null` rescue ''

    if current_cron.include?('redmine_auto_close:check_expired')
      puts 'Already registered'
    else
      new_cron = current_cron.chomp + "\n" + cron_line + "\n"
      IO.popen('crontab -', 'w') { |io| io.write(new_cron) }
      puts "Registered cron job: #{cron_line}"
    end

    puts "\n=== Install completed ==="
    Rails.logger.info '[redmine_auto_close] Installation completed'
  end

  desc 'プラグインのアンインストール（cron解除 + DBロールバック）'
  task uninstall: :environment do
    puts '=== redmine_auto_close uninstall ==='

    # 1. cron解除
    puts "\n[1/2] Removing cron job..."
    current_cron = `crontab -l 2>/dev/null` rescue ''
    new_cron = current_cron.lines.reject { |line| line.include?('redmine_auto_close:check_expired') }.join
    IO.popen('crontab -', 'w') { |io| io.write(new_cron) }
    puts 'Cron job removed'

    # 2. DBロールバック
    puts "\n[2/2] Rolling back DB migration..."
    ENV['NAME'] = 'redmine_auto_close'
    ENV['VERSION'] = '0'
    Rake::Task['redmine:plugins:migrate'].reenable
    Rake::Task['redmine:plugins:migrate'].invoke
    puts 'Done'

    puts "\n=== Uninstall completed ==="
    puts '* Please manually delete the plugins/redmine_auto_close folder'
    Rails.logger.info '[redmine_auto_close] Uninstallation completed'
  end
end
