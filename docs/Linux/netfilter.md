## netfilter的hook执行
### 从内核发出到用户态
大概的流程是：NF_HOOK -> nf_hook_slow(在这里面判断 verdict变量，如果是 NF_QUEUE，就调用nf_queue) -> nf_queue(里面会使
用qh->outfn回调到nfqnl_enqueue_packet) -> nfqnl_enqueue_packet -> __nfqnl_enqueue_packet -> nfnetlink_unicast(这个时候
是要把包发送到用户态，我继续跟踪进去) -> netlink_unicast -> netlink_sendskb -> __netlink_sendskb.


nfqnl_enqueue_packet是如何注册的：
nfnetlink_queue模块中nfnl_queue_net_init函数调用了nf_register_queue_handler将nfqh（常量定义）注册了进去，同时nfqh的outfn函数指针
指向的就是nfqnl_enqueue_packet；


### 用户态决策完发回给内核态

用户空间对数据包决策后内核空间使用nfqnl_recv_verdict函数处理

nfnetlink模块初始化的时候使用netlink_kernel_create创建了netlink的sock链接，传入的netlink_kernel_cfg配置中传入的input回调
函数是nfnetlink_rcv，该函数会调用netlink_rcv_skb函数处理接收到的消息，处理时使用回调函数nfnetlink_rcv_msg做实际处理，这个回
调函数会根据nlmsg_type获取到相应的子系统处理，该子系统就是nfnetlink_queue，nfnetlink_queue_init函数注册了nfnetlink_queue
子系统nfqnl_subsys，该子系统的ID是NFNL_SUBSYS_QUEUE，回调函数是nfqnl_cb，然后该函数可以回调到nfqnl_recv_verdict函数


内核态nfqnl_recv_verdict函数会判断`nfqa[NFQA_PAYLOAD]`是否有值，如果有说明用户态进行了改包，调用`nfqnl_mangle`函数来进行修改，并且
该函数会将skb的`ip_summed`设置为`CHECKSUM_NONE`，表示协议栈计算好了校验值，设备不需要做任何事，也就是此时用户空间需要计算好校验和，同
时`nfqnl_mangle`函数会对内核态的skb自动扩容缩容，也就是如果用户态发来的新包比原来的小，那么会自动缩容节省空间，如果用户态发来的新包比原
来的大，那么会自动扩容防止放不下，但是用户空间发来的包数据长度最大不能超过0xFFFF；

### 其他
netfilter发送netlink消息的构建：在__nfqnl_enqueue_packet方法(net/netfilter/nfnetlink_queue.c)中调用nfqnl_build_packet_message(net/netfilter/nfnetlink_queue.c)构建消息





skb中放入数据顺序：(nfgenmsg)nlmsghdr->(nlattr)nfqnl_msg_packet_hdr->