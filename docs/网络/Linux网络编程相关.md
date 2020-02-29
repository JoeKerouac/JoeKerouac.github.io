## 直接在L2层发送报文
```
socket(AF_PACKET,SOCK_RAW,htons(ETH_P_ALL));
```

使用上边的socket可以在L2层发送报文，可以组装ARP报文发送；

AF_PACKET相关文档:http://swoolley.org/man.cgi/7/packet