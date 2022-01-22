/**
 * SHA1摘要算法
 *
 * 注意：该类实例非线程安全
 * @author JoeKerouac
 */
class SHA1 {

    #H = [];
    #W = [];
    // 块大小，单位byte（8bit）
    #BLOCK_SIZE = 64;

    // 已经处理过的bit数
    #processLen = 0;
    // 缓冲区
    #buffer = [];

    constructor() {
        this.resetState();
    }

    /**
     * 将指定数据从指定位置更新指定长度到摘要中
     * @param data 要更新到摘要信息中的数据，8位数字数组，允许为空
     * @param offset 更新到摘要中的数据起始位置，允许为空
     * @param len 更新到摘要中的数据长度，允许为空
     */
    update(data, offset, len) {
        if (data == null) {
            return;
        }

        if (offset == null) {
            offset = 0;
        }

        if (len == null) {
            len = data.length;
        }

        if (len === 0) {
            return;
        }

        if (offset < 0 || offset >= data.length || (offset + len) > data.length) {
            throw "参数错误，当前数组长度：" + data.length + "; offset=" + offset + "; len=" + len;
        }

        const bufferLen = this.#buffer.length;
        // loop用于作为指针，指向当前data数据中待处理的数据起始位置
        let loop = this.#BLOCK_SIZE - bufferLen;
        // 记录当前数据填充到buffer后是否需要处理，true表示不需要
        const flag = loop > len;
        loop = flag ? len : loop;
        // 加上偏移
        loop += offset;

        // 如果buffer中已经有数据或者本次新增数据不足一个block时优先填充buffer，否则直接使用传入的data进行处理，节省一次copy
        if (bufferLen !== 0 || len < this.#BLOCK_SIZE) {
            // 优先填充buffer
            for (let i = offset; i < loop; i++) {
                this.#buffer[bufferLen + i] = data[i];
            }

            // 新增data加上buffer的数据不够一个block，直接返回
            if (flag) {
                return;
            }

            // 此时buffer中的数据已经满一个block了，先处理buffer中的数据
            this.#process(this.#buffer, 0);
            this.#buffer.length = 0;
        } else {
            // 此时需要重置指针，因为初始化的时候将指针指向了填充完buffer后的位置
            loop = offset;
        }

        // 如果data中剩余的数据超过了一个block，那么继续处理data中的数据
        let processLoop = Math.floor((len - loop + offset) / this.#BLOCK_SIZE);
        for (let i = 0; i < processLoop; i++) {
            this.#process(data, loop);
            loop = loop + (i + 1) * this.#BLOCK_SIZE;
        }

        // 最后，处理完毕后如果data中还有数据，将其copy到buffer中
        processLoop = len - loop + offset;
        for (let i = 0; i < processLoop; i++, loop++) {
            this.#buffer[i] = data[loop];
        }
    }

    /**
     * 将指定数据从指定位置更新指定长度到摘要中并获取摘要结果
     *
     * @param data 要更新到摘要信息中的数据，8位数字数组，允许为空
     * @param offset 更新到摘要中的数据起始位置，允许为空
     * @param len 更新到摘要中的数据长度，允许为空
     * @return {*[]} 计算结果，8位无符号数字数组，长度固定20
     */
    digest(data, offset, len) {
        this.update(data, offset, len);

        let bufferLen = this.#buffer.length;
        // 原始数据长度
        const originValueLen = this.#processLen + bufferLen * 8;

        if (originValueLen <= 0) {
            throw "当前没有任何待计算摘要的数据，请先调用update(data)或者digest(data)";
        }

        this.#buffer[bufferLen] = 128;

        // 如果长度已经不足9了，需要在下一个block中写入长度，这个block后续全部填充0
        if ((this.#BLOCK_SIZE - bufferLen) < 9) {
            for (let i = bufferLen + 1; i < this.#BLOCK_SIZE; i++) {
                this.#buffer[i] = 0;
            }

            // 把本block处理掉
            this.#process(this.#buffer, 0);
            // 重置bufferLen
            bufferLen = 0;
            // 后边会跳过这条记录，所以在这里把buffer的第一个数据设置为0
            this.#buffer[0] = 0;
        }

        // 从bufferLen + 1处开始填0
        for (let i = bufferLen + 1; i < (this.#BLOCK_SIZE - 8); i++) {
            this.#buffer[i] = 0;
        }

        /*
         * 将原始数据长度写出；处理逻辑说明：
         * 1、js中数字都是64位的，其中0-51位存储数字，52-62存储指数，63位存储符号，这里我们的长度肯定是大于0的，符号位也可以忽略，所以高12位要丢弃
         * 2、js中位运算是使用会自动将数字转换为32位有符号值，高32位直接被丢弃了，所以高32位要特殊处理
         */

        // 高32位
        let highValue = originValueLen / Math.pow(2, 32);
        // 高12位要丢弃，这里丢弃8位，后边丢弃4位
        this.#buffer[this.#BLOCK_SIZE - 8] = 0;
        // 丢弃高4位
        this.#buffer[this.#BLOCK_SIZE - 7] = highValue >>> 16 & 0xf
        this.#buffer[this.#BLOCK_SIZE - 6] = highValue >>> 8 & 0xff
        this.#buffer[this.#BLOCK_SIZE - 5] = highValue & 0xff

        // 处理低32位
        this.#buffer[this.#BLOCK_SIZE - 4] = originValueLen >>> 24 & 0xff
        this.#buffer[this.#BLOCK_SIZE - 3] = originValueLen >>> 16 & 0xff
        this.#buffer[this.#BLOCK_SIZE - 2] = originValueLen >>> 8 & 0xff
        this.#buffer[this.#BLOCK_SIZE - 1] = originValueLen & 0xff


        this.#process(this.#buffer, 0);

        let result = [];

        for (let i = 0; i < 5; i++) {
            let value = this.#H[i];
            result[i * 4] = value >>> 24 & 0xff
            result[i * 4 + 1] = value >>> 16 & 0xff
            result[i * 4 + 2] = value >>> 8 & 0xff
            result[i * 4 + 3] = value & 0xff
        }
        this.resetState();
        return result;
    }

    /**
     * 重置状态
     */
    resetState() {
        this.#processLen = 0;
        //this.#buffer.length = 0;
        this.#buffer = [];
        this.#W = [];
        this.#H[0] = 0x67452301 | 0;
        this.#H[1] = 0xEFCDAB89 | 0;
        this.#H[2] = 0x98BADCFE | 0;
        this.#H[3] = 0x10325476 | 0;
        this.#H[4] = 0xC3D2E1F0 | 0;
    }

    /**
     * 处理数据指定起始位置开始的一个block
     *
     * @param data 待处理的数据（8位数字数组）
     * @param offset 起始位置
     */
    #process(data, offset) {
        this.#processLen += 512;
        let i, t;

        for (i = 0; i < 16; i++) {
            this.#W[i] = (data[offset + i * 4] & 0xff) << 24 | (data[1 + offset + i * 4] & 0xff) << 16 | (data[2 + offset + i * 4] & 0xff) << 8 | (data[3 + offset + i * 4] & 0xff);
        }

        for (t = 16; t < 80; t++) {
            // W(t-3) XOR W(t-8) XOR W(t-14) XOR W(t-16)
            let value = this.#W[t - 3] ^ this.#W[t - 8] ^ this.#W[t - 14] ^ this.#W[t - 16];
            this.#W[t] = value << 1 | value >>> 31;
        }

        let temp;
        let A = this.#H[0];
        let B = this.#H[1];
        let C = this.#H[2];
        let D = this.#H[3];
        let E = this.#H[4];

        // TEMP = S^5(A) + f(t;B,C,D) + E + W(t) + K(t);
        for (t = 0; t < 20; t++) {
            temp = (A << 5 | A >>> 27) + ((B & C) | (~B & D)) + E + this.#W[t] + 1518500249;

            E = D;
            D = C;
            C = B << 30 | B >>> 2;
            B = A;
            A = temp | 0;
        }

        for (t = 20; t < 40; t++) {
            temp = (A << 5 | A >>> 27) + (B ^ C ^ D) + E + this.#W[t] + 1859775393;

            E = D;
            D = C;
            C = B << 30 | B >>> 2;
            B = A;
            A = temp | 0;
        }

        for (t = 40; t < 60; t++) {
            temp = (A << 5 | A >>> 27) + (B & C | B & D | C & D) + E + this.#W[t] - 1894007588;

            E = D;
            D = C;
            C = B << 30 | B >>> 2;
            B = A;
            A = temp | 0;
        }

        for (t = 60; t < 80; t++) {
            temp = (A << 5 | A >>> 27) + (B ^ C ^ D) + E + this.#W[t] - 899497514;

            E = D;
            D = C;
            C = B << 30 | B >>> 2;
            B = A;
            A = temp | 0;
        }
        this.#H[0] = (this.#H[0] + A) | 0;
        this.#H[1] = (this.#H[1] + B) | 0;
        this.#H[2] = (this.#H[2] + C) | 0;
        this.#H[3] = (this.#H[3] + D) | 0;
        this.#H[4] = (this.#H[4] + E) | 0;
    }
}





/**
 * HMAC摘要认证算法，除了可以获取摘要信息外，消息还自带认证信息，具有防篡改功能，接收方可以使用密钥验证摘要是否被篡改；
 *
 * 注意：该类实例非线程安全
 *
 * @author JoeKerouac
 */
class HMAC {

    // 摘要算法对象，参考SHA1实现，必须要有update(data, offset, len)和digest(data, offset, len)这两个方法
    #digest;
    // 上边的摘要对象摘要结果的长度（单位byte，8bit）
    #hashSize;
    // block大小，除了HMAC-SHA-384是128以外其他都是64
    #blockLen;
    // 初始化标志，true表示已经初始化
    #init;
    // 当前是否是第一次更新
    #first;
    // 对应算法中的K XOR ipad
    #k_ipad;
    // 对应算法中的K XOR opad
    #k_opad;

    /**
     * @param digest 摘要算法对象，参考SHA1实现，必须要有update(data, offset, len)和digest(data, offset, len)这两个方法
     * @param hashSize 上边的摘要对象摘要结果的长度（单位byte，8bit）
     * @param blockLen block大小，除了摘要算法为HMAC-SHA-384时是128以外其他都是64
     */
    constructor(digest, hashSize, blockLen) {
        this.#digest = digest;
        this.#hashSize = hashSize;
        this.#blockLen = blockLen;
        this.#init = false;
        this.#first = true;
        this.#k_ipad = [];
        this.#k_opad = [];
    }

    /**
     * 重置状态
     */
    resetState() {
        if (!this.#first) {
            this.#digest.resetState();
            this.#first = true;
        }
    }

    /**
     * 使用指定密钥初始化
     *
     * @param key 密钥，8位数字数组
     */
    init(key) {
        if (key == null) {
            throw "Missing key data";
        }

        this.resetState();

        let keyClone = key.slice();

        // 对key生成摘要
        if (keyClone.length > this.#blockLen) {
            let digest = this.#digest.digest(keyClone);
            // 尽快将内存中的key清空，防止密钥泄漏
            keyClone.fill(0);
            keyClone = digest;
        }

        // 根据rfc2104生成k_ipad和k_opad
        for (let i = 0; i < this.#blockLen; i++) {
            let k = i < keyClone.length ? keyClone[i] : 0;
            this.#k_ipad[i] = k ^ 0x36 & 0xff;
            this.#k_opad[i] = k ^ 0x5C & 0xff;
        }

        // 将内存中的数据尽快清空
        keyClone.fill(0);
        this.#init = true;
    }

    /**
     * 追加数据
     *
     * @param data 8位数字数组
     * @param offset 要使用的数据起始位置
     * @param len 长度
     */
    update(data, offset, len) {
        if (!this.#init) {
            throw "HMAC未初始化，请先初始化";
        }

        if (data == null) {
            return;
        }

        if (offset == null) {
            offset = 0;
        }

        if (len == null) {
            len = data.length;
        }

        if (this.#first) {
            this.#digest.update(this.#k_ipad);
            this.#first = false;
        }

        this.#digest.update(data, offset, len);
    }

    /**
     * 将指定数据追加到摘要并获取结果
     * @param data 8位数字数组
     * @param offset 要使用的数据起始位置
     * @param len 长度
     * @returns {*[]} 结果，8位数字数组
     */
    doFinal(data, offset, len) {
        if (!this.#init) {
            throw "HMAC未初始化，请先初始化";
        }

        this.update(data, offset, len);

        if (this.#first) {
            this.#digest.update(this.#k_ipad);
        } else {
            this.#first = true;
        }

        let result = this.#digest.digest();
        this.#digest.update(this.#k_opad);
        this.#digest.update(result);
        result = this.#digest.digest();
        return result;
    }

}

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
 * HMAC使用示例
 */
// 定义密钥
let key = [0, 29, 39, 48, 93, 85, 34, 85, 9, 74, 52, 75, 132, 201, 139, 103];
// 定义要摘要的数据
let msg = "Hello";
let data = [];
// 将要摘要的数据转换为byte数组
for (let i = 0; i < msg.length; i++) {
    data[i] = msg.charCodeAt(i);
}

// 声明算法为HMAC-SHA-1，如果要使用其他hash算法的实现请自行实现对应的hash算法，例如SHA-256
let hmacSha1 = new HMAC(new SHA1(), 20, 64);
// 只要key不变，这里只需要初始化一遍即可
hmacSha1.init(key);
// 计算data的hmac值，使用HMAC-SHA-1，结果是一个byte数组
let hmacArr = hmacSha1.doFinal(data);
console.log(hmacArr.toString());




/*
 * TOTP使用示例
 */
// 使用示例：指定步长位30，偏移为0
let totp = new TOTP([0, 0, 0, 0], 30, 0);
// 生成6位的TOTP value
let totpValue = totp.generateTOTPValue(6);
console.log(totpValue);


