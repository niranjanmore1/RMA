# QOS (Quality of Service) in Slurm

## 1. What QOS is

A QOS is a named policy object stored in the accounting database (slurmdbd). Every job runs under exactly one QOS. It does three things:

1. **Priority**: adds a weight to the job's scheduling priority.
2. **Limits**: caps resources, jobs, and time per user, account, or QOS as a whole.
3. **Preemption behavior**: decides who can kick whom off the nodes.

The default QOS is `normal` (priority 0, no limits, no preemption). It always exists.

## 2. Where QOS sits in the hierarchy

```
Cluster
 └─ Account (testaccount)
     └─ Association (cluster + account + user [+ partition])
         └─ allowed QOS list, default QOS
```

A job can use a QOS only if **all** of these are true:

- the QOS exists (`sacctmgr show qos`)
- it is in the user's association QOS list (`sacctmgr show assoc`)
- the partition permits it (`AllowQOS` / `DenyQOS` in slurm.conf)

## 3. Required configuration

`slurm.conf`:

```
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageEnforce=associations,limits,qos
PriorityType=priority/multifactor
PriorityWeightQOS=10000
PreemptType=preempt/qos
PreemptMode=REQUEUE
```

| Setting | Meaning |
|---|---|
| `AccountingStorageEnforce=qos` | Rejects jobs using a QOS the association doesn't allow |
| `AccountingStorageEnforce=limits` | Enforces QOS/association limits (implies associations) |
| `PriorityWeightQOS` | Multiplier for the QOS priority factor; if 0, QOS priority has **no** scheduling effect |
| `PreemptType=preempt/qos` | Preemption decided by QOS `Preempt` lists |
| `PreemptMode` | Global default action (see section 6) |

## 4. QOS attributes

### Priority and usage

| Attribute | Meaning |
|---|---|
| `Priority` | Integer added (scaled by `PriorityWeightQOS`) to job priority. Higher runs first. |
| `UsageFactor` | Multiplier on usage charged to fair-share. `0.5` = half cost, `2` = double, `0` = free. |
| `UsageThreshold` | Minimum fair-share value; jobs are held when the association's score falls below it. |
| `GraceTime` | Seconds a preempted job gets to finish before being killed. |

### Limits

Suffixes: PU = per user, PA = per account, no suffix = whole QOS.

| Attribute | Scope | Meaning |
|---|---|---|
| `MaxJobsPerUser` (MaxJobsPU) | user | Max **running** jobs per user |
| `MaxSubmitJobsPerUser` (MaxSubmitPU) | user | Max running + pending jobs per user |
| `MaxJobsPerAccount` / `MaxSubmitJobsPerAccount` | account | Same, per account |
| `MaxTRESPerUser` | user | e.g. `cpu=8,mem=16G,gres/gpu=2` total at once |
| `MaxTRESPerJob` (MaxTRES) | job | Max resources one job may request |
| `MaxTRESPerNode` | job | Max per node per job |
| `MaxTRESPerAccount` | account | Total across the account |
| `MaxTRESMins` | job | Max TRES-minutes one job can consume |
| `MaxWall` | job | Max wall time per job |
| `GrpTRES` | QOS-wide | Total TRES all jobs in this QOS can use together |
| `GrpJobs` / `GrpSubmit` | QOS-wide | Total running / submitted jobs in this QOS |
| `GrpTRESMins` | QOS-wide | Cumulative TRES-minutes cap |
| `GrpTRESRunMins` | QOS-wide | Cap on TRES-minutes of currently running jobs |
| `GrpWall` | QOS-wide | Cumulative wall-clock cap |
| `MinTRESPerJob` (MinTRES) | job | Minimum a job must request (e.g. force at least 8 CPUs) |

TRES = Trackable RESources: `cpu`, `mem`, `node`, `energy`, `gres/gpu`, `license/x`, `billing`. List them with `sacctmgr show tres`.

### Preemption

| Attribute | Meaning |
|---|---|
| `Preempt` | Comma-list of QOS names **this** QOS may preempt |
| `PreemptMode` | Action applied to jobs of **this** QOS when they are preempted: `cluster`, `off`, `cancel`, `requeue`, `suspend` |
| `PreemptExemptTime` | Time a job must run before it can be preempted (`HH:MM:SS`) |

### Flags

