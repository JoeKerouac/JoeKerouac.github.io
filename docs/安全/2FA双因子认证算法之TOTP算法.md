# 2FA双因子认证之OTP算法
## 概述
2 Factor Authentication简称2FA，双因子认证是一种安全密码验证方式。区别于传统的密码验证，由于传统的密码验证是由一组静态信息组成，如：字符、图像、手势等，很容易被获取，相对不安全。2FA是基于时间、历史长度、实物（信用卡、SMS手机、令牌、指纹）等自然变量结合一定的加密算法组合出一组动态密码，一般每60秒刷新一次。不容易被获取和破解，相对安全。

TOTP/HOTP作为其中的一种（实际是两种，不过其中一个是变种，这里当作一种）算法，目前已经用于大多数网站，例如GitHub、阿里云等；

## HOTP
### 算法考虑因素

- 算法必须是基于序列或者计数的；
- 该算法在硬件上应该是经济的（对硬件要求不高）；
- 该算法必须适用于不支持任何数字输入的令牌，但也可以用于更复杂的设备，例如PIN-pads；
- 用户必须能轻松读取和输入令牌上显示的值，这需要HOTP值长度合理；HOTP应该至少为6位，并且仅包含数字，这样可以方便的在受限设备上输入；
- 必须具有用户友好的机制用来重新同步计数器；
- 该算法必须使用强共享密钥，共享密钥的长度必须至少为128位，建议160位；

### 符号定义

- 如果s表示字符串，那么 | s | 表示他的长度，如果s表示数字，那么 | s | 表示他的绝对值；
- 如果s表示字符串，那么s[i]表示他的第i位（从0开始）；
- StToNum（String to Number）函数表示将入参转换为数字，入参是数字的二进制表示，例如 StToNum(110) = 6
- C：8byte计数器，移动因子（moving factor），这个counter必须能在HOTP客户端与服务端同步；
- K：客户端与服务端共享密钥，每个HOTP生成器都有一个不同且唯一的密钥；
- T：T次校验失败后服务器将拒绝该用户；
- s：服务器将尝试通过s个连续的计数器值进行验证；
- Digit：HOTP值的位数，系统参数；


### 算法详解

算法定义如下：
```
HOTP(K, C) = Truncate(HMAC-SHA-1(K, C))
```

算法说明：

要产生HOTP值，要经过下面三个步骤：
- 生成HMAC-SHA-1值HS = HMAC-SHA-1(K, C)；HS是20byte长的String；
- 使用HS生成4byte长的String Sbits = DT(HS)，DT函数在后边定义，返回一个31bit的String；
- 计算HOTP值，Snum = StToNum(Sbits)；return D = Snum mod 10^Digit；

> Truncate函数就是执行步骤2和步骤3，即动态截断，动态截断技术是从20byte的HMAC-SHA-1结果中提取4byte

DT函数定义：DT(String)：  // String = String[0]….String[19]，入参的长度是20byte，因为HMAC-SHA-1的结果长度是20byte；
- OffsetBits表示String[19]的低4位；
- Offset = StToNum(OffsetBits)；PS： 因为OffsetBits只有4位，所以Offset的范围是0 - 15；
- P = String[Offset]…String[Offset+3]；
- return P的低31位（这里返回31位而不是32位的原因是因为最高位在有符号数和无符号数上解释是不一样的，可能会造成混淆，而屏蔽掉最高位可以消除歧义）


## TOTP
### 概述
TOTP算法实际上是HOTP算法的一个变种，，HOTP算法中定义了一个8byte计数器`C`，需要能在服务器和客户端同步，但是没有定义具体如何实现`C`，而TOTP则是进一步详细定义了如何实现这个8byte的计数器`C`，TOTP中使用时间引用（time reference）和时间步长（time step）派生的值作为`C`值，同时TOTP中可以使用`HMAC-SHA-256`或者`HMAC-SHA-512`来替换`HMAC-SHA-1`；

### 算法考虑因素

设计TOTP算法时必须要考虑如下几个因素：
- prover（例如令牌、软令牌，指的就是用户使用的某种客户端）和verifier（验证者，服务器端）能够获取比较准确的Unix时间（即从UTC 1970年1月1日午夜以来经过的秒数）；
- prover和verifier必须具有相同的secret或者知道如何通过共享secret推导出secret；
- 算法必须使用HOTP作为关键构建模块；
- prover和verifier必须使用相同的时间步长（time step）；
- 每个prover必须有一个唯一的secret（key）；
- 密钥（keys、secret）应该随机生成或者使用密钥生成算法生成；
- 密钥（key）可以存储在防篡改设备中，应该是防止未授权的访问和使用；


