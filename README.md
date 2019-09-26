# YBP ISBN Harvest

Harvests ISBNs from Sierra ILS to add/remove from YBP/GOBI's "Holdings Load Service"

Internal UNC Libraries documentation: https://internal.lib.unc.edu/wikis/staff/index.php/YBP_Holdings_Load_Service

## Basic usage

```bash
rake harvest
```

## Setup

* clone repo
* bundle install
* setup Sierra DB credentials (per [sierra_postgres_utilities readme](https://github.com/UNC-Libraries/sierra-postgres-utilities))
* if there is a static list of isbns you want to exclude, copy them to `data/EXCLUDES_gobi.txt`

### If your YBP account HAS existing Holdings Load Service data

* copy most recent comprehensive holdings service isbn list to `data/comprehensive.txt`

### If your YBP account HAS NO existing Holdings Load Service data

* generate a new comprehensive list with `rake new_harvest`
