# YBP ISBN Harvest

Harvests ISBNs from Sierra ILS to add/remove from YBP/GOBI's "Holdings Load Service"

Internal UNC Libraries documentation: https://internal.lib.unc.edu/wikis/staff/index.php/YBP_Holdings_Load_Service

## Basic usage

```bash
# run a periodic (e.g. biweekly) harvest:
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

## Harvesting holdings data
To generate a routine set of delta add/delete files to be sent to YBP to add/remove from our holdings data:

```bash
# run a periodic (e.g. biweekly) harvest:
rake harvest
```

See [details on the staff wiki](https://internal.lib.unc.edu/wikis/staff/index.php/YBP_Holdings_Load_Service).

## Auditing YBP's holdings data
We can also compare YBP's actual holdings data to what their holdings data should be and generate
delta add/delete files that will fix any discrepancies. This requires asking YBP to send us a report/export of their current holdings data for us. It should look like:
  ```
  ISBN_13|FUND_CODE|CUSTOMER_NUMBER
  2000317722013|MGEOLGG|303099
  ...
  ```

To run the audit:
- with data from ybp as `data/holdings.txt`
- and with data from our last harvest in `data/comprehensive.txt` (its normal place)
- and in a unix environment

```bash
# run an periodic (e.g. yearly) audit
rake audit
```

