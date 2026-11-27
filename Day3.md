nano simpleexampart.sh
#!/bin/bash
#SBATCH --job-name=partjob
#SBATCH --partition=exampart
#SBATCH --output=example.txt

for i in {1..1000000}
do 
	echo $i
sleep 5
done

sbatch simpleexampart.sh
cd
cd /slurmdir/slurm-20.11.9/etc
nano slurm.conf
scp -r /slurmdir/slurm-20.11.9/etc/slurm.conf ubuntu@Compute:/tmp
sudo systemctl restart slurmctld

squeue
sacct
scontrol show job job_id
scontrol show partition partition_name
