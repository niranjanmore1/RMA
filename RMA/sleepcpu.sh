#!/bin/bash
#SBATCH --job-name=sleepcpu
#SBATCH --output=/tmp/cpu.txt
#SBATCH --nodelist=Compute
#SBATCH --cpus-per-task=1
#SBATCH --time=00:00:05
#SBATCH --mem=1G

echo "CPU Test"
echo "Sleeping for 10 seconds..."
sleep 10

echo "Running CPU load for 5 seconds..."
timeout 5 sh -c 'while :; do :; done'
echo "CPU done   : $(date +%T)"

echo "End        : $(date +%T)"
