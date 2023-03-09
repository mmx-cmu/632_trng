#!/bin/bash

cd ../NIST\ Test\ Suite/

echo pwd

path_start="../nist_runs/"
path_user=$1
path_final="$path_start$path_user" 

printf '0\n%s.bin\n1\n0\n10\n1', $path_final | ./assess 100000

cp experiments/AlgorithmTesting/finalAnalysisReport.txt ../632_trng/report/$path_user.rpt


