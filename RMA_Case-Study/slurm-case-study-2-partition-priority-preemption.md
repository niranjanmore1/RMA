# Case Study 2: Partition Priority Preemption in Slurm

## 1. Goal

Make jobs in a high-priority partition (`shellpart`, PriorityTier 50) **suspend** running jobs in a lower-priority partition (`debug`, PriorityTier 10) when both compete for the same node. When the high-priority job finishes, the suspended job resumes automatically.

Unlike Case Study 1 (QOS preemption), the decision here is based on the **partition's `PriorityTier`**, not on the job's QOS.

## 2. Changes in `/etc/slurm/slurm.conf`

### 2.1 Scheduling section

```
#SCHEDULING
PreemptType=preempt/partition_prio
PreemptMode=SUSPEND,GANG
```

| Setting | Meaning |
|---|---|
| `PreemptType=preempt/partition_prio` | A job in a partition with a higher `PriorityTier` can preempt jobs in a lower-tier partition that share nodes |
| `PreemptMode=SUSPEND,GANG` | Preempted jobs are paused (SIGSTOP) and resumed later. `GANG` is **mandatory** with `SUSPEND`; it is the component that performs the suspend/resume |

### 2.2 Comment out QOS enforcement

```
#AccountingStorageEnforce=limits,qos
```

Why: preemption is now decided by the partition, so QOS rules are not needed. It also removes the earlier error `Job's QOS not permitted to use this partition` and the need for `--qos` and `AllowQOS`.

### 2.3 Accounting / priority section

Add under `#ACCOUNTING`:

```
PriorityType=priority/multifactor
PriorityWeightQOS=100000
```

| Setting | Meaning |
|---|---|
| `PriorityType=priority/multifactor` | Enables the multifactor job priority calculation (age, fair-share, QOS, partition, and so on) |
| `PriorityWeightQOS=100000` | Weight of the QOS factor in job priority. It affects pending-job **ordering** only; it does not drive partition preemption |

### 2.4 Partition definitions

```
PartitionName=debug Nodes=ALL PriorityTier=10 Default=YES MaxTime=INFINITE State=UP
PartitionName=shellpart Nodes=Controller PriorityTier=50 Default=NO MaxTime=15 State=UP
```

| Field | `debug` | `shellpart` |
|---|---|---|
| Nodes | ALL (includes Controller) | Controller |
| PriorityTier | 10 (low) | 50 (high) |
| Default | YES | NO |
| MaxTime | INFINITE | 15 minutes |

The partitions **must share at least one node** (`Controller` here). Preemption only happens between partitions that overlap.

Remove any leftover `AllowQOS=` from the `shellpart` line, as shown above.

### 2.5 Full relevant block

```
# SCHEDULING
PreemptType=preempt/partition_prio
PreemptMode=SUSPEND,GANG

# ACCOUNTING
#AccountingStorageEnforce=limits,qos
PriorityType=priority/multifactor
PriorityWeightQOS=100000

# PARTITIONS
PartitionName=debug Nodes=ALL PriorityTier=10 Default=YES MaxTime=INFINITE State=UP
PartitionName=shellpart Nodes=Controller PriorityTier=50 Default=NO MaxTime=15 State=UP
```

## 3. Apply the configuration

`PreemptType` and `PreemptMode` changes need a controller restart (a plain `reconfigure` is not enough).

```bash
sudo systemctl restart slurmctld
sudo scontrol reconfigure
scontrol show config | grep -i -E "PreemptType|PreemptMode|PriorityType"
scontrol show partition debug | grep -i -E "PriorityTier|PreemptMode"
scontrol show partition shellpart | grep -i -E "PriorityTier|PreemptMode|MaxTime"
```

Expected:

```
PreemptMode             = SUSPEND/GANG
PreemptType             = preempt/partition_prio
PriorityType            = priority/multifactor
PriorityTier=10
PriorityTier=50
```

## 4. Test procedure

Check how many CPUs the node has:

```bash
sinfo -N -l
slurmd -C
```
```
sbatch -p debug -w Controller --exclusive --wrap="sleep 600"
```
Ru One By One For Output
```
for i in {1..2}; do sbatch --partition=debug --wrap="sleep 300"; done
for i in {1..2}; do sbatch --partition=shellpart --wrap="sleep 300"; done
```

