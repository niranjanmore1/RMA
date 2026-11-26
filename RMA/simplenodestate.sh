#!/bin/bash
echo "NodeName , CPUs,Memory State"

for node in ${sinfo -N -h | awk '{print $1}'
do
	cpu_info=$(scontrol show node $node | grep "CPU" | awk '(print $1)')
	mem_info=$(scontrol show node $node | grep "Real Memory" | awk '{print $1}')
	state_info=$(scontrol show node $node | grep "State" | awk '{print $1}')

	echo "$node ,$cpu_info,$mem_info,$state_info"
done
