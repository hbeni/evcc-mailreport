#!/bin/bash
#
# Send report about EVCC charging per mail
#
# @author B. Hallinger, 2026
# @license GPLv3
#
# Note: to run this, wget, sed, bc and mailx is needed:
#       `apt install mailutils dma`
# Use `-h` parameter to get help and usage info.
#

url="localhost:7070"
date_offset="last month"    # date command syntax: "this month", "last month", ...
mailto="mandatory"
lang="en"
verbose=0
nomail=0
vehicle=".*"
report="month"
LANG=C   # to ensure basic unified formatting for floating point numbers

for needed_prog in sed bc awk cut paste wget mailx /usr/sbin/sendmail; do 
        command -v "$needed_prog" > /dev/null
        [[ $? -gt 0 ]] && echo "unmet dependency: i really need '$needed_prog'!" >&2 && exit 1
done


usage() {
    echo "Usage: $0 (-m <mail>|-n) [-u <url> ] [-d <date offset>] [-l <lang>] [-g <vehicle>] [-v] [-h]" 1>&2;
    echo "  -m <mail>        is something like 'john.doe@example.org'",
    echo "  -n               or: dont actually send mail (useful if you just want to print results)" 1>&2;
    echo "  -u <url>         is hostname[:port]  (default: $url)" 1>&2;
    echo "  -d <date offset> something linux 'date' command understands (like 'last month')" 1>&2;
    echo "                   This selects the moment in time the report should refer to, " 1>&2;
    echo "                   dont confuse with -r! (default: '$date_offset')" 1>&2;
    echo "  -r <type>        Timeframe for the report for 'all', 'year', 'month' (default: month)" 1>&2;
    echo "                   (relative to -d; default: '$report')!" 1>&2;
    echo "  -l <lang>        is ISO code like 'en' or 'de' (default: $lang)" 1>&2;
    echo "  -g <vehicle>     filter for vehicle name, grep extended regex (like 'blue|red')" 1>&2;
    echo "  -v               makes the program tell what it does" 1>&2;
    echo "" 1>&2;
    echo "Example: \`$0 -m test@example.com -d 'last month' -r month\`" 1>&2;
    echo "          will generate monthly report for last month and send it to the mail adress" 1>&2;
    exit 1;
}

cleantmp() {
        [[ $verbose == 1 ]] && echo "cleanup /tmp-evcc-report*"
        rm /tmp/evcc-report*
}

while getopts "m:u:d:l:g:r:nvh" o; do
    case "${o}" in
        m)
            mailto=${OPTARG}
            ;;
        u)
            url=${OPTARG}
            ;;
        d)
            date_offset=${OPTARG}
            ;;
        l)
            lang=${OPTARG}
            ;;
        g)
            [[ ${OPTARG} == "*" ]] && OPTARG=".*"
            vehicle=${OPTARG}
            ;;
        r)
            [[ ! ${OPTARG} =~ ^(all|year|month)$ ]] && echo "-r needs to be 'all', 'year' or 'month'" && exit 2
            report=${OPTARG}
            ;;
        n)
            nomail=1
            ;;
        v)
            verbose=1
            ;;
        h|*)
            echo "unknown parameter '${o}!'"
            usage
            exit
            ;;
    esac
done
shift $((OPTIND-1))

[[ "$mailto" = "mandatory" && "$nomail" = 0 ]] && echo "-m or -n is mandatory!" && usage && exit 2;

hostname=$(echo -n "$url" | cut -f 1 -d ":")
port=$(echo -n "$url" | cut -s -f 2 -d ":")
[[ -z "$port" ]] && port="7070"

year=$(date -d "$date_offset" +%Y)
month=$(date -d "$date_offset" +%m)
fetchurl="http://${hostname}:${port}/api/sessions?format=csv&lang=$lang"
[[ $report == "year" ]]  && fetchurl="${fetchurl}&year=$year"
[[ $report == "month" ]] && fetchurl="${fetchurl}&year=$year&month=$month"
[[ $verbose -eq 1 ]] && echo "fetchurl='$fetchurl'"

