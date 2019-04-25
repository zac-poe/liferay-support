#!/bin/bash
#
# Provides restart capability for Liferay since Liferay shutdown script is asynchronous and Liferay can hang.
#
# Script will try to elegantly shutdown (if running) and restart Liferay. If the shutdown does not complete,
# it will prompt the user to forcefully kill the webserver.
#

cd "$(dirname "$0")"

# defaults
max_wait_seconds=7
webserver='tomcat'
liferay_home="$(pwd)"
kill_prompt_timeout=5

usage() {
    echo "Usage: $(basename "$0") [-s seconds] [-w webserver] [-l liferay]"
    echo -e "\nOptions:"
    echo -e "\t-s {seconds-before-kill-prompt}"
    echo -e "\t\tOverride the default ${max_wait_seconds} seconds to wait before prompting to kill the webserver."
    echo -e "\n\t-w {webserver-pattern}"
    echo -e "\t\tOverride the default '${webserver}' webserver pattern to check for."
    echo -e "\n\t-l {liferay-bundle-directory}"
    echo -e "\t\tOverride the default Liferay directory of: ${liferay_home}"
    exit 1
}

while getopts "s:w:l:" opt; do
    case "$opt" in
        s)
            if [[ $(echo "$OPTARG" | grep -c '^[0-9]\+$') -le 0 ]]; then
                echo -e "ERROR: provided seconds is not a numeric value!\n"
                usage
            else
                max_wait_seconds="$OPTARG"
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

webserver_dir="$(find "$(find "$liferay_home" -type d -name "${webserver}*" -maxdepth 1)" -type d -name 'bin' -maxdepth 1 2>/dev/null)"
if [[ ${#webserver_dir} -le 0 ]]; then
    echo "Webserver directory not found! Are the Liferay home '$liferay_home' and webserver '$webserver' correct?"
    exit 1
fi

get_liferay_process() {
    ps -ef | grep -v 'grep' | grep -i "$webserver_dir"
}

if [[ $(get_liferay_process | wc -l) -gt 0 ]]; then
    "${webserver_dir}/shutdown.sh"
    if [[ $? -ne 0 ]]; then
        echo 'Shutdown script not found'
        exit 1
    fi

    printf "\nWaiting for shutdown to complete..."
    i=1
    while [[ $(get_liferay_process | wc -l) -gt 0 ]]; do
        sleep 1
        printf '.'

        if [[ $i -gt $max_wait_seconds ]]; then
            echo -e "\nWebserver has not yet shutdown gracefully"
            printf "Kill ${webserver}? (automatically continuing to wait in $kill_prompt_timeout seconds) [Ny]: "
            read -t "$kill_prompt_timeout" response
            if [[ $? -ne 0 ]]; then
                echo ''
            fi
            if [[ $(echo "$response" | grep -ci '^y') -gt 0 ]]; then
                pid="$(get_liferay_process | awk '{print $2}')"
                if [[ ${#pid} -gt 0 ]]; then
                    kill -9 $pid
                    printf "\nWebserver has been forcefully killed"
                else
                    echo -e "\nElegant shutdown of Liferay was already successful"
                fi
            else
                printf "\nContinuing to wait for shutdown to complete..."
                i=0
            fi
        fi

        let i=i+1
    done
    echo -e "\n"
fi

"${webserver_dir}/startup.sh"
if [[ $? -ne 0 ]]; then
    echo 'Startup script not found'
    exit 1
fi
