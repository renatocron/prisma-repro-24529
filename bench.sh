#!/bin/bash

# Ensure two commands are passed as arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <command1> <command2>"
    exit 1
fi

# Commands to execute
CMD1=$1
CMD2=$2

# Log file
LOGFILE="execution_times.csv"

# Get Prisma version information
PRISMA_VERSION=$(npx prisma -v | grep 'prisma ' | awk '{print $3}')

# Check if log file exists, if not create it and add headers
if [ ! -f "$LOGFILE" ]; then
    echo "Timestamp,Command,Execution Time (s),Prisma Version" > "$LOGFILE"
fi

# Function to execute a command and log the execution time
execute_and_log() {
    local CMD=$1
    local START_TIME
    local END_TIME
    local EXECUTION_TIME

    START_TIME=$(date +%s.%N)
    eval "$CMD"
    END_TIME=$(date +%s.%N)
    EXECUTION_TIME=$(echo "$END_TIME - $START_TIME" | bc)

    echo "$(date +%Y-%m-%d\ %H:%M:%S),$CMD,$EXECUTION_TIME,$PRISMA_VERSION" >> "$LOGFILE"
}

# Infinite loop to execute the commands
while true; do
    execute_and_log "$CMD1"
    execute_and_log "$CMD2"
done
