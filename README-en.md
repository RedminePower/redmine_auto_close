# redmine_auto_close

> **Tip**: With [redmine_studio_plugin](https://github.com/RedminePower/redmine_studio_plugin), you can manage this feature along with other useful features in one place.
> Also, combined with [Redmine Studio](https://www.redmine-power.com/), you can enjoy an even better Redmine experience.

## Overview

A plugin that automatically closes issues (status change, assignee change, comment addition) based on conditions.
It supports automatic closing of parent issues when all child issues are closed, and periodic closing of expired issues.

For details, see [here](https://github.com/RedminePower/redmine_studio_plugin/blob/master/docs/auto_close-en.md).

## Supported Versions

- Redmine 5.x (tested with 5.1.11)
- Redmine 6.x (tested with 6.1.1)

## Installation

The Redmine installation path varies depending on your environment.
The following instructions use `/var/lib/redmine`.
Please adjust according to your environment.

| Environment | Redmine Path |
|-------------|--------------|
| apt (Debian/Ubuntu) | `/var/lib/redmine` |
| Docker (Official Image) | `/usr/src/redmine` |
| Bitnami | `/opt/bitnami/redmine` |

Run the following commands and restart Redmine.

```bash
cd /var/lib/redmine/plugins
git clone https://github.com/RedminePower/redmine_auto_close.git
cd /var/lib/redmine
bundle exec rake redmine_auto_close:install RAILS_ENV=production
```

The `install` task performs the following:
1. Database migration
2. Cron job registration (runs expired issue check daily at 3:00)

## Uninstallation

Run the following commands and restart Redmine.

```bash
cd /var/lib/redmine
bundle exec rake redmine_auto_close:uninstall RAILS_ENV=production
rm -rf plugins/redmine_auto_close
```

The `uninstall` task performs the following:
1. Remove cron job
2. Database rollback
