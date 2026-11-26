#!/bin/bash
#SBATCH --job-name=sleepjob
#SBATCH --time=00:10:00
#SBATCH --cpus-per-task=1
#SBATCH --nodelist=Compute
#SBATCH --output=/tmp/sleepjob

for i in {1..1000}
do
echo "Testing For Loop"
sleep 5
done
