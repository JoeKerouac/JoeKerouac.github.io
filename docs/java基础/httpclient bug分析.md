# 由httpclient bug导致的生产问题
## 服务器挂了
在一个平常的早上，我们一个服务的pod忽然在高峰期重启了，导致了大量错误，为了防止再出现问题，我们就开始了一轮排查；

## pod为什么被重启了
首先，我们先分析了pod重启的原因，查看了监控，发现pod是因为健康检查失败导致被k8s重启了；

继续查看健康检查失败详细原因，发现是因为连接被拒、请求超时这两种原因导致的，说明此时tomcat连接池满了，导致无法接收新连接，请求处理的又太慢，堆积请求无法被快速处理，导致请求处理超时，并进一步导致请求堆积，连接无法释放，无法接收新的连接，此时k8s的健康检查自然就失败了；

> 我们的k8s健康检查用的是http请求，接口是SpringBoot Actuator提供的；

## 为什么请求处理太慢

服务处理的慢，正常来讲以下指标肯定至少有一个是异常的：

- CPU：代码bug导致CPU死循环或者类似死循环，例如有一个垃圾算法时间复杂度太高，又频繁触发；
- 内存：内存溢出或者本身内存设置的太小，导致频繁的Full GC，导致STW；
- DB（慢sql）：因为数据库都是同步IO，如果有大量慢SQL，会导致数据库连接被占用，其他线程无法获取数据库连接导致被挂起（通常数据库连接池会比线程池小）；
- 三方调用慢；
- redis等其他外部依赖（不过通常不会有什么问题）；

但是查看了监控后，发现：
- 服务的CPU、内存都正常；
- 慢sql有，但是一分钟只有几个，不至于把服务搞垮；
- 看日志发现三方调用确实慢；

继续对三方调用进行分析：

对于日志中发现的三方调用比较慢的那个接口，分析发现是在异步任务中调用的，理论上对同步接口应该没什么影响的，并且虽然异步任务是在事务中执行的，会占用数据库连接，但是异步任务的线程池是固定的30个，理论上我们有300个数据库连接，30个占用应该不会有这么大的影响的；至此线索就断了；

> 因为分析的时候已经是晚上了，比较匆忙，并且基于过往经验先入为主的认为大概率就是慢sql导致连接占用导致的，所以这里实际上忽略了一个重要信息，那就是实际上同步请求线程中也有另外一个三方调用的接口，这个是最关键的一个因素；

## 临时方案

线索到这里就断了，并且同事反馈白天的压测也没有复现场景，因为天也晚了，所以我们就先暂定了一个方案，简单做了一些调整：
- 1、添加了数据库相关的详细日志，记录sql执行时间、连接获取等待时间等；
- 2、将全局httpclient超时时间调短为3秒；
- 3、减小下游异步调用时的并发；

## 转机
前一天晚上调整后，第二天发现状况已经缓解了，pod也没有被k8s杀死重启；此时同事提到了我们前一天忽略的因素，那就是同步请求线程中也有三方调用接口，并且通过压测复现了这个同步调用响应过慢导致tomcat线程池被大量占用，最终导致pod的健康检查失败的场景；


问题定位了，那我们就开始排查为什么请求会这么慢，我们下游的口径是他们限流了，并且很快就返回了http status 429，但是我们这儿又确实请求超时了，所以就怀疑是下游日志中的时间统计有问题，可能在实际限流逻辑生效前就已经等待了很久了，但是下游在测试环境把他们的限流策略调整为了0，此时只要请求就会立即触发限流策略返回429,下游用postman调用也显示很快就返回的了；此时我们的系统调用仍然显示调用超时；


啊？这就尴尬了，那看来问题很有可能就在我们系统中，然后我在本地写了一个测试用例，执行了一下，发现也很快的就返回了429,并没有超时，没办法了，上大招，只能进pod里边抓个包看看了，结果进去后发现确实是远程没有响应，这就奇怪了，为什么同样代码在本地执行跟远程不一样呢？

![懵逼](../../resource/操作系统/懵逼.jpg)


此时，我注意到了，我本地测试用例中引用的apache http client版本比较新，因为中间更新过，但是服务器上跑的那个项目的apache http client已经很久没有更新过了，版本比较老，那有没有可能是这个问题呢？


说干就干，快速将本地http client从5.2.1降到5.0.3，重新执行，发现果然复现了，至此，问题解决方案已经有了，只需要升级项目中的http client版本号即可；

## 问题跟因
当然，这只是解决了我们的问题，但是此时还是不知道是什么导致了这个差异，本着有问题就刨根问底的原则，我又继续排查了下来；


首先是抓包，对低版本的请求进行了抓包，结果抓包时才想起来发现请求是https的，压根无法解密，wireshark要对https解密的话配置起来又比较麻烦，所以暂时先不解密，直接看下报文，发现请求被发送了两次，第二次没有响应，这里为什么会请求两次呢？经过对http client代码的解析，发现http client默认情况下会在服务端返回429和503的时候重试（重试策略源码参考: `org.apache.hc.client5.http.impl.DefaultHttpRequestRetryStrategy`）；


