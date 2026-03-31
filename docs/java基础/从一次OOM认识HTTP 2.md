# 从一次 OOM 认识 HTTP/2

服务 A 上线一段时间后，出现了 OOM（内存溢出），于是按照排查流程，对 JVM 堆进行 dump 并开始分析。

> 可以使用命令 `jmap -dump:format=b,file=<dump 文件名> <PID>` 对指定 JVM 进程进行堆转储。

拿到 dump 文件后，用 Eclipse MAT 打开分析，发现大量的 `byte[]` 数组，进一步查看后确认是 HTTP 缓冲区占用了内存，如下图所示：

![Eclipse MAT 分析图](../../resource/java基础/MAT分析图.jpg)

项目里确实用了 Apache HttpClient，所以第一时间定位到网络请求部分。结果发现每次发起请求时，都会新建一个 `HttpClient` 实例，且请求结束后未关闭。熟悉 Apache HttpClient 的人都知道：每个 `HttpClient` 都会维护一个连接池，目的是连接复用。但这里每次都新建 `HttpClient`，不仅失去了复用意义，请求结束也未关闭，最终造成了内存泄漏。

这段代码最初只是本地 `main` 方法里做验证用的，所以没问题。但后来直接复制到线上项目时，忘了把连接池抽出来做成类字段，结果导致每次调用都重复创建连接池。

最终解决也很简单：把连接池提取成类中的字段，在类被实例化成 Bean 时初始化连接池，在 Bean 销毁时关闭连接池。

本以为问题到此结束，但从 MAT 的堆栈分析中又发现了另一个问题：上图中显示的 Output Buffer 单个就有 16 MB，但实际上我在代码里明确设置过输出缓冲区大小只有 8 KB，为什么没生效？

接下来我写了段本地代码，配合 Debug 继续排查。最开始调试时，`org.apache.hc.core5.http2.impl.nio.AbstractH2StreamMultiplexer#outputBuffer` 中的 Buffer 确实是我设置的 8 KB，但当收到响应时，这个字段已经变成了 16 MB。

查看这个字段对应的类 `org.apache.hc.core5.http2.impl.nio.FrameOutputBuffer`，发现里面有个 `expand` 方法会动态扩容。我在这里打了断点，最终发现是收到了服务端的一个报文，解析出 Buffer 大小为 16 MB，然后把本地 Output Buffer 调整成了这个大小。

这个报文就是 HTTP/2 中的 `SETTINGS frame`。下面我们就系统地认识一下 HTTP/2。

---

## HTTP/2

### HTTP/1.1 存在的问题

要理解为什么出现了 HTTP/2，先要看看 HTTP/1.1 的局限：

- 单连接内的请求必须串行（队头阻塞，Head-of-Line Blocking）。
- 建立多个 TCP 连接会增加连接和拥塞控制的额外开销。
- 请求头部冗余大（每次都传完整头，如 Cookie）。
- 不支持真正意义上的服务器推送。

### HTTP/2 的核心目标

HTTP/2 并没有“重新发明” HTTP：

- 保持语义兼容：URL、方法（GET/POST）、状态码、头字段与 HTTP/1.1 保持一致。
- 改变传输格式：从纯文本切换为二进制分帧，提升传输效率和灵活性。

核心目标：

- 降低延迟
- 更好地利用带宽
- 加快页面加载速度
- 对应用层无感知

### HTTP/2 的主要特性

#### 1. 二进制分帧（Binary Framing Layer）
- 核心思想是把请求和响应拆成更小的帧（Frame），在二进制层传输，而不是一次性发送完整报文。
- 每个帧属于某个流（Stream），每个流有唯一 ID。
- 常见帧类型：DATA、HEADERS、PRIORITY、RST_STREAM、SETTINGS、PUSH_PROMISE、PING、GOAWAY、WINDOW_UPDATE、CONTINUATION。

#### 2. 多路复用（Multiplexing）
- 同一个 TCP 连接可并发多个流（全双工）。
- 不同流的帧可以交错发送，对端根据 Stream ID 重组。
- 彻底解决了 HTTP/1.1 的队头阻塞。

#### 3. 流量控制（Flow Control）
- 类似 TCP，HTTP/2 在帧层面也支持流量控制（通过 WINDOW_UPDATE）。
- 可以对单个流和整个连接分别设置窗口大小，避免大文件独占带宽。

#### 4. 首部压缩（HPACK）
- HTTP/1.x 的头部是纯文本且重复度高（如 Cookie、User-Agent）。
- HTTP/2 使用 HPACK 算法（静态表 + 动态表）压缩：
  - 静态表：常见头字段的索引表。
  - 动态表：双方维护动态状态，后续相同字段可直接引用索引。
