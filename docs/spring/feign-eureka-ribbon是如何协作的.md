# feign-eureka-ribbon的协作原理

在我们的项目中使用了`feign`、`eureka`、`ribbon`这三个组件，最近想要在负载均衡上做些文章，需要了解这三个组件底层是如何协作的，这样才能找到突破口，所以给这三个组件的源码大概翻了一遍，最终整理出该笔记，希望对同样对这三个组件是如何协作感兴趣的读者一些帮助；

> 文中使用的spring cloud版本为`Greenwich.SR6`

> PS: 本文为纯源码分析，所以配合源码阅读本文最佳；

## feign

当我们引入`spring-cloud-openfeign-core`的时候，会引入`org.springframework.cloud.openfeign.ribbon.DefaultFeignLoadBalancedConfiguration`这个配置文件，这个配置文件提供了一个`feign.Client`接口的实现`org.springframework.cloud.openfeign.ribbon.LoadBalancerFeignClient`，`feign.Client`接口是feign中最核心的接口，feign框架的所有网络请求最终都会统一调用`feign.Client`，具体网络请求如何发起`feign`本身并不关心，我们可以自己实现网络请求，当然，`feign`中也给我们默认实现了一些，比如`feign.Client.Default`、`feign.httpclient.ApacheHttpClient`等，底层使用了不同的网络框架来处理网络请求，默认的实现是`feign.Client.Default`，这个实现中使用了jdk自带的`java.net.HttpURLConnection`实现了网络请求，没有连接池等概念，每次请求都会新建连接，效率比较低，不过这不在我们讨论的重点；

> 本文不重点讨论feign的网络实现，不过如果项目中有使用feign的话，要关注这点，一定要替代默认实现，默认实现的性能较差；

## ribbon

虽然feign默认的实现是`feign.Client.Default`，但是实际上feign框架并没有直接使用该实现，而是使用了`org.springframework.cloud.openfeign.ribbon.LoadBalancerFeignClient`包装了一层，我们的请求会被`LoadBalancerFeignClient`委托到`com.netflix.client.AbstractLoadBalancerAwareClient#executeWithLoadBalancer(S, com.netflix.client.config.IClientConfig)`方法处，该方法将请求提交到了`com.netflix.loadbalancer.reactive.LoadBalancerCommand`中，最终目的就是使用ribbon的负载均衡能力决策出一个`com.netflix.loadbalancer.Server`，而该`Server`就是为我们本次请求提供服务的服务端，包含ip、端口号等；

> 从这里也可以看出，默认情况下feign和ribbon是强绑定的；


下面我们来分析Server是如何决策出来的，首先是`LoadBalancerCommand`中提供了`com.netflix.loadbalancer.reactive.LoadBalancerCommand#selectServer`方法来选择为当前请求提供服务的`Server`，`selectServer`方法并没有直接实现该逻辑，而是将其委托到了`com.netflix.loadbalancer.LoadBalancerContext#getServerFromLoadBalancer`处，该方法中又将`Server`的决策逻辑委托到了`com.netflix.loadbalancer.ILoadBalancer#chooseServer`；


那`com.netflix.loadbalancer.ILoadBalancer`是何时注入的呢？我们回到`org.springframework.cloud.openfeign.ribbon.LoadBalancerFeignClient#execute`处，在这里，调用了`lbClient`方法来构建了feign负载均衡`FeignLoadBalancer`的实例，`lbClient`方法中将构建委托给了`org.springframework.cloud.openfeign.ribbon.CachingSpringLoadBalancerFactory#create`方法，最终在该方法中构建了`FeignLoadBalancer`的实例，该方法中通过调用`org.springframework.cloud.netflix.ribbon.SpringClientFactory#getLoadBalancer`来构建了`com.netflix.loadbalancer.ILoadBalancer`实例，`getLoadBalancer`方法中通过调用`org.springframework.cloud.context.named.NamedContextFactory#getInstance(java.lang.String, java.lang.Class<T>)`以获取bean的方式获取到了`ILoadBalancer`实例，并将其注入了`FeignLoadBalancer`实例中；

> 实际上`SpringClientFactory`继承自`org.springframework.cloud.context.named.NamedContextFactory`，是ribbon自定义的`NamedContextFactory`，这是spring cloud context组件提供的一个工厂类，用于创建和管理具有名称的应用程序上下文；


上个问题解决了，但是现在又有了新问题，`org.springframework.cloud.openfeign.ribbon.CachingSpringLoadBalancerFactory`中的`org.springframework.cloud.netflix.ribbon.SpringClientFactory`实例又是在哪儿构建的呢？`ILoadBalancer`类型的bean又是在哪儿声明的呢？