# Fetch report and do some calculations
filename="evcc-report-${hostname}-${year}-${month}.csv"
file="/tmp/$filename"
wget --quiet -O "/tmp/evcc-report-fetchresult.tmp" "$fetchurl"
fetchresult=$?
[[ $verbose == 1 ]] && echo "fetch result: $fetchresult; file=$file"
[[ $fetchresult -gt 0 ]] && echo "fetch error $fetchresult while retrieving $fetchurl!" >&2 && cleantmp && exit 2;
sed -i '/;;;;;/d' "/tmp/evcc-report-fetchresult.tmp"
head -n1  /tmp/evcc-report-fetchresult.tmp > $file.header
tail -n+2 /tmp/evcc-report-fetchresult.tmp | grep -i -E ",(${vehicle})," > $file.content
cat $file.header $file.content > $file
[[ $verbose == 1 ]] && echo "------- File -------" && cat /tmp/evcc-report-fetchresult.tmp && echo "------- eof -------"


loaded_energy=$(cut -d, -f9 $file |tail +2 | paste -sd+ - | LANG=C bc -l)
first_energy=$(cut -d, -f9 $file |tail -1)
last_km=$(cut -d, -f6 $file |head -n2 |tail -n1)
first_km=$(cut -d, -f6 $file |tail -n1)
price=$(cut -d, -f15 $file |tail +2 | paste -sd+ - | LANG=C bc -l)
solarpart=$(cut -d, -f14 $file | tail +2 | awk '{w++; wx+=$1} END{print wx/w}')
solarkwh=$(echo "$solarpart / 100 * $loaded_energy" | LANG=C bc -l)
gridpart=$(echo "( 100 - $solarpart )" | LANG=C bc -l)
gridkwh=$(echo "( 100 - $solarpart ) / 100 * $loaded_energy" | LANG=C bc -l)
average=$(echo "$price / $loaded_energy" | LANG=C bc -l)
[[ -n "$first_km" ]] && [[ -n "$last_km" ]] && mileage=$(LANG=C echo "(($loaded_energy-$first_energy) / ($last_km - $first_km) * 100)" |bc -l)

# Overwrite with originally fetched file for mailing
mv /tmp/evcc-report-fetchresult.tmp "$file"

[[ $vehicle == ".*" ]] && vehicle="all"
timeframe="${month}/${year}"
[[ $report == "all" ]]  && timeframe="alltime"
[[ $report == "year" ]] && timeframe="$year"
body="EVCC report ${timeframe} ${vehicle}@${hostname}\n"
body="${body}--------------------------------------------\n\n"
body="${body}Energy:  $loaded_energy kWh\n"
body="${body}  Solar: $(printf '%.2f' $solarpart) % ($(printf '%.2f' $solarkwh) kWh)\n"
body="${body}  Grid:  $(printf '%.2f' $gridpart) % ($(printf '%.2f' $gridkwh) kWh)\n"
body="${body}Price:   $(printf '%0.2f' $price) €\n"
body="${body}Average: $(printf '%.3f' $average) €/kWh\n"
[[ -n "$mileage" ]] && body="${body}Mileage: $(($last_km - $first_km)) km ($(printf '%.2f' $mileage) kWh/100km)\n"

if [[ $nomail -eq 0 ]]; then
  subject="EVCC report: ${vehicle}@${hostname} ${timeframe}"
  echo -e "$body" | mailx -s "$subject" -A "$file" "$mailto"
  mailresult=$?
  [[ $verbose == 1 ]] && echo "mail send result=$mailresult"
  [[ $mailresult -gt 0 ]] && echo "mail send error: $mailresult"
else
  [[ $verbose == 1 ]] && echo "no mail sent, -n in effect!"
  echo -e "$body"
fi


cleantmp
[[ $verbose == 1 ]] && echo "all done."
exit 0