- 有效减少重复头部带宽开销。

#### 5. 服务器推送（Server Push）
- 服务器可主动推送客户端“可能需要”的资源，减少额外请求。
  - 例如：客户端请求 HTML，服务器可以直接推送 CSS 和 JS。
- 客户端可以拒绝推送（发送 RST_STREAM）。

#### 6. 优先级与依赖（Priority）
- 客户端可对流设置优先级和依赖，告诉服务器哪些资源更重要。
  - 例如：HTML 优先级高于图片。
- 服务器可据此动态调整资源传输顺序。

---

### 与 HTTP/1.1 的对比

| 特性    | HTTP/1.1 | HTTP/2 |
| ------- | -------- | ------ |
| 传输格式  | 文本       | 二进制   |
| 连接复用  | 不支持（多连接） | 单连接多流 |
| 队头阻塞  | 有         | 消除     |
| 头部压缩  | 无         | HPACK   |
| 服务器推送 | 无         | 有       |
| 请求优先级 | 无         | 有       |

### 现状

- HTTP/2 通常需要 HTTPS/TLS（主流浏览器要求只在 TLS 上启用）。
- 目前主流网站、CDN（如 Cloudflare、Akamai）、浏览器（Chrome、Firefox、Edge）都支持。
- ALPN（Application-Layer Protocol Negotiation）：TLS 扩展，用于协商使用 HTTP/1.1 还是 HTTP/2。

---

## Frame 详解

下面介绍 HTTP/2 的各类 Frame，先看交互时序图：

![HTTP/2 时序图](../../resource/java基础/http2时序图.png)

---

### DATA (0x00)

**作用**：  
在某个流上传输实际的 HTTP 请求/响应实体（Body）。

**特点**：
- Stream ID 必须非零，表示属于哪个流。
- 可以分片发送，比如一个大文件可拆分成多个 DATA 帧顺序发送。
- 有 `END_STREAM` 标志表示该流最后一个 DATA 帧。

**典型场景**：
- 客户端发送 POST 请求体。
- 服务器返回 HTML、JSON、文件等内容。

---

### HEADERS (0x01)

**作用**：  
用于发送 HTTP 头信息，如 `:method`、`:path`、`:status` 等。

**特点**：
- 必须是新流的起始帧（除非是推送或续帧）。
- 使用 HPACK 压缩，降低重复头部开销。
- 有 `END_HEADERS` 标志表示头块结束，如头太大可用 CONTINUATION 帧续传。
- 有 `END_STREAM` 标志，若无 Body，可直接结束流。

**典型场景**：
- 客户端发起 GET/POST 请求：HEADERS + 可选 DATA。
- 服务器返回响应状态和头：HEADERS + 可选 DATA。

---

### PRIORITY (0x02)

**作用**：  
告知对端当前流的优先级和依赖关系。

**特点**：
- 可单独发送，也可嵌入 HEADERS（用 PRIORITY 标志）。
- 包含依赖流 ID、是否独占（Exclusive）、权重（Weight）。
- 实现端可根据优先级调度传输顺序。

**典型场景**：
- 浏览器根据页面结构优先传 HTML，再传 CSS、图片。

---

### RST_STREAM (0x03)

**作用**：  
强制取消某个流，类似 TCP 的 `RST`。

**特点**：
- 包含错误码说明原因，如 `CANCEL`、`STREAM_CLOSED`。
- 双方任意一方都可发，立即终止该流并释放资源。

**典型场景**：
- 用户取消下载时，浏览器发送 RST_STREAM。

---

### SETTINGS (0x04)

**作用**：  
连接级别的参数协商，如帧大小、最大并发流数等。

**特点**：
- 连接初始化时必须交换（客户端发 Preface 后先发 SETTINGS）。
- Stream ID 必须是 0。
- 可包含多个参数，如：
  - `SETTINGS_MAX_CONCURRENT_STREAMS`
  - `SETTINGS_INITIAL_WINDOW_SIZE`
- 发送后对端需回复 ACK。

**实际可包含的参数**：
- `HEADER_TABLE_SIZE`：HPACK 动态表大小（单位：字节），默认 4096。值越大压缩率越高，但更耗内存。
- `ENABLE_PUSH`：是否允许服务器推送，默认 1（允许），0 表示禁用 Server Push。
- `MAX_CONCURRENT_STREAMS`：限制对端同时开多少并发流，防止资源耗尽。
- `INITIAL_WINDOW_SIZE`：每个流的初始窗口大小（单位：字节），默认 65535（64 KB）。
- `MAX_FRAME_SIZE`：单个帧最大允许大小（单位：字节），最小 16 KB，最大 16 MB。
- `MAX_HEADER_LIST_SIZE`：限制单次请求/响应头部字段总大小，防御恶意大头攻击。

