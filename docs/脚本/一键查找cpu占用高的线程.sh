# topN表示我们要查询CPU占用最高的Java程序中占用CPU最高的N个线程栈，3就表示查询CPU占用最高的Java程序中占用CPU最高的3个线程的线程栈
topN=3
pid=`top -b -n 1 | grep java | awk '{print $9"    "$1}' | sort -nr | head -n 1 | awk '{print $2}'`
tidArr=`top -b -n 1 -H -p ${pid} | grep -E "^\s*[0-9]+" | awk '{print $9"    "$1}' | sort -nr | head -n ${topN} | awk '{print $2}'`

for tid in ${tidArr}
do
    # 查询线程的cpu占用
    cpuUse=`top -b -n 1 -H -p ${pid} | grep -E "^\s*${tid}" | awk '{print $9}'`
    tid=`printf '%x' ${tid}`
    echo "进程[${pid}]的线程[${tid}]cpu 占用为：${cpuUse}，详细线程栈如下："

    jstack ${pid} | grep nid=0x${tid} -A 150 | while read line;do if [[ $line != "" ]];then echo $line;else break;fi;done

    echo -e "\n\n"
done

