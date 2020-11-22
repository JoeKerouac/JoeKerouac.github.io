## 获取命令行参数示例脚本：
```
#!/bin/bash

ARGS=`getopt -o "ao:" -l "arg,option:" -n "getopt.sh" -- "$@"`
 
eval set -- "${ARGS}"
 
while true; do
    case "${1}" in
        -a|--arg)
        shift;
        echo -e "arg: specified"
        ;;
        -o|--option)
        shift;
        if [[ -n "${1}" ]]; then
            echo -e "option: specified, value is ${1}"
            shift;
        fi
        ;;
        --)
        shift;
        break;
        ;;
    esac
done
```
说明：
```
ARGS=`getopt -o "ao:" -l "arg,option:" -n "getopt.sh" -- "$@"`
```
`-o`后边跟短参数名，一个字母就是一个参数，这个语句表示可以获取参数`-a`、`-o`，`-l`后边是长参数名，可以使用比较长的参数名，这个语句表示
获取参数`--arg`、`--option`，-n表示脚本名，主要用于脚本参数获取错误时打印错误提醒用的，`-- "$@"`表示获取脚本输入参数作为getopt的参数
来解析。

参数后边不跟表示没有值，有一个冒号表示必须要有值，两个冒号表示可以有也可以没有；

```
eval set -- "${ARGS}"
```
这一行表示重排序

## 判断目录是否存在：
```
if [ ! -d "/etc/kubernetes" ]; then
echo "初始化K8S配置目录..."
mkdir /etc/kubernetes
fi
```

## 判断文件是否存在
```
if [ ! -f "/root/Test.java" ]; then
echo "Test.java不存在"
fi
```
	
## 远程执行命令等：
```
yum install -y expect
远程复制，第一个参数为源路径，第二个参数为目标路径，第三个参数为远程主机密码
#示例：autoscp /root/project root@test.com:/root/ qiao
#示例：autoscp root@test.com:/root/project /root/ qiao
function autoscp(){
	echo "copy $1 to $2 ......"
	expect -c "
		spawn scp -r $1 $2
		expect {
			\"yes/no\" {set timeout 1500; send \"yes\r\"; exp_continue;}
			\"*assword\" {set timeout 1500; send \"$3\r\";}
		}
	expect eof"
}

#远程执行命令，第一个参数为远程主机登陆名和主机名，第二个参数为密码，第三个参数为要执行的命令，如果命令是多条需要加双引号并且使用分号分隔。
#示例：autoexec root@test.com qiao "cd ~/project; ls"
function autoexec(){
	echo "正在主机[$1]执行命令[$3] ......"
	expect -c "
		spawn ssh $1 \"$3\"
		expect {
			\"yes/no\" {set timeout 1500; send \"yes\r\"; exp_continue;}
			\"*assword\" {set timeout 1500; send \"$2\r\";}
		}
	expect eof"
}
```

## 查找service文件位置：
```
systemctl show --property=FragmentPath docker
```
	
## for循环：
```
for arg in 1 2 3
do
	echo "当前是$arg"
done
```
	
## 写入多行到文件：
> 注意，这个会覆盖源文件，如果不想覆盖，则使用`cat << EOF >> fileName`这种写法，另外EOF可以替换为任意其他单词，只要前后匹配即可；

```
cat << EOF > /etc/kubernetes/kubelet
KUBELET_ADDRESS="--address=0.0.0.0"
KUBELET_HOSTNAME="--hostname-override=$slef_add"
KUBELET_API_SERVER="--api-servers=http://$server_add:$kube_port"
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=$pod_img"
KUBELET_ARGS="--cluster_dns=$dns_addr --cluster_domain=cluster.local"
EOF
```

## 获取当前目录
```
# $0表示获取当前执行的sh的目录（如果是sh命令执行的，这里获取到的是相对文件路径，如果是sh中又用exec命令执行了，那么获取的是当前执行文件的绝对路径）
# 例如在/home目录使用sh test1.sh，那么PRG就是.test1.sh，如果该文件又执行了exec test2.sh，那么这时PRG就会变成/root/test2.sh，这里变成
# 绝对路径而不是相对路径了
PRG="$0"

# -h表示判断文件是否是软链接
# 下面这个用于获取真实路径
while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "$PRG"`/"$link"
  fi
done

# Get standard environment variables
# 这里获取到的就是当前的目录（如果是sh执行就是相对路径，如果是exec就是绝对路径）
PRGDIR=`dirname "$PRG"`
```

## 获取PID
```
# 获取当前shell的PID
echo $$

# 获取Shell最后运行的后台Process的PID
echo $!

# 例如，对于下面的命令，获取出来的就是Test2的PID
nohup Test1 &
nohup Test2 &
# 这是$!获取到的就是Test2的PID
echo $!
```