#!/usr/bin/env sh

set -e

VARNISHLOG="$($(command -v echo) "${VARNISHLOG}" | $(command -v tr) '[:upper:]' '[:lower:]')"

# 16. March 2019
# We parse VARNISHD_OPTS as well as VARNISHD_ADDITIONAL_OPTS in order to don't break existent setups
VARNISHD_FULL_OPTS="${VARNISHD_OPTS} ${VARNISHD_ADDITIONAL_OPTS} ${VARNISHD_DEFAULT_OPTS}"

start_varnishd () {
    FILE="${1}"
    VARNISH_BACKEND="${2}"

    if [ "${VARNISHLOG}" == "true" ]; then
        VARNISHD="$(command -v varnishd)  \
                    ${VARNISHD_FULL_OPTS}"

        VARNISHD_LOG="exec $(command -v varnishlog) \
                    ${VARNISHLOG_OPTS}"
    else
        VARNISHD="exec $(command -v varnishd)  \
                    -F ${VARNISHD_FULL_OPTS}"
    fi

    if [ -n "${FILE}" ]; then
        ${VARNISHD} -f "${FILE}"
    elif [ -n "${VARNISH_BACKEND}" ]; then
        ${VARNISHD} -b "${VARNISH_BACKEND}"
    else
        echo "unable to start varnishd"
        echo "this should not have happened"
        exit 1 # r.i.p.
    fi

    if [ "${VARNISHLOG}" == "true" ]; then
        eval "${VARNISHD_LOG}"
    fi
}

if [ ! -s "${VARNISH_VCL_PATH}" ]; then

    echo "${VARNISH_VCL_PATH}"
    echo "it seems like vcl ist not mounted"
    echo "looking for either a vcl in env \${VARNISH_VCL_CONTENT} or a default backend in \${VARNISH_VCL_BACKEND} ..."

    if [ -z "${VARNISH_VCL_DEFAULT_BACKEND}" ] && [ -z "${VARNISH_VCL_CONTENT}" ]; then
        echo "... neither a default backend or a varnish vcl were provided in env - aborting now"
        exit 1 # r.i.p.
    fi

    if [ -n "${VARNISH_VCL_CONTENT}" ]; then
        echo "... found VCL in environment - starting varnishd with provided vcl content"
        echo "${VARNISH_VCL_CONTENT}" > "${VARNISH_VCL_PATH}"
        unset VARNISH_VCL_DEFAULT_BACKEND
    else
        echo "... found default backend - starting varnishd with builtin vcl and provided backend address"
        unset VARNISH_VCL_PATH
    fi

fi

start_varnishd "${VARNISH_VCL_PATH}" "${VARNISH_VCL_DEFAULT_BACKEND}"