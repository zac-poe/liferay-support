#!/bin/bash
#
# Provides shutdown capability for Liferay to support drop in and sym linking.
#

cd "$(cd "$(dirname "$([[ -h "$0" ]] && readlink "$0" || echo "$0")")" && pwd)"

# defaults
webserver='tomcat'
liferay_home="$(pwd)"

usage() {
    echo "Usage: $(basename "$0") [-w webserver] [-l liferay]"
    echo -e "\nOptions:"
    echo -e "\n\t-w {webserver-pattern}"
    echo -e "\t\tOverride the default '${webserver}' webserver pattern to check for."
    echo -e "\n\t-l {liferay-bundle-directory}"
    echo -e "\t\tOverride the default Liferay directory of: ${liferay_home}"
    exit 1
}

while getopts "w:l:" opt; do
    case "$opt" in
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

"${webserver_dir}/shutdown.sh"
if [[ $? -ne 0 ]]; then
    echo 'Shutdown script not found'
    exit 1
fi
