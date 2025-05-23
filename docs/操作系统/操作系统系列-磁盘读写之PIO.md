# 别再只会读文件了，操作系统是这样读磁盘的！

在我们开发操作系统时，BIOS 会将磁盘的第一个扇区加载到内存中并执行其中的代码。显然，一个操作系统不可能只占用一个扇区的空间，因此我们必须继续从磁盘读取数据。那么，如何从磁盘读取数据呢？本文将介绍如何使用
PIO（Programmed I/O）模式从磁盘中读取数据。

## 磁盘小知识

一个硬盘通常由：

- **多个盘片（Platters）**：类似光盘的圆形盘片，用于存储数据。
- **每个盘片有两个面**：上下两面均可存储数据。
- **每个面上有多个磁道（Track）**：类似树的年轮，是同心圆的分布。
- **磁道被划分为多个扇区（Sector）**：扇区是硬盘的最小存储单位。
- **磁头（Head）**：用于读取/写入磁道上的数据。
- **柱面（Cylinder）**：所有盘片上相同位置的磁道集合。
- **扇区（Sector）**：数据的基本读写单位，早期大小通常为 512 字节，现代硬盘通常为 4KB。

![img.png](../../resource/操作系统/磁盘CHS图.png)

## 如何对磁盘寻址

磁盘数据的寻址方式主要有两种：

- **CHS（Cylinder-Head-Sector）**：通过cylinder（柱面）、head（磁头）、sector（扇区）三元组来定位，较为复杂。
- **LBA（Logical Block Addressing）**：将所有扇区编号，从 0 开始按顺序访问，使用更简单。

LBA 又分为两种版本：

- **LBA28**：使用 28 位地址线，最多可寻址 128GB（2^28 × 512 字节）。
- **LBA48**：使用 48 位地址线，最大可寻址 128PB（2^48 × 512 字节）。

## 如何使用PIO读取磁盘

### 理论知识

> PIO 模式在数据传输过程中严重依赖 CPU，因为每一个字节的传输都需要通过 CPU 的 I/O 端口完成，而不是直接传输到内存。在某些
> CPU 上，PIO 模式下的传输速度可达每秒 16MB，但会严重影响其他进程的执行。


一个硬盘控制器通常提供两个 ATA 总线：

- **Primary ATA Bus（主通道）**
- **Secondary ATA Bus（副通道）**

每个通道最多连接两个设备（主设备、从设备），因此一个控制器最多可控制 4 个 IDE 设备。

> 注意，这里的主通道、副通道，主设备、从设备实际上并没有主从关联性，只不过以前习惯于叫master、slave；现在因为某些原因，技术上通常会避开master、slave的叫法；

### 控制端口分布

每个 ATA 总线有 10 个标准端口：

- **8 个控制端口：**
    - 主通道地址：`0x1F0` ~ `0x1F7`
    - 副通道地址：`0x170` ~ `0x177`
- **2 个设备控制/备用状态端口：**
    - 主通道：`0x3F6` ~ `0x3F7`
    - 副通道：`0x376` ~ `0x377`

#### 控制端口功能一览

| 偏移 | 读/写方向 | 寄存器名               | 描述                             | 大小 LBA28/LBA48 |
|----|-------|--------------------|--------------------------------|----------------|
| 0  | R/W   | 数据寄存器              | 读/写 PIO 数据字节                   | 16 位 / 16 位    |
| 1  | R     | 错误寄存器              | 用于检索上次执行的 ATA 命令生成的任何错误        | 8 位 / 16 位     |
| 1  | W     | 功能寄存器              | 用于控制特定命令接口功能                   | 8 位 / 16 位     |
| 2  | R/W   | 扇区计数寄存器            | 要读/写的扇区数（0 是一个特殊值）             | 8 位 / 16 位     |
| 3  | R/W   | 扇区号寄存器（LBA lo）     | 这是针对 CHS / LBA28 / LBA48 的特定内容 | 8 位 / 16 位     |
| 4  | R/W   | 磁头低位寄存器 /（LBA mid） | 部分磁盘扇区地址                       | 8 位 / 16 位     |
| 5  | R/W   | 磁头高位寄存器 /（LBA hi）  | 部分磁盘扇区地址                       | 8 位 / 16 位     |
| 6  | R/W   | 驱动器/磁头寄存器          | 用于选择驱动器和/或磁头。支持额外的地址/标志位       | 8 位 / 8 位      |
| 7  | R     | 状态寄存器              | 用于读取当前状态                       | 8 位 / 8 位      |
| 7  | W     | 命令寄存器              | 用于向设备发送 ATA 命令                 | 8 位 / 8 位      |

