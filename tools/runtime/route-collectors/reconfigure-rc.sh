#! /usr/bin/env bash

KEY="your-ixp-manager-api-key"
URL="http://ixp.example.com/api/v4/router/gen-config"
URL_DONE="http://ixp.example.com/api/v4/router/updated"
ETCPATH="/usr/local/etc/bird"
RUNPATH="/var/run/bird"
LOGPATH="/var/log/bird"
BIN="/usr/sbin/bird"

mkdir -p $ETCPATH
mkdir -p $LOGPATH
mkdir -p $RUNPATH

if [[ -n $1 && $1 = '--quiet' ]]; then
    export QUIET=1
else
    export QUIET=0
    echo -en "\Route Collector BGPd Lisenters\n==============================\n\n"
    echo -e "Verbose mode enabled. Issue --quiet for non-verbose mode (--debug also available)\n"
fi

if [[ -n $1 && $1 = '--debug' ]]; then
    export QUIET=1
    export DEBUG=1
else
    export DEBUG=0
fi

function log {
    if [[ $QUIET -eq 0 && $DEBUG -eq 0 ]]; then
        echo -en $1
    fi
}

for handle in handle1-ipv4 handle1-ipv6; do

    if [[ $handle == *ipv6 ]]; then
        PROTOCOL="6"
    else
        PROTOCOL=""
    fi

    log  "Instance for ${handle}:\tConfig: "

    cmd="curl --fail -s -H \"X-IXP-Manager-API-Key: ${KEY}\" ${URL}/${handle} >${ETCPATH}/bird-${handle}.conf"

    if [[ $DEBUG -eq 1 ]]; then echo $cmd; fi
    eval $cmd

    if [[ $? -eq 0 ]]; then
        log "DONE \tDaemon: "
    else
        log "ERROR\n"
        continue
    fi

    # are we running or do we need to be started?
    cmd="${BIN}c${PROTOCOL} -s ${RUNPATH}/bird-${handle}.ctl configure"
    if [[ $DEBUG -eq 1 ]]; then echo $cmd; fi
    eval $cmd &>/dev/null

    if [[ $? -eq 0 ]]; then
        log "RECONFIGURED \tIXP Manager Updated: "
    else
        cmd="${BIN}${PROTOCOL} -c ${ETCPATH}/bird-${handle}.conf -s ${RUNPATH}/bird-${handle}.ctl"

        if [[ $DEBUG -eq 1 ]]; then echo $cmd; fi
        eval $cmd &>/dev/null

        if [[ $? -eq 0 ]]; then
            log "STARTED \tIXP Manager Updated: "
        else
            log "ERROR\n"
            continue
        fi
    fi

    # tell IXP Manager the router has been updated:
    cmd="curl -s -X POST -H \"X-IXP-Manager-API-Key: ${KEY}\" ${URL_DONE}/${handle} >/dev/null"
    if [[ $DEBUG -eq 1 ]]; then echo $cmd; fi
    eval $cmd

    if [[ $? -eq 0 ]]; then
        log "DONE"
    else
        log "ERROR\n"
        continue
    fi

    log "\n"
done

log "\n"
