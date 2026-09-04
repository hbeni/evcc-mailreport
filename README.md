# evcc-mailreport

This bash script can generate reports for EVCC (https://github.com/evcc-io/evcc/) and mail them to you.
It uses EVCCs REST API to generate the report.

## Usage:
```shell
beni@cassiopeia:~$ sendEVCCReport.sh -h
Usage: sendEVCCReport.sh (-m <mail>|-n) [-u <url> ] [-d <date offset>] [-l <lang>] [-g <vehicle>] [-v] [-h]
  -m <mail>        is something like 'john.doe@example.org'
  -n               dont actually send mail (useful if you just want to print results)
  -u <url>         is hostname[:port]  (default: localhost:7070)
  -d <date offset> something linux 'date' command understands (like 'last month')
                   This selects the moment in time the report should refer to, 
                   dont confuse with -r! (default: 'last month')
  -r <type>        Timeframe for the report for 'all', 'year', 'month' (default: month)
                   (relative to -d; default: 'month')!
  -l <lang>        is ISO code like 'en' or 'de' (default: en)
  -g <vehicle>     filter for vehicle name, grep extended regex (like 'blue|red')
  -v               makes the program tell what it does

Example: `sendEVCCReport.sh -m test@example.com -d 'last month' -r month`
          will generate monthly report for last month and send it to the mail adress

```

## Example report:
```
EVCC report mm/yyyy car@localhost
--------------------------------------------

Energy:  xxx.xxx kWh
  Solar: xx.xx % (xx.xx kWh)
  Grid:  xx.xx % (xx.xx kWh)
Price:   xx.xx €
Average: x.xxx €/kWh
Mileage: xxx km (xx.xx kWh/100km)
```