| Flag | Effect |
|---|---|
| `DenyOnLimit` | Reject at submit if the job would exceed a limit (instead of leaving it pending) |
| `EnforceUsageThreshold` | Enforce `UsageThreshold` |
| `NoReserve` | Job is not given backfill reservations |
| `PartitionMaxNodes` / `PartitionMinNodes` / `PartitionTimeLimit` | QOS overrides the partition limit |
| `OverPartQOS` | Job's QOS limits override the partition QOS |
| `RequiresReservation` | Job must run inside a reservation |
| `NoDecay` | QOS usage isn't decayed over time |
| `UsageFactorSafe` | Only apply UsageFactor if the job can finish within the limit |

## 5. How QOS affects scheduling priority

With `priority/multifactor`:

```
Job priority = PriorityWeightAge       * age_factor
             + PriorityWeightFairshare * fairshare_factor
             + PriorityWeightJobSize   * jobsize_factor
             + PriorityWeightPartition * partition_factor
             + PriorityWeightQOS       * qos_factor
             + PriorityWeightTRES      * tres_factor
             - nice
```

`qos_factor = QOS Priority / highest QOS Priority` in the system (0.0 to 1.0). Example with `PriorityWeightQOS=10000` and priorities normal=0, low=10, high=1000: `high` gets factor 1.0 (+10000), `low` gets 0.01 (+100), `normal` gets 0.

```bash
sprio -l
sprio -j <jobid>
```

Priority only reorders **pending** jobs. It never stops a running job.

## 6. Preemption in detail

With `PreemptType=preempt/qos`:

- A job in QOS `high` is pending and cannot start.
- If `high` has `Preempt=low` and a running job uses `low`, Slurm may preempt it.

**Which `PreemptMode` is used?** The one set on the **preempted** job's QOS, falling back to the partition `PreemptMode`, then the global one.

| Mode | Behavior |
|---|---|
| `OFF` | No preemption |
| `CANCEL` | Preempted job is cancelled |
| `REQUEUE` | Job is killed and returned to PENDING (needs `--requeue` / `JobRequeue=1`) |
| `SUSPEND` | Job is paused with SIGSTOP, memory stays resident, resumes afterward (needs `PreemptMode=SUSPEND,GANG`) |
| `GANG` | Time-slicing; used together with SUSPEND |

> **Important:** `PreemptMode` on a QOS applies when jobs of that QOS are preempted, not when they preempt. To requeue low-priority jobs, set it on `low`:

```bash
sacctmgr -i modify qos low set PreemptMode=requeue
sacctmgr -i modify qos high set Preempt=low
```

`GraceTime` gives the victim time to checkpoint (it receives SIGTERM first). `PreemptExemptTime` protects a job for its first N minutes.

## 7. Assigning QOS

**Creating and editing:**

```bash
sacctmgr add qos high priority=1000
sacctmgr modify qos high set MaxJobsPerUser=10 MaxWall=02:00:00
sacctmgr modify qos high set MaxTRESPerUser=cpu=16,gres/gpu=2
sacctmgr modify qos high set Preempt=low,normal
sacctmgr modify qos high set Preempt=          # clear the list
sacctmgr delete qos high
```

**Associating with users and accounts:**

```bash
sacctmgr modify user where name=ubuntu account=testaccount cluster=linux set qos+=high       # add
sacctmgr modify user where name=ubuntu account=testaccount cluster=linux set qos-=high       # remove
sacctmgr modify user where name=ubuntu account=testaccount cluster=linux set qos=normal,high # replace whole list
sacctmgr modify user where name=ubuntu set defaultqos=normal
sacctmgr modify account where name=testaccount set qos+=high
```

**Inheritance:** if a user association has no QOS list, it inherits from its parent account, then cluster root.

**Submitting:**

```bash
sbatch --qos=high job.sh
srun --qos=high ...
salloc --qos=high ...
```

Default QOS order: user's `defaultqos` → account's → cluster's → `normal`.

## 8. QOS and partitions

Two separate mechanisms:

1. **Partition `AllowQOS` / `DenyQOS`** in slurm.conf: which QOS may submit to the partition. Default is `AllowQOS=ALL`.
2. **Partition QOS** (`PartitionName=x QOS=partqos`): the partition is tied to a QOS whose limits apply to every job there. If both job QOS and partition QOS set a limit, the **partition QOS wins** unless the job QOS has the `OverPartQOS` flag.

```
PartitionName=shellpart Nodes=Controller MaxTime=15 State=UP AllowQOS=testqos,normal QOS=partqos
```

## 9. Limit hierarchy and precedence

Order of enforcement when several limits apply:

