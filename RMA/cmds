# Run a Job on the Slurm Controller

Submit a batch script (`simplenodestate.sh`) that reports node state using `sbatch`.

## 1. Create the script

```bash
nano simplenodestate.sh
```

Paste this:

```bash
#!/bin/bash
#SBATCH --job-name=simplenodestate
#SBATCH --output=simplenodestate_%j.out
#SBATCH --error=simplenodestate_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:02:00

echo "Job ID      : $SLURM_JOB_ID"
echo "Running on  : $(hostname)"
echo "Date        : $(date)"
echo "--- Node state ---"
sinfo -N -l
```

Save and exit nano: `Ctrl+O`, `Enter`, `Ctrl+X`.

## 2. Submit the job

```bash
sbatch simplenodestate.sh
```

Expected output:

```
Submitted batch job 12
```

## 3. Check the job

```bash
squeue
```

```bash
scontrol show job 12
```

## 4. View the result On Compute Node

```bash
cat simplenodestate_12.out
```

Replace `12` with your job ID.

## Useful commands

| Command | Purpose |
|---|---|
| `sbatch script.sh` | Submit a batch job |
| `squeue` | List queued and running jobs |
| `squeue -u $USER` | Show only your jobs |
| `scancel <jobid>` | Cancel a job |
| `sinfo` | Show partition and node state |
| `sinfo -N -l` | Per-node detailed state |
| `scontrol show node` | Full node details |

## Troubleshooting

- **`sbatch: command not found`**: Slurm is not installed or not in `PATH` on this machine.
- **Job stuck in `PD` (pending)**: run `squeue -j <jobid> -o "%R"` to see the reason.
- **Nodes show `down` or `drain`**: check `sinfo -R` for the reason, then resume with:
  ```bash
  sudo scontrol update nodename=<node> state=resume
  ```
- **`Permission denied` on submit**: not needed to `chmod +x`; `sbatch` reads the script directly.
