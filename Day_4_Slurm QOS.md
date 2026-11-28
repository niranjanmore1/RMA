# Slurm QOS Setup (testqos)

## 1. Create the QOS and set priority

```bash
sacctmgr add qos testqos
```

```bash
sacctmgr modify qos testqos set priority=1000
```

## 2. Edit `slurm.conf`

```bash
nano /slurmdir/slurm-20.11.9/etc/slurm.conf
```

Add the following:

```
AccountingStorageType=accounting_storage/slurmdbd
```

```
AccountingStorageEnforce=limits,qos
PriorityType=priority/multifactor
PriorityWeightQOS=100000
```

### Partition line (restricts the partition to `testqos`)

```
PartitionName=shellpart Nodes=Controller Default=NO MaxTime=15 State=UP AllowQOS=testqos
```

## 3. Set QOS limits

```bash
sacctmgr -i modify qos where name=testqos set MaxJobsPU=10 MaxSubmitJobsPU=2
```

## 4. Create account and user

```bash
sacctmgr add account testaccount
```

```bash
sacctmgr add user ubuntu account=testaccount
```

### Assign `testqos` to the user

```bash
sacctmgr -i modify user where name=ubuntu account=testaccount cluster=linux set qos+=testqos
```

### Set default QOS (so jobs use `testqos` without `--qos`)

Allow the QOS on the account first, then make it the default (order matters, since DefaultQOS must be in the allowed QOS list):

```bash
sacctmgr -i modify account where name=testaccount set QOS=testqos
```

```bash
sacctmgr -i modify account where name=testaccount set DefaultQOS=testqos
```

```bash
sacctmgr -i modify user where name=ubuntu set DefaultQOS=testqos
```

### Verify

```bash
sacctmgr show association format=Cluster,Account,User,QOS,DefaultQOS
```

## 5. Restart services

```bash
sudo systemctl restart {slurmd,slurmctld}
```

## 6. Enable QOS preemption

```bash
nano /slurmdir/slurm-20.11.9/etc/slurm.conf
```

Add under `# SCHEDULING`:

```
# SCHEDULING
SchedulerType=sched/backfill
PreemptType=preempt/qos
PreemptMode=REQUEUE
```

Restart again:

```bash
sudo systemctl restart {slurmd,slurmctld}
```

## 7. Submit a test job

```bash
sbatch --account=testaccount --wrap="sleep 300"
```

Since `shellpart` only allows `testqos`, submit with the QOS and partition explicitly:

```bash
sbatch --account=testaccount --qos=testqos --partition=shellpart --wrap="sleep 300"
```

Check:

```bash
squeue
```