1. Partition QOS
2. Job QOS
3. User association
4. Account association
5. Parent accounts up to root
6. Cluster

The first limit hit blocks the job, and the reason shows in `squeue`.

## 10. Pending reasons

| Reason | Meaning |
|---|---|
| `QOSMaxJobsPerUserLimit` | Hit MaxJobsPU |
| `QOSMaxCpuPerUserLimit` | Hit MaxTRESPU cpu |
| `QOSMaxWallDurationPerJobLimit` | Job `--time` exceeds MaxWall |
| `QOSGrpCpuLimit` | QOS-wide GrpTRES reached |
| `QOSResourceLimit` | Generic QOS resource cap |
| `Job's QOS not permitted to use this partition` | Partition `AllowQOS` mismatch |
| `InvalidQOS` | QOS not in the association list |
| `AssocMaxJobsLimit` | Association (not QOS) limit |

Without `DenyOnLimit`, a job exceeding a limit stays PENDING. With it, `sbatch` fails immediately.

## 11. Inspection commands

```bash
sacctmgr show qos format=Name,Priority,Preempt,PreemptMode,GraceTime,MaxJobsPU,MaxSubmitPU,MaxTRESPU,MaxWall,Flags%30
sacctmgr show assoc format=Cluster,Account,User,QOS%40,DefaultQOS
scontrol show job <id> | grep -i qos
sprio -l
sacct -X --format=JobID,QOS,State,Elapsed
sshare -a
```

## 12. Worked example: three-tier setup

Goal: `low` for background work, `normal` as default, `high` for urgent jobs that can preempt `low`, with `high` capped.

```bash
sacctmgr -i add qos low  priority=10   PreemptMode=requeue GraceTime=30
sacctmgr -i add qos high priority=1000 Preempt=low MaxJobsPerUser=10 MaxWall=04:00:00 Flags=DenyOnLimit
sacctmgr -i modify qos normal set priority=100

sacctmgr -i modify user where name=ubuntu account=testaccount cluster=linux set qos=low,normal,high defaultqos=normal
```

`slurm.conf`:

```
AccountingStorageEnforce=associations,limits,qos
PriorityType=priority/multifactor
PriorityWeightQOS=10000
PreemptType=preempt/qos
PreemptMode=REQUEUE
JobRequeue=1
PartitionName=shellpart Nodes=Controller MaxTime=15 State=UP AllowQOS=low,normal,high
```

Test:

```bash
sbatch -p shellpart --qos=low  --requeue --wrap="sleep 300"
sbatch -p shellpart --qos=high --wrap="sleep 300"
squeue -o "%.8i %.10q %.10T %.10M %R"
sprio -l
```

On a single-node controller with free CPUs, both jobs just run. To see preemption, fill the CPUs with `low` jobs first (e.g. `--cpus-per-task=<all>`), then submit `high`.

## 13. Common mistakes

1. `Preempt=` takes QOS names, not a mode.
2. `PreemptMode` belongs on the victim QOS.
3. `PreemptExemptTime` takes a duration, not YES/NO.
4. Adding a QOS to the DB does nothing until it is added to the user/account association.
5. Partition `AllowQOS` and the association list must both permit the QOS.
6. `PriorityWeightQOS=0` makes QOS priority meaningless.
7. `AccountingStorageEnforce` without `limits` means MaxJobs/MaxTRES are recorded but not enforced.
8. Run `sacctmgr` without `sudo` if sudo loses your config (or use `sudo SLURM_CONF=/etc/slurm/slurm.conf sacctmgr ...`).
9. `scontrol reconfigure` applies partition changes; `PreemptType` changes need a `slurmctld` restart.
10. Changing a QOS doesn't retroactively affect running jobs' limits; pending jobs are re-evaluated.

## 14. Troubleshooting log from this lab

| Symptom | Cause | Fix |
|---|---|---|
| `No valid entity in list command` | Typo `quos` | `sacctmgr show qos` |
| `Bad PreemptExemptTime format` | `PreemptExempt=NO` parsed as `PreemptExemptTime` | Remove it |
| Job `PD`: QOS not permitted to use this partition | Partition `AllowQOS` excluded `normal` | Submit with `--qos=testqos` or add `normal` to `AllowQOS` |
| `Invalid qos specification` | QOS not in user's association | `sacctmgr -i modify user where name=ubuntu account=testaccount cluster=linux set qos+=testqos` |
| `not running a supported accounting_storage plugin` | `sudo` didn't pick up slurm.conf | Run without `sudo`, or pass `SLURM_CONF` |