> 这里IO端口号偏移是基于最小控制端口的偏移量

#### 设备控制寄存器功能

| 偏移 | 读/写方向	 | 寄存器名      | 描述               | 大小 LBA28/LBA48 |
|----|--------|-----------|------------------|----------------|
| 0  | R      | 替代状态寄存器	  | 状态寄存器的副本，但不会触发中断 | 8-bit / 8-bit  |
| 0  | W      | 设备控制寄存器	  | 用于复位总线或启用/禁用中断	  | 8-bit / 8-bit  |
| 1  | R      | 驱动器地址寄存器	 | 提供驱动器选择和磁头选择信息	  | 8-bit / 8-bit  |

> 这里IO端口号偏移是基于最小设备控制端口的偏移量


#### 错误寄存器位定义

| 位 (Bit) | 缩写 (Abbreviation) | 描述 (Function)                       |
|---------|-------------------|-------------------------------------|
| 0       | AMNF              | 未找到地址标记（Address mark not found）     |
| 1       | TKZNF             | 未找到0号磁道（Track zero not found）       |
| 2       | ABRT              | 命令已中止（Aborted command）              |
| 3       | MCR               | 请求更换介质（Media change request）        |
| 4       | IDNF              | 未找到ID（ID not found）                 |
| 5       | MC                | 介质已更换（Media changed）                |
| 6       | UNC               | 不可纠正的数据错误（Uncorrectable data error） |
| 7       | BBK               | 检测到坏块（Bad Block detected）           |


### 示例代码：PIO 读取一个扇区

下面给出一个PIO模式读取磁盘的示例代码：

> 注意，示例中写死了使用主通道，主设备；

```c

static inline void outb(uint16_t port, uint8_t data) {
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
}

static inline void insl(uint32_t port, void *addr, uint32_t cnt) {
    // insl指令应该是att特有的语法，Intel中是insd
    asm volatile (
        "cld;"
        "repne; insl;"
        : "=D" (addr), "=c" (cnt)
        : "d" (port), "0" (addr), "1" (cnt)
        : "memory", "cc");
}

/**
 * @brief 等待磁盘ready
 * 
 */
static void waitdisk(void) {
    while ((inb(0x1F6) & 0xC0) != 0x40)
        /* do nothing */;
}

/**
 * @brief 以PIO的方式读取一个扇区，扇区号使用LBA编码
 * 
 * @param dst 目标地址
 * @param secno 读取的扇区号，LBA，扇区号从0开始
 */
static void readsect(void *dst, uint32_t secno) {
    waitdisk();

    // 读取master固定写出0x40，slave写出0x50
    // 01000000b - bit6设为1表示LBA模式，bit4设为0表示主盘
    outb(0x1f6, 0x40);
    
    outb(0x1f2, 0);
    // LBA[31:24]
    outb(0x1f3, (secno >> 24) & 0xff);
    // 因为我们的secno实际是32位的，所以这里实际上应该固定是0
    // LBA[39:32]
    outb(0x1f4, 0);
    // LBA[47:40]
    outb(0x1f5, 0);

    outb(0x1f2, 1);
    // LBA[7:0]
    outb(0x1f3, secno & 0xff);
    // LBA[15:8]
    outb(0x1f4, (secno >> 8) & 0xff);
    // LBA[23:16]
    outb(0x1f5, (secno >> 16) & 0xff);

    // 48bit LBA读取命令
    outb(0x1f7, 0x24);

    // 等待磁盘ready
    waitdisk();
    // 开始从0x1f0端口读数据
    insl(0x1f0, dst, SECTSIZE / 4);
}

```

# 联系我

- 作者微信：JoeKerouac
- 微信公众号（文章会第一时间更新到公众号，如果搜不出来可能是改名字了，加微信即可=_=|）：代码深度研究院
- GitHub：https://github.com/JoeKerouac


