#read omnireduce.cfg
wnum=0
anum=0
mode="RDMA"
ib_hca="mlx5_1"
ib_port="1"
while read line; do

if [[ $line =~ "num_workers"  ]]
then
    wnum=$((${line: 14}))
    echo "Worker number: $wnum"
fi
if [[ $line =~ "num_aggregators"  ]]
then
    anum=$((${line: 18}))
    echo "Aggregator number: $anum"
fi
if [[ $line =~ "direct_memory"  ]]
then
    mode_num=$((${line: 16}))
    if [[ "$mode_num" -eq "1" ]]
    then
        mode="GDR"
    fi
    echo "mode: $mode"
fi
if [[ $line =~ "ib_hca"  ]]
then
    ib_hca=${line: 9}
    echo "IB HCA: ${ib_hca}"
fi
if [[ $line =~ "ib_port"  ]]
then
    ib_port=${line: 10}
    echo "IB Port: ${ib_port}"
fi
if [[ $line =~ "worker_ips"  ]]
then
    #echo "$line"
    line=${line: 13}
    worker_arr=(${line//,/ })
    j=0
    while [ $j -lt $wnum ]
    do
        echo "worker $j IP : ${worker_arr[$j]}"
	j=$((j+1))
    done
fi
if [[ $line =~ "aggregator_ips"  ]]
then
    #echo "$line"
    line=${line: 17}
    aggregator_arr=(${line//,/ })
    j=0
    while [ $j -lt $anum ]
    do
        echo "aggregator $j IP : ${aggregator_arr[$j]}"
	j=$((j+1))
    done
fi
done < omnireduce.cfg

# start workers
i=0
while [ $i -lt $wnum ]
do
    ssh -p 2222 ${worker_arr[$i]} "cd /home/exps/models/DeepLight; mkdir -p ./100G-results/NCCL/ ; export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}; export NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME}; export NCCL_DEBUG=INFO; export NCCL_IB_HCA=${ib_hca}:${ib_port}; export OMPI_COMM_WORLD_SIZE=${wnum}; export OMPI_COMM_WORLD_RANK=$i; export OMPI_COMM_WORLD_LOCAL_RANK=0; nohup /usr/local/conda/bin/python main_all.py -l2 6e-7 -n_epochs 2 -warm 2 -prune 1 -sparse 0.90  -prune_deep 1 -prune_fm 1 -prune_r 1 -use_fwlw 1 -emb_r 0.444 -emb_corr 1. -backend nccl -batch_size 2048  -init tcp://${worker_arr[0]}:4000 > ./100G-results/NCCL/log.txt 2>&1 &"
    i=$((i+1))
done
# check completed
while [[ 1 ]]
do
    count=`ps -ef |grep python |grep -v "grep" |wc -l`
    if [ 0 == $count ];then
	break
    fi
done
i=0
while [ $i -lt $anum ]
do
    ssh -p 2222 ${aggregator_arr[$i]} "pkill -9 aggregator"
    i=$((i+1))
done
