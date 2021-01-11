## 相关组件
### kubelet
kubelet 是在每个 Node 节点上运行的主要 “节点代理”。

kubelet 是基于 PodSpec 来工作的。每个 PodSpec 是一个描述 Pod 的 YAML 或 JSON 对象。kubelet 接受通过各种机制（主要是通过 apiserver）提供的一组 PodSpec，并确保这些 PodSpec 中描述的容器处于运行状态且运行状况良好。kubelet 不管理不是由 Kubernetes 创建的容器。

除了来自 apiserver 的 PodSpec 之外，还可以通过以下三种方式将容器清单（manifest）提供给 kubelet。

File（文件）：利用命令行参数给定路径。kubelet 周期性地监视此路径下的文件是否有更新。监视周期默认为 20s，且可通过参数进行配置。

HTTP endpoint（HTTP 端点）：利用命令行参数指定 HTTP 端点。此端点每 20 秒被检查一次（也可以使用参数进行配置）。

HTTP server（HTTP 服务器）：kubelet 还可以侦听 HTTP 并响应简单的 API（当前未经过规范）来提交新的清单。