# redmine_auto_close

## Features

A plugin that automatically performs actions on tickets based on specific triggers.

**Available Actions:**
- Change status
- Change assignee
- Add comment

### Trigger Types

#### When All Child Tickets Are Closed
Executes actions on the parent ticket when all of its child tickets are closed.

**Characteristics:**
- Compatible with [Redmine Studio](https://www.redmine-power.com/) review feature
  - The review feature creates review request and review issue tickets under a review session ticket
  - Automatically closes the review session ticket when all review requests and issues are closed

**Use Cases:**
- Break down a parent ticket into multiple subtasks, and automatically close the parent when all are completed
- Automatically close a release ticket when all feature additions and bug fixes under it are completed

#### When Expired
Periodically checks tickets that have passed their due date and executes actions on tickets matching the conditions.

**Characteristics:**
- Scheduled execution via cron (daily at 3:00)
  - Execution logs are output to `log/auto_close.log` (see `log/production.log` for details)
  - To run manually:
  ```
  $ bundle exec rake redmine_auto_close:check_expired RAILS_ENV=production
  ```
- Threshold setting to prevent unintended mass updates
- Configurable action user (assignee/author/parent ticket assignee/fixed user)

**Use Cases:**
- Clean up abandoned tickets - Automatically close tickets that remain unaddressed past their due date to keep the ticket list clean
- Escalation on expiration - Change the assignee of expired tickets to a supervisor or administrator to promote action
- Prevent oversight - Add reminder comments to expired tickets to alert stakeholders

## Supported Versions
- Redmine 4.x (tested with 4.2.3)
- Redmine 5.x (tested with 5.1.11)
- Redmine 6.x (tested with 6.1.1)

## Installation
Run the following commands and restart Redmine.

```
$ cd /path/to/redmine/plugins
$ git clone https://github.com/RedminePower/redmine_auto_close.git
$ bundle exec rake redmine_auto_close:install RAILS_ENV=production
```

The `install` task performs the following:
1. Database migration
2. Cron job registration (runs expired ticket check daily at 3:00)

## Upgrade
Run the following commands and restart Redmine.
Existing "Auto Close" settings will be preserved.

```
$ cd /path/to/redmine/plugins/redmine_auto_close
$ git pull
$ bundle exec rake redmine_auto_close:install RAILS_ENV=production
```

## Usage
1. After installing the plugin, "Auto Close" will be added to the administration menu.
![image](https://user-images.githubusercontent.com/87136359/226633071-159626ee-aca0-4724-b651-187ca66de7b2.png)
2. Click "Auto Close" to navigate to the list screen.
![image](https://user-images.githubusercontent.com/87136359/226633407-4cac6c54-d2fe-4d13-95fb-3c60c7ad765a.png)
3. Click "New Auto Close", fill in the fields, and click the "Create" button.
![image](https://github.com/user-attachments/assets/5973718c-a95b-4c38-836f-9bbad8b97e5a)
![image](https://github.com/user-attachments/assets/c8958af1-2a6a-4d52-b907-f96265a3c1f8)
4. When the conditions set in "Trigger" are met, the actions specified in "Action" will be executed.

## Uninstallation

Run the following commands and restart Redmine.

```
$ cd /path/to/redmine
$ bundle exec rake redmine_auto_close:uninstall RAILS_ENV=production
$ rm -rf plugins/redmine_auto_close
```

The `uninstall` task performs the following:
1. Remove cron job
2. Database rollback
