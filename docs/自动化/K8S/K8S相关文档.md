## 相关概念
### Cluster
Cluster 是计算、存储和网络资源的集合，Kubernetes 利用这些资源运行各种基于容器的应用。

### Master
Master 是 Cluster 的大脑，它的主要职责是调度，即决定将应用放在哪里运行。Master 运行 Linux 操作系统，可以是物理机或者虚拟机。为了实现高可
用，可以运行多个 Master。

### Node
Node 的职责是运行容器应用。Node 由 Master 管理，Node 负责监控并汇报容器的状态，并根据 Master 的要求管理容器的生命周期。Node 运行在 Linux
操作系统，可以是物理机或者是虚拟机。

### Pod
Pod是kubernets的最小工作单元。每个pod包含一个或多个容器。pod中的容器会做为一个整体被master调度到一个node上运行。

kubernets引入pod主要基于下面两个目的：
- 可管理性：有些容器天生就是需要紧密联系，一起工作。Pod提供了比容器更高层次的抽象，将它们封装到一个部署单元中。Kubernetes以Pod为最小单元
  进行调度、扩展、资源共享、管理生命周期。
- 通信和资源共享：Pod中所有容器使用同一个网络namespace，即相同的IP地址和Port空间。它们可以直接使用localhost进行通信。同样的，这些容器可
  以共享存储，当kubernets挂载volume到pod，本质上是将volume挂在到pod中的每一个容器。

Pod有两种使用方式：
- 运行单一容器；one-container-per-Pod 是 Kubernetes 最常见的模型，这种情况下，只是将单个容器简单封装成 Pod。即便是只有一个容
  器，Kubernetes 管理的也是Pod而不是直接管理容器。

- 运行多个容器；但问题在于：哪些容器应该放到一个Pod中？答案是：这些容器联系必须 非常紧密，而且需要 直接共享资源。

### Controller
Kubernetes 通常不会直接创建 Pod，而是通过 Controller 来管理 Pod 的。Controller 中定义了 Pod 的部署特性，比如有几个副本，在什么样
的 Node 上运行等。为了满足不同的业务场景，Kubernetes提供了多种Controller，包括 Deployment、ReplicaSet、DaemonSet、StatefuleSet、
Job 等。 

#### Deployment
是最常用的 Controller，比如前面在线教程中就是通过创建 Deployment 来部署应用的。Deployment 可以管理 Pod 的多个副本，并确保 Pod 按照期望的
状态运行。

#### ReplicaSet
实现了 Pod 的多副本管理。使用 Deployment 时会自动创建 ReplicaSet，也就是说 Deployment 是通过 ReplicaSet 来管理 Pod 的多个副本，我们通
常不需要直接使用 ReplicaSet。ReplicaSet

#### DaemonSet
用于每个 Node 最多只运行一个 Pod 副本的场景。正如其名称所揭示的，DaemonSet 通常用于运行 daemon。

#### StatefuleSet
能够保证 Pod 的每个副本在整个生命周期中名称是不变的。而其他 Controller 不提供这个功能，当某个 Pod 发生故障需要删除并重新启动时，Pod 的名称会
发生变化。同时 StatefuleSet 会保证副本按照固定的顺序启动、更新或者删除。

#### Job
用于运行结束就删除的应用。而其他 Controller 中的 Pod 通常是长期持续运行。

### Service
Deployment 可以部署多个副本，每个 Pod 都有自己的 IP，外界如何访问这些副本呢？通过 Pod 的 IP 吗？要知道 Pod 很可能会被频繁地销毁和重启，它们
的 IP 会发生变化，用 IP 来访问不太现实。答案是 Service。Kubernetes Service 定义了外界访问一组特定 Pod 的方式。Service 有自己的 IP 和端
口，Service 为 Pod 提供了负载均衡。Kubernetes 运行容器（Pod）与访问容器（Pod）这两项任务分别由 Controller 和 Service 执行。

### Endpoint
提供对需要独立部署在K8S集群外的服务的访问，例如mysql，一般mysql是单独部署的，那在K8S集群中怎么访问集群外的mysql呢？这时就可以通过创建一个
Endpoint来实现，Endpoint可以指定外部的ip和port，然后通过service包装给内部集群使用；

### Namespace
如果有多个用户或项目组使用同一个 Kubernetes Cluster，如何将他们创建的 Controller、Pod 等资源分开呢？答案就是 Namespace。Namespace 可以
将一个物理的 Cluster 逻辑上划分成多个虚拟 Cluster，每个 Cluster 就是一个 Namespace。不同 Namespace 里的资源是完全隔离的。Kubernetes 默
认创建了两个 Namespace：

- default：创建资源时如果不指定，将被放到这个Namespace中。
- kube-system：Kubernetes 自己创建的系统资源将放到这个 Namespace 中。