**Step 1:** fill the node with low-priority `debug` jobs (replace `2` with the node's CPU count):

```bash
sbatch -p debug --cpus-per-task=2 --wrap="sleep 600"
squeue -o "%.8i %.10P %.10T %.10M %R"
```

Expected: the job is `RUNNING`.

**Step 2:** submit a high-priority job to `shellpart`:

```bash
sbatch -p shellpart --cpus-per-task=2 --time=5 --wrap="sleep 120"
squeue -o "%.8i %.10P %.10T %.10M %R"
```

Expected:

```
   JOBID  PARTITION      STATE       TIME NODELIST(REASON)
      91      debug  SUSPENDED       0:20 Controller
      92 shellpart    RUNNING       0:02 Controller
```

**Step 3:** wait for the `shellpart` job to finish; the `debug` job returns to `RUNNING` and keeps its earlier elapsed time:

```bash
watch -n 5 'squeue -o "%.8i %.10P %.10T %.10M %R"'
```

**Step 4:** confirm in the history:

```bash
sacct -X --format=JobID,Partition,State,Elapsed,Suspended
scontrol show job <debug_jobid> | grep -i -E "JobState|SuspendTime|RunTime"
```

The `Suspended` column shows how long the `debug` job was paused.

## 5. How it works

1. The `debug` job runs on `Controller`.
2. A `shellpart` job arrives and needs the same CPUs.
3. Slurm compares `PriorityTier`: 50 > 10, so `shellpart` wins.
4. Gang scheduling sends SIGSTOP to the `debug` job. Its memory stays resident on the node.
5. When the `shellpart` job ends, the `debug` job is resumed (SIGCONT).

## 6. Partition-priority preemption vs QOS preemption

| Aspect | Case Study 1: QOS preemption | Case Study 2: partition priority |
|---|---|---|
| `PreemptType` | `preempt/qos` | `preempt/partition_prio` |
| Who decides | QOS `Preempt=` list | Partition `PriorityTier` |
| Needs slurmdbd | Yes | No |
| `AccountingStorageEnforce` | `qos,associations` | Not required (commented out) |
| User action | `--qos=high` | `-p shellpart` |
| Preempt action | Set per victim QOS (`PreemptMode` on QOS) | Global or partition `PreemptMode` |
| Typical mode | `REQUEUE` | `SUSPEND,GANG` |

## 7. Important notes

1. **`PriorityTier` vs `PriorityJobFactor`:** `PriorityTier` decides preemption and scheduling order between partitions. `PriorityJobFactor` only adjusts job priority within the multifactor formula.
2. **Memory is not freed on suspend.** A suspended job still holds its RAM, so the node needs enough memory for both jobs, or the high-priority job will not start. Enforce memory accounting with `SelectType=select/cons_tres` and `SelectTypeParameters=CR_Core_Memory`.
3. **GANG also time-slices** jobs in partitions with the **same** `PriorityTier` (default slice is `SchedulerTimeSlice=30` seconds). Different tiers do not time-slice; the higher tier simply wins.
4. **Per-partition override:** add `PreemptMode=REQUEUE` (or `OFF`, `CANCEL`) on a `PartitionName=` line to change what happens to jobs in that partition when they are preempted.
5. **`MaxTime=15` on `shellpart`:** jobs requesting more than 15 minutes (`--time`) stay pending. `INFINITE` on `debug` means those jobs can be suspended for a long time.
6. **Same-tier overlap:** if two partitions on the same nodes have equal `PriorityTier`, no preemption occurs; with GANG they time-slice instead.
7. **Reverting to Case Study 1:** uncomment `AccountingStorageEnforce=limits,qos` (or `qos,associations`), set `PreemptType=preempt/qos`, and `PreemptMode=REQUEUE`, then restart `slurmctld`.

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Both jobs run, nothing suspended | Node has free CPUs | Request all CPUs of the node in the first job |
| `shellpart` job stays `PENDING` (Resources) | `PreemptType` not applied | `sudo systemctl restart slurmctld`, then recheck `scontrol show config` |
| Error about `SUSPEND` needing `GANG` | `PreemptMode=SUSPEND` without `GANG` | Use `PreemptMode=SUSPEND,GANG` |
| No preemption at all | Partitions share no nodes | Make sure both include `Controller` |
| `shellpart` job pending, reason `PartitionTimeLimit` | `--time` greater than 15 min | Use `--time=10` or less |
| `shellpart` job pending, reason `QOSNotAllowed`-style message | Old `AllowQOS=` still on the partition line | Delete `AllowQOS=...`, then `scontrol reconfigure` |
| Job not suspending, memory error | Not enough RAM for both jobs | Lower `--mem`, or use `PreemptMode=REQUEUE` for the victim partition |

## 9. Quick command reference

```bash
sudo systemctl restart slurmctld
scontrol show partition
scontrol show config | grep -i -E "Preempt|PriorityType|SelectType"
squeue -o "%.8i %.10P %.10T %.10M %R"
sacct -X --format=JobID,Partition,State,Elapsed,Suspended
sprio -l
sinfo -p debug,shellpart
```
