#! /bin/bash

# Variables
curr_dir="$(pwd)"
dumpfile_name="tmp"
trace_tmp="$curr_dir/tmp"

# Array of pid
pids=(`cat db2trc.flw | grep -i 'tid =' | sort -n -k3 | awk '{ a[$3]++ } END { for (b in a) { print b } }'`)
tids=(`cat db2trc.flw | grep -i 'tid =' | sort -n -k3 | awk ' {printf $3"-"$6"\n"}'`)
num_sort_per=(`cat db2trc.perfrep |  awk ' /Node : /   {printf NR"\n"}' | sort -n `)
num_sort_tfile=(`cat db2trc.flw |  awk ' /pid = /   {printf NR"\n"}' | sort -n `)
PT_row=(`cat db2trc.flw | grep -i 'tid =' | sort -n -k3 | awk '{printf $0"\n"}'`) 

# Folder creation.  
if [[ ! -e $dumpfile_name ]]; then
    mkdir $dumpfile_name
elif [[ ! -d $dumpfile_name ]]; then
    echo "$dumpfile_name already exists but is not a directory" 1>&2
fi
working_dir="$trace_tmp/$dumpfile_name"

# returns higer line number.
function get_higher () {
    temp_num=$1
    n_max=1
    
    cat db2trc.perfrep |  awk ' /Node : /   {printf NR"\n"}' | sort -n  |  while read line_temp 
    do
        set $line_temp
        if [ $line_temp -gt "$temp_num" ]; then
            n_max=$line_temp
            echo $n_max
            break
        #else echo "99999999"
        fi
    done
}
# returns higer line number.
function get_higher_trc () {
    temp_num=$1
    n_max=1
    
    #echo "${num_sort_tfile[*]}" |  while read line_temp2
    cat db2trc.flw |  awk ' /pid = /   {printf NR"\n"}' | sort -n  | while read line_temp2 
    do
        set $line_temp2
        if [ $line_temp2 -gt "$temp_num" ]; then
            n_max=$line_temp2
            echo $n_max
            break
        #else echo "99999999"
        fi
    done
}
# function to deatch data from trace perfrep.
function fun_fetch_data_perfrep () {
    arg_pid=$1
    arg_tid=$2
    arg_line=$3

    cat db2trc.perfrep |  awk ' /Node : /   {printf NR" "$0"\n"}'| while read line_2
    do
        set $line_2
        if [[ $line_2 =~ .*$arg_tid* ]] && [[ $line_2 =~ .*$arg_pid* ]]
            then
                for i in "${num_sort_per[@]}"
                    do
                        if [[ "$i" -eq "$1" ]] ; then
                        next_high=$(get_higher "$1")
                        #echo -e "\tFound $i, $1, $next_high"
                        cat db2trc.perfrep | awk -v start=$i -v end=$next_high 'NR >= start && NR <= end-1' > $working_dir/pid_$arg_pid/tid_perfrep_$arg_tid.out
                    fi
                done
        fi
    done
}
# Creating thread trc files
function fun_create_tidfile () {
    arg_pid=$1
    arg_tid=$2
    arg_line=$3

    cat db2trc.flw |  awk ' /pid = /   {printf NR" "$0"\n"}'| while read line_2
    do
        set $line_2
        if [[ $line_2 =~ .*$arg_tid* ]] && [[ $line_2 =~ .*$arg_pid* ]]
            then
                for i in "${num_sort_tfile[@]}"
                    do
                        if [[ "$i" -eq "$1" ]] ; then
                        next_high=$(get_higher_trc "$1")
                        #echo -e "\tFound $i, $1, $next_high"
                        echo -e "\tCreating tid file : $arg_tid"
                        cat db2trc.flw | awk -v start=$i -v end=$next_high 'NR >= start && NR <= end-1' > $working_dir/pid_$arg_pid/tid_$arg_tid.trc
                    fi
                done
        fi
    done
}
# Make_thread folders.
function fun_mkthd () {
    pid_tmp=$1
    # echo -e "From function : $pid_tmp "
    cat db2trc.flw | grep -i 'tid =' | awk '{printf $0"\n"}' | while read line
        do 
            case "$line" in
                *$pid_tmp*)
                        set $line
                        # echo -e "line: $line"
                        fun_fetch_data_perfrep $pid_tmp $6 $line
                        fun_create_tidfile $pid_tmp $6 $line
                    ;;
            esac 
        done
}

function start_program () {
    for i in "${pids[@]}"
    do
        echo -e "Creating pid folder : $i"
        mkdir -p $working_dir/pid_$i
        fun_mkthd $i
    done
    echo -e "\nworking directory: $working_dir \n"
}


## Starting of Program----------

# Executing start function:  
start_program 