#!/bin/bash

#change the ip target for the test
ip=$2
sed "s/placeholderIP/$ip/" $1 > updatedTest.xml
echo "Changed IP"

#run load tests
tsung -n -f updatedTest.xml start > tsung_run_output.txt
echo "Ran Load Tests"

#grab output dir and generate logs
dir=$(cat tsung_run_output.txt | grep -o -P "(\/home\/ec2-user\/.tsung\/log\/[0-9-]*)")
echo "$dir"
cd $dir
tsung_stats.pl
