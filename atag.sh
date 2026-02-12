#!/bin/bash

atag() {
    local IS_GIT_FOLDER=$(git rev-parse --git-dir 2> /dev/null)

    if [ -z "$IS_GIT_FOLDER" ]; then
        printf "\033[91m[ERROR] Not in .git folder !\033[0m\n"
        return 1
    fi

    local DATE_TAG=$(date +"%d-%m-%Y_%Hh%Mm%S")
    local TAG_NAME="atag"
    local DEFAULT_COMMIT_MSG="chore: Auto Commit goes brrr"

    local PRINT_CMDS=0
    local ASK_COMMIT=0
    local CALL_ADD=1
    local SKIP_ASK=0
    local SKIP_TAG=0

    local COMMANDS=()
    local CMD_STARTS=()

    add_cmd() {
        CMD_STARTS+=("${#COMMANDS[@]}")
        COMMANDS+=("$@")
    }

    print_cmds() {
        local i j start end
    
        for ((i=0; i<${#CMD_STARTS[@]}; i++)); do
            start=${CMD_STARTS[i]}
            end=${CMD_STARTS[i+1]:-${#COMMANDS[@]}}
    
            printf "  \033[95m$\033[0m "
            for ((j=start; j<end; j++)); do
                printf "%q " "${COMMANDS[j]}"
            done
            printf "\n"
        done
    }

    run_cmds() {
        local i start end
    
        for ((i=0; i<${#CMD_STARTS[@]}; i++)); do
            start=${CMD_STARTS[i]}
            end=${CMD_STARTS[i+1]:-${#COMMANDS[@]}}
    
            "${COMMANDS[@]:start:end-start}" || return $?
        done
    }

    print_bool() {
        if [ "$1" = "1" ]; then
            printf "\033[42m YES \033[0m"
        else
            printf "\033[41m NO  \033[0m"
        fi
    }

    print_info() {
        if [ "$PRINT_CMDS" = "1" ]; then
            printf "\n\033[94m[INFO]\033[0m Commands to be executed:\n"
            print_cmds
        fi
        
        printf "\n"
        printf "\033[94m[INFO]\033[0m Call Add ?    "
        print_bool "$CALL_ADD"; printf "\n"

        printf "\033[94m[INFO]\033[0m Ask Commit ?  "
        print_bool "$ASK_COMMIT"; printf "\n"

        if [ "$ASK_COMMIT" = "0" ]; then
            printf "\033[94m[INFO]\033[0m Commit MSG:   '\033[92m%s\033[0m'\n" "$DEFAULT_COMMIT_MSG"
        fi

        if [ "$SKIP_TAG" = "0" ]; then
            printf "\033[94m[INFO]\033[0m Will use tag: '\033[92m%s\033[0m'\n" "$FULL_TAG"
        else
            printf "\033[94m[INFO]\033[0m \033[93mWill not tag\033[0m\n"
        fi
    }

    print_help() {
        printf "Usage:\tatag [-c msg] [-C] [-n] [-p] [-y] [-t] [-h]\n"
        printf "\tAutomatically adds, commits, tags and pushes files.\n\n"
        printf "\tOptions:\n"
        printf "\t  \033[94m-c | --commit <msg>\033[0m\tUse a custom commit message\n"
        printf "\t  \033[94m-C | --custom-commit\033[0m\tCalls the commit message window\n"
        printf "\t  \033[94m-n | --not-add\033[0m      \tDo not \`git add .\`\n"
        printf "\t  \033[94m-p | --print\033[0m        \tPrints the commands list before execution\n"
        printf "\t  \033[94m-y | --yes\033[0m          \tSkips the confirmation prompt\n"
        printf "\t  \033[94m-t | --no-tag\033[0m       \tDo not tag\n"
        printf "\t  \033[94m-h | --help\033[0m         \tPrints this help info\n"
    }

    # Arg parser
    local POS_ARGS=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -c|--commit)
                DEFAULT_COMMIT_MSG="$2"
                shift; shift
                ;;
            -C|--custom-commit)
                ASK_COMMIT=1
                shift
                ;;
            -n|--not-add)
                CALL_ADD=0
                shift
                ;;
            -p|--print)
                PRINT_CMDS=1
                shift
                ;;
            -y|--yes)
                SKIP_ASK=1
                shift
                ;;
            -t|--no-tag)
                SKIP_TAG=1
                shift
                ;;
            -h|--help)
                print_help
                return 0
                ;;
            -*|--*)
                printf "\033[91m[ERROR] Unknown argument $1\033[0m\n"
                return 1
                ;;
            *)
                POS_ARGS+=("$1")
                shift
                ;;
        esac
    done

    set -- "${POS_ARGS[@]}" # restore the pos args

    if [ "$#" -gt 1 ]; then
        printf "\033[91m[ERROR] Only one tag should be provided\033[0m\n"
        exit 1
    fi

    # Handle tag ending with "-" or "-*"
    if [ "$#" = 1 ]; then
        TAG_NAME="$1"
        END_CHAR="${TAG_NAME: -1}"

        if [ "$END_CHAR" = "*" ]; then
            TAG_NAME="${TAG_NAME::-2}"
        elif [ "$END_CHAR" = "-" ]; then
            TAG_NAME="${TAG_NAME::-1}"
        fi
    fi

    local FULL_TAG="$TAG_NAME-$DATE_TAG"

    # printf "\033[94m[INFO]\033[0m Will use tag: '\033[92m$FULL_TAG\033[0m'\n"

    # TODO: Add everything to a string and ask before execution

    if [ "$CALL_ADD" = "1" ]; then
        add_cmd git add .
    fi

    if [ "$ASK_COMMIT" = "1" ]; then
        add_cmd git commit 
    else
        # I guess if someone wants to break everything with a weird tag...
        # add_cmd bash -c 'printf "%s\n" "$1" | git commit --file=-' _ "$DEFAULT_COMMIT_MSG"
        add_cmd git commit -m "$DEFAULT_COMMIT_MSG" 
    fi

    if [ "$SKIP_TAG" = "0" ]; then
        add_cmd git tag -ma "$FULL_TAG"
        add_cmd git push --follow-tags
    else
        add_cmd git push
    fi

    printf "\n\033[94m[INFO]\033[0m Files to be committed:\n"
    local FILES=$(git status --short)
    if [ -z "$FILES" ]; then
        printf "\033[93m[WARN] No files added !\033[0m\n"
    fi

    print_info

    if [ "$SKIP_ASK" = "0" ]; then
        printf "\n\033[93m[CONFIRM]\033[0m Execute these commands? [\033[92my\033[0m/\033[91mN\033[0m] "
        read -r reply

        case "$reply" in
            y|Y|yes|YES) ;;
            *)
                printf "\033[91m[ABORTED] Nothing was executed.\033[0m\n"
                return 1
                ;;
        esac
    fi

    printf "\n\033[94m[INFO]\033[0m Executing...\n"
    run_cmds
}
