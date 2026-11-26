#!/bin/bash
#!/bin/bash
#SBATCH --job-name=hello_job
#SBATCH --output=/tmp/helloout_%j.txt
#SBATCH --nodelist=Compute
echo "Hello from Slurm cluster!"
echo "Ran on host: $(hostname)"
echo "Hello from Slurm cluster!"
