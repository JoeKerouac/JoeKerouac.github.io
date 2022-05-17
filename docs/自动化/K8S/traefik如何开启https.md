# k8s中部署traefik并开启https支持
k8s现在已经是容器编排领域的事实标准了，而在我们部署k8s集群时，ingress组件是必不可少的，在k8s领域，做的比较好的ingress组件就是traefik了，原生支持k8s，配置简单，上手极快，下面我们就来讲讲如何部署traefik并开启https支持；


## 生成https证书
> 如果已有证书则可以跳过此步骤

先创建ca：
```
openssl genrsa -out ca.key 4096

# 注意这里替换xxx.com为你自己的网址
openssl req -x509 -new -nodes -sha512 -days 36500 \
  -subj "/C=CN/ST=Henan/L=Henan/O=Joe/OU=IT/CN=xxx.com" \
  -key ca.key \
  -out ca.crt
```

根据ca签发证书：
```
openssl genrsa -out tls.key 2048

openssl req -new -key tls.key -out tls.csr -days 36500

openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 36500
```

## 将证书放入k8s的secret

执行以下命令：
```
kubectl create secret generic traefik-tls --from-file=ssl.crt --from-file=ssl.key -n kube-system
```

## 部署traefik
> 默认安装到了kube-system命名空间

要部署traefik，我们只需要在k8s中安装以下yaml文件即可（）：
```

kind: ConfigMap
apiVersion: v1
metadata:
  name: traefik-config
  namespace: kube-system
data:
  traefik.yaml: |-
    serversTransport:
      insecureSkipVerify: true
    api:
      insecure: true
      dashboard: true
    metrics:
      prometheus: ""
    entryPoints:
      # dns端口
      dns:
        address: ":53/udp"
      # 应用http端口
      web:
        address: ":80"
        # 设置forwardedHeaders为insecure，始终信任请求头中的X-Forwarded-*，也就是无论哪个ip过来的请求，我们都信任其携带的X-Forwarded-*请求头，将其转发到后端
        forwardedHeaders: 
          insecure: true
        transport:
          # 设置优雅退出时间
          lifeCycle:
            requestAcceptGraceTimeout: 10s
            graceTimeOut: 10s
          respondingTimeouts:
            # 读取请求的超时时间，0表示不会超时
            readTimeout: 10s
            # 响应超时时间，从接受完请求到完全写出响应之间的时间，0表示不会超时
            writeTimeout: 300s
            # keep-alive最长时间，如果超过该时间仍然没有数据那么连接将会中断
            idleTimeout: 300s
      # 应用https端口
      websecure:
        address: ":443"
        # 设置forwardedHeaders为insecure，始终信任请求头中的X-Forwarded-*，也就是无论哪个ip过来的请求，我们都信任其携带的X-Forwarded-*请求头，将其转发到后端
        forwardedHeaders: 
          insecure: true
        transport:
          # 设置优雅退出时间
          lifeCycle:
            requestAcceptGraceTimeout: 10s
            graceTimeOut: 10s
          respondingTimeouts:
            # 读取请求的超时时间，0表示不会超时
            readTimeout: 10s
            # 响应超时时间，从接受完请求到完全写出响应之间的时间，0表示不会超时
            writeTimeout: 300s
            # keep-alive最长时间，如果超过该时间仍然没有数据那么连接将会中断
            idleTimeout: 300s
    tls:
      # tls选项
      options:
        default:
          minVersion: VersionTLS12
          maxVersion: VersionTLS13
          cipherSuites:
            - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
            - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
            - TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256
            - TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384
            - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
            - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
            - TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256
            - TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384
    # 服务发现，使用kubernetes
    providers:
      kubernetesCRD: ""
      kubernetesingress: ""
    # traefik本身的日志配置，日志级别:DEBUG, PANIC, FATAL, ERROR, WARN, and INFO
    log:
      level: warn
      format: json
    # 访问日志配置
    accessLog:
      filePath: "/traefik/log/access.log"
      format: json
      # 内存中保存的日志行数buffer，当内存中日志行数超过该buffer值才会写出到磁盘
      bufferingSize: 100

---

# traefik部署先决条件，先部署以下内容
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutes.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRoute
    plural: ingressroutes
    singular: ingressroute
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: middlewares.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: Middleware
    plural: middlewares
    singular: middleware
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutetcps.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteTCP
    plural: ingressroutetcps
    singular: ingressroutetcp
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressrouteudps.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteUDP
    plural: ingressrouteudps
    singular: ingressrouteudp
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: tlsoptions.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSOption
    plural: tlsoptions
    singular: tlsoption
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: tlsstores.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSStore
    plural: tlsstores
    singular: tlsstore
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: traefikservices.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TraefikService
    plural: traefikservices
    singular: traefikservice
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: serverstransports.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: ServersTransport
    plural: serverstransports
    singular: serverstransport
  scope: Namespaced

---
# RBAC权限控制
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress

rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
      - networking.k8s.io
    resources:
      - ingresses
      - ingressclasses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - traefik.containo.us
    resources:
      - middlewares
      - ingressroutes
      - traefikservices
      - ingressroutetcps
      - ingressrouteudps
      - tlsoptions
      - tlsstores
      - serverstransports
    verbs:
      - get
      - list
      - watch

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress

roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress
subjects:
  - kind: ServiceAccount
    name: traefik-ingress
    namespace: kube-system


---
# serviceAccount定义
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: kube-system
  name: traefik-ingress

---

# 真正的服务安装
apiVersion: apps/v1
kind: Deployment
metadata:
    name: traefik-ingress
    namespace: kube-system
    labels:
        app: traefik-ingress
        kubernetes.io/cluster-service: "true"
spec:
    replicas: 3
    selector:
        matchLabels:
            app: traefik-ingress
    template:
        metadata:
            labels:
                app: traefik-ingress
                name: traefik-ingress
        spec:
            dnsPolicy: ClusterFirstWithHostNet
            terminationGracePeriodSeconds: 10
            affinity:
                podAntiAffinity:
                    requiredDuringSchedulingIgnoredDuringExecution:
                    - labelSelector:
                        matchExpressions:
                        - key: app
                          operator: In
                          values:
                          - traefik-ingress
                      namespaces:
                      - kube-system
                      topologyKey: kubernetes.io/hostname
            tolerations:
            - effect: NoExecute
              key: node.kubernetes.io/unreachable
              operator: Exists
              tolerationSeconds: 5
            - effect: NoExecute
              key: node.kubernetes.io/not-ready
              operator: Exists
              tolerationSeconds: 5
            - effect: NoExecute
              key: node.kubernetes.io/unschedulable
              operator: Exists
              tolerationSeconds: 5
            - effect: NoExecute
              key: node.kubernetes.io/network-unavailable
              operator: Exists
              tolerationSeconds: 5
            serviceAccountName: traefik-ingress
            containers:
            - image: traefik:v2.4
              name: traefik-ingress
              imagePullPolicy: IfNotPresent
              resources:
                  requests:
                    cpu: 500m
                    memory: 500Mi
              ports:
              - name: web
                containerPort: 80
              - name: websecure
                containerPort: 443
              - name: dns
                containerPort: 53
                protocol: UDP
              - name: admin
                containerPort: 8080
              args:
              - --configfile=/traefik/traefik.yaml
              volumeMounts:
                - mountPath: "/traefik"
                  name: config
            volumes:
              - name: config
                configMap:
                  name: traefik-config
                  items:
                    - key: traefik.yaml
                      path: traefik.yaml

---
# tls选项
apiVersion: traefik.containo.us/v1alpha1
kind: TLSOption
metadata:
  name: traefik-tls-options
  namespace: kube-system
spec:
  minVersion: VersionTLS12
  cipherSuites:
    - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384

---
# 存储分组
apiVersion: traefik.containo.us/v1alpha1
kind: TLSStore
metadata:
  name: default
  namespace: kube-system

spec:
  # 指定默认证书，k8s中traefik只能通过这个指定证书
  defaultCertificate:
    secretName: traefik-tls


---
apiVersion: v1
kind: Service
metadata:
 name: traefik
 namespace: kube-system
spec:
 selector:
   app: traefik-ingress
 ports:
 - port: 80
   targetPort: web
   name: web
   nodePort: 80
 - port: 443
   targetPort: websecure
   name: websecure
   nodePort: 443
 - port: 53
   targetPort: dns
   name: dns
   nodePort: 53
   protocol: UDP
 type: NodePort

```