> 我们遇到的 Buffer 扩容，就是因为服务端在 SETTINGS frame 里告诉客户端 `MAX_FRAME_SIZE`，客户端据此修改了本地 Output Buffer。

**SETTINGS 参数总结**

| 参数                       | 作用                  | 默认值 | 单位    |
| ------------------------ | ------------------- | ---- | ------ |
| HEADER_TABLE_SIZE        | HPACK 动态表大小         | 4096 | bytes  |
| ENABLE_PUSH              | 是否允许 Server Push | 1    | boolean |
| MAX_CONCURRENT_STREAMS   | 并发流上限              | 无    | streams |
| INITIAL_WINDOW_SIZE      | 每个流初始窗口           | 65535 | bytes  |
| MAX_FRAME_SIZE           | 单帧最大大小             | 16384 | bytes  |
| MAX_HEADER_LIST_SIZE     | 头部字段总大小上限         | 无    | bytes  |

---

### PUSH_PROMISE (0x05)

**作用**：  
服务器声明将要推送一个资源。

**特点**：
- 由服务器发送，属于现有流。
- 告诉客户端后面会用新流 ID 主动推送该资源。
- 带有被推送资源的伪头字段，如 `:path`、`:method`。

**典型场景**：
- 服务器响应 HTML 时，顺便推送 CSS、JS。

---

### PING (0x06)

**作用**：  
探测对端是否活跃、测量 RTT、KeepAlive。

**特点**：
- Stream ID 必须是 0（连接级别）。
- 固定 8 字节可选数据，收端必须原样返回。
- 有 ACK 标志区分请求与响应。

**典型场景**：
- 保活探测，快速检测连接是否断开。

---

### GOAWAY (0x07)

**作用**：  
优雅关闭连接，告知对端不要再新开流。

**特点**：
- 连接级别，Stream ID = 0。
- 包含最后一个已处理的流 ID、错误码和可选调试信息。
- 不影响已存在的流，继续处理完，但禁止新流。

**典型场景**：
- 服务器升级、维护、优雅下线。

---

### WINDOW_UPDATE (0x08)

**作用**：  
流量控制核心帧，告知对端可以继续发送更多字节。

**特点**：
- 可针对连接（ID=0）或单个流（ID>0）。
- 包含一个增量值（扩充流量窗口），最大 2³¹-1。
- 防止单个流或连接独占所有带宽或内存。

**典型场景**：
- 客户端处理完部分数据后，告知服务器可以继续发送。

---

### CONTINUATION (0x09)

**作用**：  
用于续传过大的头块。

**特点**：
- 紧跟在 HEADERS 或 PUSH_PROMISE 后。
- 头块必须连续，用 `END_HEADERS` 标志结束。
- Stream ID 必须一致。

**典型场景**：
- 请求头或响应头很大（如带大 Cookie）。

---

## Frame 总结

| Frame          | 作用                 | 是否流相关 |
| -------------- | -------------------- | ---------- |
| DATA           | 承载 Body            | 是         |
| HEADERS        | 承载头部/新流开始     | 是         |
| PRIORITY       | 优先级调度           | 是         |
| RST_STREAM     | 中断流               | 是         |
| SETTINGS       | 协商连接参数         | 否         |
| PUSH_PROMISE   | 服务器推送声明       | 是         |
| PING           | 探活 RTT             | 否         |
| GOAWAY         | 优雅关闭连接         | 否         |
| WINDOW_UPDATE  | 流量控制             | 视情况而定 |
| CONTINUATION   | 大头块续传           | 是         |

---

## 问题确认
最终，我们也知道了是因为使用了http/2协议，客户端和服务端建立连接时约定了MAX_FRAME_SIZE为16M，导致本地output buffer被重新设置为了16M，而不是我们预设的8K，因为http/2协议本身链接也是复用的，所以实际上我们的连接池数量也可以设置小一点儿了（注意，如果仍然像之前那样设置，比如设置200个链接，那么仅仅output buffer就会占用3200M的内存，这是一个很大的开销）；


# 联系我
- 作者微信：JoeKerouac
- 微信公众号（文章会第一时间更新到公众号，如果搜不出来可能是改名字了，加微信即可=_=|）：代码深度研究院
- GitHub：https://github.com/JoeKerouac

