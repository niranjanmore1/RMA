# Slurm Assignment: Simple Batch Jobs

Three minimal Slurm batch scripts (`simplejoba`, `simplejobb`, `simplejobc`) submitted from the controller node.

**Working directory:** `~/slurmassign` (on `ubuntu@Controller`)

---

## 1. Job Scripts

### simplejoba

```bash
#!/bin/bash
#SBATCH --job-name=simplejoba
#SBATCH --output=jobA.out
echo "Running at A"
sleep 20
```

### simplejobb

```bash
#!/bin/bash
#SBATCH --job-name=simplejobb
#SBATCH --output=jobB.out
echo "Running at B"
sleep 20
```

### simplejobc

```bash
#!/bin/bash
#SBATCH --job-name=simplejobc
#SBATCH --output=jobC.out
echo "Running at C"
sleep 20
```

### Directive reference

| Directive | Meaning |
|---|---|
| `#SBATCH --job-name=<name>` | Name shown in `squeue` |
| `#SBATCH --output=<file>` | File where stdout is written (relative to submit directory) |
| `sleep 20` | Keeps the job alive 20 s so it is visible in the queue |

---

## 2. Submit

Single job:

```bash
sbatch simplejoba
```

All three:

```bash
sbatch simplejoba
sbatch simplejobb
sbatch simplejobc
```

Expected output (job IDs will differ):

```
Submitted batch job 1
Submitted batch job 2
Submitted batch job 3
```

---

## 3. Monitor

```bash
squeue
```

Expected (while running):

```
JOBID PARTITION     NAME     USER ST   TIME  NODES NODELIST(REASON)
    1     debug simplejo   ubuntu  R   0:05      1 node1
```

Other useful commands:

```bash
sinfo                      # node/partition state
scontrol show job <jobid>  # full job details
sacct -j <jobid>           # accounting info (if enabled)
scancel <jobid>            # cancel a job
```

### Watch Live

Refresh the queue every second to watch jobs move from `PD` (pending) to `R` (running) and disappear when done:

```bash
watch -n 1 squeue
```

Press `Ctrl+C` to exit.

Variants:

```bash
watch -n 1 squeue -u ubuntu                                  # only your jobs
watch -n 1 'squeue; echo; sinfo'                             # queue + node state together
watch -n 1 'squeue -o "%.6i %.12j %.3t %.8M %.20R"'          # custom columns (ID, name, state, time, reason/node)
```

Best used right after submitting a dependency chain, so you can see A run first, then C, then B as each `(Dependency)` hold is released.

---

## 4. Job Dependencies (Chaining)

`--dependency=afterok:<jobid>` holds a job in `PD` (pending) until the given job finishes with exit code 0. If the parent fails, the dependent job is never run.

### Commands used

```bash
sbatch simplejoba                              # Job A -> Submitted batch job 47
sbatch --dependency=afterok:47 simplejobc      # Job C waits for A -> job 48
sbatch --dependency=afterok:48 simplejobb      # Job B waits for C
squeue
```

### Resulting execution order

```
simplejoba (47)  -->  simplejobc (48)  -->  simplejobb
     A                     C                    B
```

Expected `squeue` right after submission:

```
JOBID PARTITION     NAME     USER ST   TIME  NODES NODELIST(REASON)
   47     debug simplejo   ubuntu  R   0:03      1 node1
   48     debug simplejo   ubuntu PD   0:00      1 (Dependency)
   49     debug simplejo   ubuntu PD   0:00      1 (Dependency)
```

Final output once all three complete (~60 s total, since each sleeps 20 s):

```bash
cat jobA.out jobC.out jobB.out
```

```
Running at A
Running at C
Running at B
```

### Notes

- Earlier attempts used `--dependency=afterok:44` for `simplejobc`; if the parent job ID no longer exists or didn't finish OK, Slurm rejects the submission or leaves the job pending/cancelled with `DependencyNeverSatisfied`.
- Always confirm the parent's job ID from the `Submitted batch job <id>` line (or `squeue`) before chaining.
- Other dependency types:

| Type | Runs when |
|---|---|
| `after:<id>` | Parent has started |
| `afterany:<id>` | Parent finished, any exit status |
| `afterok:<id>` | Parent finished successfully (exit 0) |
| `afternotok:<id>` | Parent failed |
| `singleton` | No other job with same name/user is running |

Capture the job ID automatically in one script:

```bash
A=$(sbatch --parsable simplejoba)
C=$(sbatch --parsable --dependency=afterok:$A simplejobc)
B=$(sbatch --parsable --dependency=afterok:$C simplejobb)
squeue
```

---

## 5. Verify Output

After ~20 seconds:

```bash
cat jobA.out jobB.out jobC.out
```

Expected:

```
Running at A
Running at B
Running at C
```

---

## 6. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `sbatch: command not found` | Slurm client not installed or not in `PATH` |
| Job stuck in `PD` (pending) | Check reason in `squeue`; nodes may be `down`/`drain`: run `sinfo`, then `sudo scontrol update nodename=<node> state=resume` |
| No `.out` file appears | Job hasn't started, or the submit directory isn't writable from the compute node (shared filesystem/NFS needed) |
| `Invalid account/partition` | Add `#SBATCH --partition=<name>` matching `sinfo` output |
