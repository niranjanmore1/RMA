#!/bin/bash
#SBATCH --job-name=backupjob
#SBATCH --partition=shellpart
#SBATCH --time=00:15:00
#SBATCH --output=backup.txt

SRC=/home/ubuntu/slurmassign/data
DEST=/home/ubuntu/slurmassign/backup

mkdir -p "$DEST"
tar -czf "$DEST/backup_$(date +%F_%H%M%S).tar.gz" "$SRC"
echo "Backup finished: $(date)"