要回答这个问题，就要引入`ribbon`组件了，当我们引入`spring-cloud-netflix-ribbon`的时候，`org.springframework.cloud.netflix.ribbon.RibbonAutoConfiguration`就会被自动引入，该配置中声明了`SpringClientFactory`这个bean，同时该配置上添加了`@RibbonClients`注解，该注解引入了`org.springframework.cloud.netflix.ribbon.RibbonClientConfigurationRegistrar`，这个bean最终会扫描`org.springframework.cloud.netflix.ribbon.RibbonClients`注解和`org.springframework.cloud.netflix.ribbon.RibbonClient`注解来生成注册一批`org.springframework.cloud.netflix.ribbon.RibbonClientSpecification`bean定义，最终这些`RibbonClientSpecification`会被注入到我们构建的`SpringClientFactory`中作为配置，而`SpringClientFactory`的默认配置则是`org.springframework.cloud.netflix.ribbon.RibbonClientConfiguration`，该配置中声明了许多bean，其中就包含`ILoadBalancer`这个bean；


## eureka

上边提到了`feign`与`ribbon`是如何协作的，那`feign`、`ribbon`又是如何与`eureka`协作的呢？核心就在于`ribbon`提供的默认`ILoadBalancer`的实现`com.netflix.loadbalancer.ZoneAwareLoadBalancer`，在`ZoneAwareLoadBalancer`的`chooseServer`实现中，实际上并没有实现具体的逻辑，具体的逻辑是委托给了`com.netflix.loadbalancer.IRule#choose`，而`IRule`这个bean在`RibbonClientConfiguration`配置类中也有，提供了一个默认实现`com.netflix.loadbalancer.ZoneAvoidanceRule`，不过`ZoneAvoidanceRule`的`choose`方法中又先通过`ILoadBalancer`的`getAllServers`获取了所有`Server`列表，然后根据相关算法从里边挑处了一个`Server`，不过我们对这些算法不关心，我们关心的是它如何对接上了`eureka`的服务发现的能力；


现在我们继续回到`ILoadBalancer`中，ribbon提供的默认`ILoadBalancer`实现`ZoneAwareLoadBalancer`中通过`com.netflix.loadbalancer.ServerList`来获取了所有`Server`列表，而`ribbon`与`eureka`协作的重点就在于`ServerList`上；


当我们引入`spring-cloud-netflix-eureka-client`的时候，`org.springframework.cloud.netflix.ribbon.eureka.RibbonEurekaAutoConfiguration`会被自动引入，同样的，该配置类上添加了`@RibbonClients`注解，与`RibbonAutoConfiguration`不同的是，该注解还指定了使用`org.springframework.cloud.netflix.ribbon.eureka.EurekaRibbonClientConfiguration`配置类 ，而不是使用默认的配置类，这个配置类中声明了一个很重要的bean，那就是`com.netflix.loadbalancer.ServerList`这个bean，这个bean替代了`ribbon`默认的`ServerList`实现，其中使用了`EurekaClient`来获取指定服务的所有服务提供方ip、端口等信息，这样，`ribbon`就能使用到`eureka`提供的服务发现的能力了；


## 总结
看到上边绕来绕去，是不是感觉脑瓜嗡嗡叫？

![脑瓜嗡嗡叫](../../resource/spring/脑瓜嗡嗡叫.png)


简单总结下，`feign`与`ribbon`通过`org.springframework.cloud.openfeign.ribbon.LoadBalancerFeignClient`关联了起来，`ribbon`为`feign`提供了负载均衡的能力，而`eureka`则通过`org.springframework.cloud.netflix.ribbon.eureka.DomainExtractingServerList`实现了`ribbon`的`com.netflix.loadbalancer.ServerList`接口，来为`ribbon`提供服务发现能力；


至此，`feign`、`ribbon`、`eureka`的协作原理我们已经解析完毕，其中还有很多细节没有讲到，读者可以自行阅读源码来细细品味，例如`ribbon`的负载均衡策略实现算法、`ribbon`是如何对服务发现给到的后端服务进行健康检查的、`feign`网络请求的几种内置实现、`eureka`的分区负载均衡、`NamedContextFactory`在`ribbon`中是如何使用的等等；

# 联系我
- 作者微信：JoeKerouac
- 微信公众号（文章会第一时间更新到公众号，如果搜不出来可能是改名字了，加微信即可=_=|）：代码深度研究院
- GitHub：https://github.com/JoeKerouac
