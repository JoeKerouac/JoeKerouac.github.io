# 构建环境搭建
> SoftEtherVPN地址：https://github.com/SoftEtherVPN/SoftEtherVPN_Stable.git

SoftEtherVPN的构建环境搭建（Dockerfile）：

```
FROM centos:7

RUN yum install -y epel-release.noarch \
    && yum update -y \
RUN yum -y groupinstall "Development Tools" \
    && yum install -y readline-devel ncurses-devel openssl-devel cmake3 gcc gcc-c++ make openssl11-devel libsodium-devel git \
    && rm -rf /usr/bin/cmake \
    && ln -s /usr/bin/cmake3  /usr/bin/cmake \
    && rm -rf /usr/include/openssl \
    && ln -s /usr/include/openssl11/openssl /usr/include/openssl \
    && rm -rf /usr/lib64/libcrypto.so \
    && ln -s /usr/lib64/openssl11/libcrypto.so /usr/lib64/libcrypto.so \
    && rm -rf /usr/lib64/libssl.so \
    && ln -s /usr/lib64/libssl.so.1.1.1g /usr/lib64/libssl.so 

ENV LDFLAGS="-L/usr/lib64/openssl11 -Wl,-rpath,/usr/lib64/openssl11"
ENV CFLAGS="-I/usr/include/openssl11/openssl"

```

# 构建
1、拉取代码：git clone https://github.com/SoftEtherVPN/SoftEtherVPN_Stable.git
2、切换到代码目录：cd SoftEtherVPN
3、执行命令./configure
4、执行命令make -C build