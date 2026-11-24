# slurm installation

---

slurm version: 20.11.9

---

### Update system

```jsx
sudo apt update
```

### install opessh-server

```jsx
sudo apt install openssh-server
```

### take remote access on putty or mobaextream

```jsx
ssh user@ip 
```

### Set hostnames

```jsx
sudo hostnamectl set-hostname controller
```

add entry in /etc/hosts

```jsx
192.168.187.128 controller
```

### Create a directory and set permissions

```jsx
sudo mkdir /slurmdir 
sudo chmod 777 /slurmdir
```

### *Slurm Installation **Common steps for controller and compute***

1. **Install Required Dependencies:**
Install necessary libraries and build tools:

```bash
sudo apt install -y build-essential munge libmunge-dev libmunge2 libmysqlclient-dev libssl-dev libpam0g-dev libnuma-dev perl
```

1. **Download SLURM:**
Use wget to download SLURM package:

```bash
wget https://download.schedmd.com/slurm/slurm-20.11.9.tar.bz2
```

1. **Extract and Configure SLURM:**

```bash
tar -xvjf slurm-20.11.9.tar.bz2 slurm-20.11.9/
cd slurm-20.11.9/
./configure --prefix=/slurmdir/slurm-20.11.9/
```

1. **Compile and Install:**

```bash
make
make install
```

### *Controller Node Specific Steps*

1. check munge key 

```jsx
sudo ls -l /etc/munge/munge.key 
sudo chmod 400 /etc/munge/munge.key
```

1. **Set Munge Permissions and Start Service:**

```bash
sudo chown -R munge: /etc/munge /var/log/munge
sudo chmod 0700 /etc/munge /var/log/munge
sudo systemctl enable munge
sudo systemctl start munge
sudo systemctl status munge
```

1. **Configure SLURM:**

```bash
cd /slurmdir/slurm-20.11.9/etc
cp slurm.conf.example slurm.conf
```

1. **Edit SLURM Configuration:**
Edit slurm.conf with the following content:

```bash
ClusterName=cluster
SlurmctldHost=controller
SlurmUser=root
NodeName=controller Procs=1 State=UNKNOWN
PartitionName=partition Nodes=ALL Default=YES MaxTime=INFINITE State=up 
```

1. Create a softlink for services 

```jsx
sudo ln -s /slurmdir/slurm-20.11.9/etc/slurmctld.service /usr/lib/systemd/system/slurmctld.service
sudo ln -s /slurmdir/slurm-20.11.9/etc/slurmd.service /usr/lib/systemd/system/slurmd.service
```

1. Restart services and check status

```jsx
sudo systemctl restart slurmctld 
sudo systemctl restart slrumd
sudo systemctl status slurmctld 
sudo systemctl status slrumd
```

1. Create a required directories

```jsx
sudo mkdir -p /var/spool/slurm/ctld
sudo chmod  755 /var/spool/slurm/ctld
sudo chown gauravc:gauravc /var/spool/slurm/ctld/
sudo mkdir -p /var/spool/slurm/d
sudo chown gauravc:gauravc /var/spool/slurm/d
```

1. add export paths  

/etc/bash.bashrc

```jsx
export PATH="/slurmdir/slurm-20.11.9/bin/:$PATH"
export PATH="/slurmdir/slurm-20.11.9/sbin/:$PATH"
export LD_LIBRARY_PATH="/slurmdir/slurm-20.11.9/lib/:$LD_LIBRARY_PATH"
```

code configuration files to compute nodes 

```jsx
scp -r /slurmdir/slurm-20.11.9/etc/slurm.conf gauravc@compute1:/tmp 
scp -r /etc/munge/munge.key gauravc@compute1:/tmp
```

### Compute nodes steps

```jsx
cp /tmp/slurm.conf /slurmdir/slurm-20.11.9/etc/
cp /tmp/munge.key /etc/munge/munge.key 
chmod 400 /etc/munge/munge.key
```

```jsx
sudo chown -R munge: /etc/munge /var/log/munge
sudo chmod 0700 /etc/munge /var/log/munge
sudo systemctl enable munge
sudo systemctl start munge
sudo systemctl status munge
```

```jsx
sudo mkdir -p /var/spool/slurm/d
sudo chown gauravc:gauravc /var/spool/slurm/d
```
