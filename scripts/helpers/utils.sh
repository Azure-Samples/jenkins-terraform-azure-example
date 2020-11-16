#!/bin/bash

##############################################################################
#- function used to create resource names from well known parameters
#- -t Type - resource type ie rg, as, aci
#- -p Prefix - unique prefix ie cse
##############################################################################
function createResourceName() {
    # reset the index for the arguments locally for this function.
    local OPTIND t p
    while getopts ":t:p:" opt; do
        case $opt in
        t) local type=${OPTARG//-/} ;;
        p) local prefix=${OPTARG//-/} ;;
        :)
            echo "Error: -${OPTARG} requires a value" >&2
            exit 1
            ;;
        esac
    done
    shift $((OPTIND - 1))

    # Validation
    if [[ -z $prefix || -z $type ]]; then
        echo "Required parameters are missing"
        exit 1
    fi

    echo "$type-$prefix-jenkins-example"
}

##############################################################################
#- function used to create resource names from well known parameters
#- -t Type - resource type ie rg, as, aci, satf, saaci
#- -p Prefix - unique prefix ie cse
##############################################################################
function createResourceNameNoDashes() {
    # reset the index for the arguments locally for this function.
    local OPTIND t p
    while getopts ":t:p:" opt; do
        case $opt in
        t) local type=${OPTARG//-/} ;;
        p) local prefix=${OPTARG//-/} ;;
        :)
            echo "Error: -${OPTARG} requires a value" >&2
            exit 1
            ;;
        esac
    done
    shift $((OPTIND - 1))

    # Validation
    if [[ -z $prefix || -z $type ]]; then
        echo "Required parameters are missing"
        exit 1
    fi

    echo "${type}${prefix}jenkinsexample"
}