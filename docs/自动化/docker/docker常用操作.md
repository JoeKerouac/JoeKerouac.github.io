## 常用命令
```
docker run -ti -v /home/joe:/home/admin:
    运行某个镜像并且直接attach进去，并且挂载本机目录/home/joe到容器的/home/admin下边
docker run image-name：
	运行某个镜像
docker ps：
	查看现在正在运行的container（可以加参数，具体的可以查看--help）
docker attach container-id：
	进入某个正在运行的container
docker start container-id：
	启动某个已经关闭的container
docker stop container-id：
	关闭某个正在运行的container
docker rm container-id：
	删除某个容器
docker rmi image-id | image-name：
	删除某个镜像
docker commit container-id docker-hub-ID/custom-name：
	提交某个container到指定的docker-hub-id下（如果没有docker hub的账号可以替换为本地的registry地址，详情参考官网文档）
(ctrl+P) + (ctrl+Q)：
	从docker容器中退出，但是不关闭docker容器（如果docker容器是以run -tid参数运行）
docker run -p 1000:2000
	运行时将docker容器2000端口映射到物理机的1000端口
```
## 替换默认仓库
```
# 修改配置文件，替换仓库为阿里云的
tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://alrvuw46.mirror.aliyuncs.com"]
}
EOF

# 重新加载配置
systemctl daemon-reload
systemctl restart docker
```
