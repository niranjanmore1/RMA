#For Setting QOS (Quality Of Service) 
```
sacctmgr add qos testqos
```

```
sacctmgr modify qos testqos set priority=1000
```

```
nano /slurmdir/slurm-20.11.9/etc/slurm.conf
```

In Slurm.conf Add Below to 
```
AccountingStorageType=accounting_storage/slurmdbd
```

```
AccountingStorageEnforce=limits,qos
PriorityType=priority/multifactor
PriorityWeightQOS=100000
```

#In NodeName 
```
PartitionName=shellpart Nodes=Controller Default=NO MaxTime=15 State=UP AllowQOS=testqos
```

```
sacctmgr -i modify qos where name=testqos set MaxJobsPU=10 MaxSubmitJobsPU=2
```

```
sacctmgr add account testaccount
```
```
sacctmgr add user ubuntu account=testaccount
```
```
sacctmgr show association
```
```
sudo systemctl restart {slurmd,slurmctld}
```
```
nano /slurmdir/slurm-20.11.9/etc/slurm.conf
```
# SCHEDULING
SchedulerType=sched/backfill
PreemptType=preempt/qos
PreemptMode=REQUEUE

```
sudo systemctl restart {slurmd,slurmctld}
```
```
sbatch --account=testaccount --wrap="sleep 300"
```

