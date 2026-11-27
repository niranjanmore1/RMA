# Slurm: Submitting a Job to a Custom Partition (`exampart`)

## 1. Create the job script

```bash
nano simpleexampart.sh
```

```bash
#!/bin/bash
#SBATCH --job-name=partjob
#SBATCH --partition=exampart
#SBATCH --output=example.txt

for i in {1..1000000}
do
	echo $i
	sleep 5
done
```

## 2. Submit the job

```bash
sbatch simpleexampart.sh
```

## 3. Edit and distribute `slurm.conf`

```bash
cd
cd /slurmdir/slurm-20.11.9/etc
nano slurm.conf
scp -r /slurmdir/slurm-20.11.9/etc/slurm.conf ubuntu@Compute:/tmp
sudo systemctl restart slurmctld
```

> **Note:** `scp` copies the file to `/tmp` on the `Compute` node. Move it into that node's Slurm `etc` directory (and restart `slurmd` there) for the change to take effect.

## 4. Monitor jobs and partitions

| Command | Purpose |
|---|---|
| `squeue` | Show jobs currently in the queue |
| `sacct` | Show accounting data for jobs |
| `scontrol show job <job_id>` | Detailed info about a specific job |
| `scontrol show partition <partition_name>` | Detailed info about a specific partition |

```bash
squeue
sacct
scontrol show job job_id
scontrol show partition partition_name
```