### 算法详解

TOTP算法定义：
```
TOTP = HOTP(K, T)
```

详细说明：
- 其中`T = (Current Unix Time -T0) / X `，这里计算中结果默认向下取整，丢弃小数部分； 
- 该算法的实现必须支持时间值T在2038年之后大于32位整数的情况（可以通过调整X和T0的值来实现，或者到时候使用其他解决方案）； 
- 该算法的安全性取决于HOTP算法的安全性，分析表明，对于该算法的最佳破解手段就是暴力破解（即遍历）； 
- 时间步长不应该太长，也不应该太短，太长的话会使攻击变得简单（攻击者有更多时间实施攻击），太短的话会对性能有影响；因为verifier不知道prover使用的时间戳，在经过网络延迟以及其他延迟后，可能导致prover使用的时间戳落入的步长区间与verifier使用的时间戳落入的步长区间不一致，导致最终的T值不一致，此时我们可以允许verifier多使用一个步长作为延迟，但是不建议更多，因为这会间接导致实际的时间步长变长，使攻击变得简单；


## 参考文档
- RFC6238

## 参考JS实现
```

class TOTP {

    // 步长
    #X;
    // 初始时间偏移，单位秒
    #T0;
    // hmacSha1算法
    #hmacSha1;

    /**
     * 构造器
     * @param key 密钥，8位数字数组，必传
     * @param X 步长，默认30
     * @param T0 初始时间偏移，单位秒，默认0
     */
    constructor(key, X, T0) {
        if (key == null) {
            throw "密钥不能为空";
        }

        if (!(key instanceof Array)) {
            throw "密钥必须是数组";
        }

        if (X == null || X <= 0) {
            X = 30;
        }

        if (T0 == null || T0 < 0) {
            T0 = 0;
        }

        this.#X = X;
        this.#T0 = T0;
        this.#hmacSha1 = new HMAC(new SHA1(), 20, 64);
        this.#hmacSha1.init(key);
    }

    /**
     * 校验给定的TOTP value是否合法
     * @param value 给定的TOTP value
     * @returns {boolean} true表示合法
     */
    verify(value) {
        if (value == null || typeof value != "string") {
            throw "参数错误，参数必须是string; " + value == null ? "null" : typeof value;
        }

        return this.generateTOTPValue(value.length) === value;
    }

    /**
     * 生成TOTP value
     * @param returnDigits 结果长度，默认6
     * @param unixTime Unix日期，默认取当前时间
     * @returns {string} TOTP value
     */
    generateTOTPValue(returnDigits, unixTime) {
        if (returnDigits == null || returnDigits <= 0) {
            returnDigits = 6;
        }

        if (unixTime == null || unixTime <= 0) {
            unixTime = Math.round(new Date().getTime() / 1000);
        }

        let T = Math.floor((unixTime - this.#T0) / this.#X);

        let data = [];
        data[0] = 0;
        data[1] = 0;
        data[2] = 0;
        data[3] = 0;
        data[4] = T >>> 24 & 0xff;
        data[5] = T >>> 16 & 0xff;
        data[6] = T >>> 8 & 0xff;
        data[7] = T >>> 0 & 0xff;

        let hash = this.#hmacSha1.doFinal(data);

        let offset = hash[hash.length - 1] & 0xf;

        let binary = ((hash[offset] & 0x7f) << 24) | ((hash[offset + 1] & 0xff) << 16)
            | ((hash[offset + 2] & 0xff) << 8) | (hash[offset + 3] & 0xff);


        let otp = binary % Math.pow(10, returnDigits);

        let result = otp.toString();
        while (result.length < returnDigits) {
            result = "0" + result;
        }

        return result;
    }

}


/*
 * TOTP使用示例，注意，TOTP依赖与HMAC算法，HMAC算法请参考前一篇文章，前一篇文章中有HMAC算法的JS示例代码
 */
// 使用示例：指定步长位30，偏移为0
let totp = new TOTP([0, 0, 0, 0], 30, 0);
// 生成6位的TOTP value
let totpValue = totp.generateTOTPValue(6);
console.log(totpValue);
```

# 联系我
- 作者微信：JoeKerouac
- 微信公众号（文章会第一时间更新到公众号）：代码深度研究院
- GitHub：https://github.com/JoeKerouac


