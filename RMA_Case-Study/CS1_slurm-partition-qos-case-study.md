# Case Study: Slurm Partition-Level QOS

## Objective

Show that a QOS attached **only to a partition** limits all jobs submitted to that partition, regardless of the submitting user's or account's own QOS. The account and user keep only the `normal` QOS.

## Scenario

| Item | Value |
|---|---|
| Partition | `exampart` (carries `testqos`) |
| Account | `testaccount` (QOS list / default: `normal`) |
| User | `ubuntu` (QOS: `normal`) |
| Test jobs | 6 x `sleep 300` |

> Rule under test: **only the partition has the QOS; the account and user do not.**

## Prerequisites

- `slurmdbd` running with accounting enabled.
- In `slurm.conf`, enforcement must include QOS and limits:

```conf
AccountingStorageEnforce=associations,limits,qos
```

- Partition defined with a QOS in `slurm.conf` (add `QOS=testqos` to the partition line, using your own node names):

```conf
PartitionName=exampart Nodes=<nodelist> QOS=testqos State=UP
```

- Apply the config change:

```bash
sudo scontrol reconfigure
```

## Step 1: Create the QOS with a limit (example values)

The limit below is an example; use whatever limit your lab defines.

```bash
sacctmgr -i add qos testqos
sacctmgr -i modify qos where name=testqos set MaxJobsPerUser=2
sacctmgr show qos format=Name,MaxJobsPU,Priority
```

## Step 2: Remove QOS from account and user (keep only `normal`)

```bash
# Account default QOS -> normal
sacctmgr -i modify account where name=testaccount set DefaultQOS=normal

# Account allowed QOS list (command as run in the lab)
sacctmgr -i modify account where name=testaccount set QOS-=testqos

# Inspect associations
sacctmgr show association format=Cluster,Account,User,Partition,QOS,DefaultQOS
```

## Step 3: Move the user out of `testaccount`

```bash
sacctmgr show association
sacctmgr delete user where name=ubuntu account=testaccount
sacctmgr show association
sacctmgr add user ubuntu account=root
```

After this, `ubuntu` has no association with `testaccount`, so no account-level QOS can be involved. Only the partition's QOS remains in play.

## Step 4: Submit test jobs to the partition

```bash
for i in {1..6}; do sbatch --partition=exampart --wrap="sleep 300"; done
```

## Step 5: Verify

```bash
squeue -u ubuntu -o "%.8i %.10P %.8T %.10M %.20r"
scontrol show partition exampart | grep -i qos
scontrol show job <jobid> | grep -Ei "QOS|Reason"
```

## Expected Result

- Jobs run up to the partition QOS limit (for example 2 with `MaxJobsPerUser=2`).
- Remaining jobs stay `PENDING` with a reason such as `QOSMaxJobsPerUserLimit`.
- `scontrol show partition exampart` shows `QoS=testqos`.
- The user and account show only `normal`, yet the partition's limit still applies.

## Key Takeaways

1. A partition QOS is enforced for every job in that partition, independent of the user's or account's QOS.
2. Account and user associations only need `normal`; no per-user or per-account `testqos` assignment is required.
3. Removing the user from `testaccount` and placing them under `root` does not bypass the partition QOS.
4. `AccountingStorageEnforce` must include `qos` and `limits`, or the limits are not enforced.

## Cleanup

```bash
scancel -u ubuntu
```