但是按理说重复发送也不该不响应的呀，所以我就把http client升级上来，然后继续抓包，发现高版本的也是请求了两次，不同的是第二次也有响应，为什么会这样呢？


本来到这里我都考虑想办法配置下https解密了，不过在我对比两个版本的包的时候，发现新版本的两次请求都是两个application data（https的业务数据record type对应的就是application data，在wireshark中展示也是application data，对https包不熟悉的可以参考历史文章：![record数据结构](https://mp.weixin.qq.com/s/wvrTFnWzXp-oDJ_amdrQbg)），而老版本的第二次请求只有一个application data，结合http定义，两个application data应该分别对应的是http的header和body,分了两次发送，现在问题变成了什么低版本的http client第二次请求只发送了http header,没有发送http body没有发送；


因为我用的是http client的异步模式，熟悉http client源码的小伙伴肯定知道，异步模式下http client的重试是在`org.apache.hc.client5.http.impl.async.AsyncHttpRequestRetryExec`中进行的，在5.0.3版本中，请求在AsyncHttpRequestRetryExec的109行被标记为重试，然后在AsyncHttpRequestRetryExec的127行重试，然后我们找到发送body的代码`org.apache.hc.core5.http.impl.nio.AbstractHttp1StreamDuplexer#streamOutput`，在479行加上断点，执行到重试逻辑的时候发现第二次到这里写出的长度是0，因为这里是一个ByteBuffer，那很容易想到应该是第一次写出后position更新到了limit，第二次写出时因为没有重置position导致写出数据为0（我们自己写代码的时候如果不注意也会出现类似问题），重新调试验证下我们的想法，在写出前看了下此时ByteBuffer的状态，果然，发现第一次写出是position是0，第二次position=limit，没有重置；

既然高版本没有问题，那说明高版本肯定是正确的重置了这个buffer，那我们就继续debug下高版本的，定位下是在哪儿、怎么重置的这个buffer，最终定位到在5.2.1中AsyncHttpRequestRetryExec的第132行调用了releaseResources，releaseResources实际上最终调用到了我们传入的`org.apache.hc.core5.http.nio.AsyncRequestProducer`接口实现的releaseResources方法中重置了buffer的position，传入的AsyncRequestProducer接口实现代码如下：

```
        new BasicRequestProducer(httpRequest, entity == null ? null : new AsyncEntityProducer() {
            @Override
            public boolean isRepeatable() {
                return entity.isRepeatable();
            }

            @Override
            public void failed(final Exception cause) {

            }

            @Override
            public long getContentLength() {
                return entity.getContentLength();
            }

            @Override
            public String getContentType() {
                return entity.getContentType();
            }

            @Override
            public String getContentEncoding() {
                return entity.getContentEncoding();
            }

            @Override
            public boolean isChunked() {
                return entity.isChunked();
            }

            @Override
            public Set<String> getTrailerNames() {
                return entity.getTrailerNames();
            }

            @Override
            public int available() {
                return Integer.MAX_VALUE;
            }

            @Override
            public void produce(final DataStreamChannel channel) throws IOException {
                channel.write(buffer);
                // 写出完毕
                if (buffer.remaining() <= 0) {
                    channel.endStream();
                }
            }

            @Override
            public void releaseResources() {
                buffer.flip();
            }
        })

```

在releaseResources方法实现中重置了position；至于为什么要在这里重置而不是其他地方，这个可以参考`org.apache.hc.core5.http.nio.AsyncRequestProducer`接口上`isRepeatable`方法的javadoc,明确说明了重试时会调用`releaseResources`；

至此，问题的跟因也被我们找到了，然后就是定位具体问题修复的版本号，好在内部统一排查雷系问题，我看了提交记录，发现最早是在5.1.3版本中修复的，只需要升级到该版本或者该版本之上即可，对应的PR: https://github.com/apache/httpcomponents-client/pull/343 ，有兴趣的可以看下；


## 思考复盘
导致这个事故的问题解决了，这很重要，更重要的是如何避免下次发生，针对此类问题，我们可以做如下优化：

- 对于controller中的同步三方调用，要尽可能的设置较短的超时时间，建议1-3秒，避免因为三方调用响应过慢导致我们自己的系统挂掉（tomcat线程池被大量占用）；
- 对于数据库，实际上也有一个连接获取等待超时的参数，建议设置为一个较小的值，推荐1-3秒，防止因为慢sql占用连接导致的服务假死；
- 对于系统中关键调用，需要做详细的压测，并根据压测结果限流，特别是对于较慢的三方调用，如果可能都做成异步的，必须同步调用的必须做限流处理；
- 问题排查时不能急，不要漏掉蛛丝马迹；

# 联系方式

- 微信：JoeKerouac
- 微信公众号：代码深度研究院（如搜不到可添加微信获取）
- GitHub：[https://github.com/JoeKerouac](https://github.com/JoeKerouac)

