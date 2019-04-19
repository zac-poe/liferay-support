#!/bin/bash
#
# This script performs thread dumps at intervals for a Liferay JVM. It can be used to help analyze performance issues.
#

which jstack > /dev/null
if [[ $? -ne 0 ]]; then
    echo "jstack not found! This utility is a requirement to run this script, please ensure it is properly added to your path."
    exit 1
fi

# defaults
output_prefix="$(echo "$(basename "$0")" | sed 's/\..*$//')-$(date '+%s')"
output_extension='.txt'
dumps=10
webserver='tomcat'
liferay_home="$(pwd)"
output_dir="$(pwd)"
wait=30

usage() {
    echo "Usage: $(basename "$0") [-n number-dumps] [-b between] [-o output] [-w webserver] [-l liferay] [-z]"
    echo -e "\nOptions:"
    echo -e "\t-n {number-of-thread-dumps}"
    echo -e "\t\tOverride the default ${dumps} number of thread dumps to perform."
    echo -e "\n\t-b {seconds-between-thread-dumps}"
    echo -e "\t\tOverride the default ${wait} seconds to wait between thread dumps."
    echo -e "\n\t-o {output-path}"
    echo -e "\t\tOverride the default '$output_dir' output thread dump file path."
    echo -e "\n\t-w {webserver-pattern}"
    echo -e "\t\tOverride the default '${webserver}' webserver pattern to check for."
    echo -e "\n\t-l {liferay-bundle-directory}"
    echo -e "\t\tOverride the default Liferay directory of: ${liferay_home}"
    echo -e "\n\t-z"
    echo -e "\t\tZip thread dump files."
    exit 1
}

while getopts "n:b:o:w:l:z" opt; do
    case "$opt" in
        n)
            if [[ $(echo "$OPTARG" | grep -c '^[0-9]\+$') -le 0 ]]; then
                echo -e "ERROR: provided number-dumps is not a numeric value!\n"
                usage
            else
                dumps="$OPTARG"
            fi
        ;;
        b)
            if [[ $(echo "$OPTARG" | grep -c '^[0-9]\+$') -le 0 ]]; then
                echo -e "ERROR: provided between is not a numeric value!\n"
                usage
            else
                wait="$OPTARG"
            fi
        ;;
        o)
            if [[ ! -d "$OPTARG" ]]; then
                echo -e "ERROR: provided output directory was not found!\n"
                usage
            else
                output_dir="$OPTARG"
            fi
        ;;
        w)
            webserver="$OPTARG"
        ;;
        l)
            if [[ ! -d "$OPTARG" ]]; then
                echo -e "ERROR: provided Liferay directory was not found!\n"
                usage
            else
                liferay_home="$OPTARG"
            fi
        ;;
        z)
            zip_files=1
        ;;
        *)
            usage
        ;;
    esac
done
OPTIND=1

# prevent passing ignored args
if [[ ${#1} -gt 0 && $(printf -- "$1" | grep -c '^-') -le 0 ]]; then
    usage
fi

webserver_dir="$(find "$liferay_home" -type d -name "${webserver}*" -maxdepth 1)"
if [[ ${#webserver_dir} -le 0 ]]; then
    echo "Webserver directory not found! Are the Liferay home '$liferay_home' and webserver '$webserver' correct?"
    exit 1
fi

pid="$(ps -ef | grep -v 'grep' | grep -i "$webserver_dir" | awk '{print $2}')"
if [[ ${#pid} -le 0 ]]; then
    echo "Liferay at '$liferay_home' is not running!"
    exit 1
fi

i=0
while [[ "$i" -lt "$dumps" ]]; do
    output="$output_dir/$(printf "${output_prefix}-%02d${output_extension}" "$i")"

    echo "Performing thread dump $(($i+1)) of $dumps"
    jstack "$pid" > "$output"

    echo -e "Sleeping $wait seconds before next thread dump...\n"
    sleep "$wait"
    let i=$i+1
done

if [[ "$zip_files" -gt 0 ]]; then
    cd "$output_dir"
    archive="${output_prefix}.tar.gz"
    tar -czf "$archive" "${output_prefix}"*"${output_extension}"
    rm "${output_prefix}"*"${output_extension}"
    echo "Thread dump archive created at $output_dir/$archive"
    echo "Archive contents:"
    tar -tzf "$archive" | sed 's/^/     /'
else
    echo "Thread dumps available in $output_dir as ${output_prefix}-*${output_extension} files"
fi