## 一些注意点
至此，traefik已经部署完成，并且支持https，在此过程中，我们需要注意以下几点：
- 1、配置文件中配置tls.certificates[]是没有用的，在k8s中不支持这个配置；
- 2、TLSStore的name必须叫default；
- 3、原来使用http时定义了一个IngressRoute，我们使用https还需要再单独定义一个https的IngressRoute，也就是对于同一个服务，如果需要同时开启http和https，那么需要定义两个IngressRoute；

> 根据上边的内容，我们可以注意到，在k8s中我们只能配置一个证书，而不能配置多个（实际上IngressRoute中还可以单独指定一个证书，相当于可以配置多个，不过需要在每个IngressRoute中指定，比较麻烦）；

## 定义https的IngressRoute
> PS: http的IngressRoute请参考官方示例，比较简单，这里就不在列举了；

如下所示：

```

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  labels:
    app: my-service
    serviceName: my-service
  name: my-service-https
  namespace: dev
spec:
  # 这里指定https只能走443端口
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`my-service.kube.com`)
      services:
        - name: my-service
          port: 80
  # tls相关配置
  tls:
    # 如果不想使用全局默认的证书（即上边TlsStore中存储的证书），那么可以在IngressRoute所在的命名空间中创建一个secret存放证书，创建方法与上边相同，然后这里将注释放开，此时将优先使用这里的证书，如果这里的证书不匹配才会用全局默认证书；
    # secretName: secret
    # tls选项，这里使用我们上边定义的那个tls选项
    options:
      name: traefik-tls-options
      namespace: kube-system

```

# 联系我
- 作者微信：JoeKerouac 
- 微信公众号（文章会第一时间更新到公众号，如果搜不出来可能是改名字了，加微信即可=_=|）：代码深度研究院
- GitHub：https://github.com/JoeKerouac

