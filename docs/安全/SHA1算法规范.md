# SHA1算法规范
> SHA1算法作为摘要算法的一种，被使用于各种签名、摘要等场景，本章我们详细分析下SHA1算法细节；

## 术语定义
- word： 32bit的String，可以表示为8个16进制的序列，例如A103FE23；
- integer： 表示 `0-2^32-1` 之间的数字；
- block： 表示512bit的String，一个block可以表示为16个word的序列（数组）；

## 消息填充规则
对于待摘要的消息M，先填充一个 `bit 1`，然后填充N个 `bit 0`，最后填充 `64bit` 的消息M的长度信息（单位bit），最终需要满足以下条件：
- (消息M的长度 + 1 + N + 64) % 512 = 0;  PS：消息M的长度单位是bit；

## 函数定义：
- f(t;B,C,D) = (B AND C) OR ((NOT B) AND D)           ( 0 <= t <= 19)
- f(t;B,C,D) = B XOR C XOR D                          (20 <= t <= 39)
- f(t;B,C,D) = (B AND C) OR (B AND D) OR (C AND D)    (40 <= t <= 59)
- f(t;B,C,D) = B XOR C XOR D                          (60 <= t <= 79).
- K(t) = 5A827999                                     ( 0 <= t <= 19)
- K(t) = 6ED9EBA1                                     (20 <= t <= 39)
- K(t) = 8F1BBCDC                                     (40 <= t <= 59)
- K(t) = CA62C1D6                                     (60 <= t <= 79).
- S^n(X)  =  (X << n) OR (X >> 32-n)

## 摘要算法
> PS：摘要算法有两种，一种使用内存多一点儿，算法比较简单（相当于以空间换时间），一种使用内存少一点，算法比较复杂（相当于以时间换空间），这里我们使用第一种算法，也就是使用内存多一点儿，但是算法简单的；

1、声明四个buffer：
- 两个长度为5的buffer，单位为word，其中一个buffer中的数据打标为 `A`、`B`、`C`、`D`、`E`，另外一个buffer中的数据打标为`H0`、`H1`、`H2`、`H3`、`H4`；
- 一个长度为80的buffer，单位word，其中数据打标为`W(0)`、`W(1)`、`W(2)`...`W(79)`；
- 一个长度为1的buffer，单位word，打标为`TEMP`；

2、将打标为`H`的buffer填充为以下值：
- H0: 0x67452301
- H1: 0xEFCDAB89
- H2: 0x98BADCFE
- H3: 0x10325476
- H4: 0xC3D2E1F0

3、将带摘要的消息按照上文提到的填充规则填充；

4、将填充好后的数据按照512bit分组为`M0`、`M1`、`M2`...`Mn`来循环处理，直至所有分组处理完成，其中`Mi`的处理规则如下：
- 将`Mi`中的数据从左到右拆分放入`W(0)`、`W(1)`...`W(15)`中；PS：注意，`Mi`中的数据总共512bit，正好拆分为16个`word`放入`W(0)-W(15)`中；
- 循环处理（t从16循环到79）：W(t) = S^1(W(t-3) XOR W(t-8) XOR W(t-14) XOR W(t-16))；
- 使A = H0, B = H1, C = H2, D = H3, E = H4；
- 循环处理（t从0循环到79）：TEMP = S^5(A) + f(t;B,C,D) + E + W(t) + K(t);E = D;  D = C;  C = S^30(B);  B = A; A = TEMP;
- 最后更新`H`buffer中的值：H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E；

当`Mn`处理完成后`H0 H1 H2 H3 H4`就是我们需要的消息摘要；

## 参考文档：
- SHA1规范：RFC3174

## 参考Java实现：
```
import java.util.Arrays;

/**
 * RFC3174规范的参考实现
 * 
 * @author JoeKerouac
 * @since 1.0.0
 */
public class SHA1 {

    /**
     * block大小，单位byte
     */
    private static final int BLOCK_SIZE = 64;

    private final int[] H = new int[5];
    private final int[] W = new int[80];

    /**
     * 计算摘要信息
     *
     * @param data
     *            要计算摘要信息的数据
     * @return 计算结果
     */
    public byte[] digest(byte[] data) {
        reset();

        byte[] padding = padding(data);
        int blockCount = padding.length / BLOCK_SIZE;
        for (int i = 0; i < blockCount; i++) {
            process(padding, i * BLOCK_SIZE);
        }

        byte[] result = new byte[20];
        for (int i = 0; i < 5; i++) {
            writeInt(H[i], result, i * 4);
        }

        return result;
    }

    /**
     * 重置H状态值
     */
    private void reset() {
        H[0] = 0x67452301;
        H[1] = 0xEFCDAB89;
        H[2] = 0x98BADCFE;
        H[3] = 0x10325476;
        H[4] = 0xC3D2E1F0;

    }

    /**
     * 填充
     * 
     * @param data
     *            要填充的数据
     * @return 填充结果
     */
    private byte[] padding(byte[] data) {
        // 计算总共需要填充的长度
        int paddingSize = BLOCK_SIZE - (data.length % BLOCK_SIZE);
        paddingSize = paddingSize < 9 ? paddingSize + BLOCK_SIZE : paddingSize;

        // 开始生成填充后的数据
        byte[] padding = new byte[data.length + paddingSize];
        System.arraycopy(data, 0, padding, 0, data.length);
        // 先填充一个bit1和7个bit0，正好对应有符号byte值的-128
        padding[data.length] = -128;

        // 填充0
        for (int i = data.length + 1; i < padding.length - 8; i++) {
            padding[i] = 0;
        }

        // 填充原消息的长度
        writeLong(data.length * 8L, padding, padding.length - 8);
        return padding;
    }

    /**
     * 将long值写入byte数组
     * 
     * @param value
     *            long值
     * @param data
     *            数组
     * @param offset
     *            写入起始位置
     */
    private void writeLong(long value, byte[] data, int offset) {
        for (int i = 0; i < 8; i++) {
            data[offset + i] = (byte)(value >>> ((7 - i) * 8) & 0xff);
        }
    }

    /**
     * 将int值写入byte数组
     * 
     * @param value
     *            int值
     * @param data
     *            要写入的数组
     * @param offset
     *            写入起始位置
     */
    private void writeInt(int value, byte[] data, int offset) {
        for (int i = 0; i < 4; i++) {
            data[offset + i] = (byte)(value >>> ((3 - i) * 8) & 0xff);
        }
    }

    /**
     * 从起始位置开始往后将原始数据中的4个byte合并为一个int
     * 
     * @param data
     *            原始数据
     * @param offset
     *            起始位置
     * @return int
     */
    private int mergeToInt(byte[] data, int offset) {
        return Byte.toUnsignedInt(data[offset]) << 24 | Byte.toUnsignedInt(data[1 + offset]) << 16
            | Byte.toUnsignedInt(data[2 + offset]) << 8 | Byte.toUnsignedInt(data[3 + offset]);
    }

    /**
     * 处理数据指定起始位置开始的一个block
     * 
     * @param data
     *            待处理的数据
     * @param offset
     *            起始位置
     */
    private void process(byte[] data, int offset) {
        for (int j = 0; j < 16; j++) {
            W[j] = mergeToInt(data, offset + j * 4);
        }

        for (int t = 16; t < 80; t++) {
            // W(t-3) XOR W(t-8) XOR W(t-14) XOR W(t-16)
            int value = W[t - 3] ^ W[t - 8] ^ W[t - 14] ^ W[t - 16];
            W[t] = value << 1 | value >>> 31;
        }

        int temp;
        int A = H[0];
        int B = H[1];
        int C = H[2];
        int D = H[3];
        int E = H[4];

        for (int t = 0; t < 80; t++) {
            // TEMP = S^5(A) + f(t;B,C,D) + E + W(t) + K(t);
            temp = (A << 5 | A >>> 27) + f(t, B, C, D) + E + W[t] + k(t);
            E = D;
            D = C;
            C = B << 30 | B >>> 2;
            B = A;
            A = temp;
        }

        H[0] += A;
        H[1] += B;
        H[2] += C;
        H[3] += D;
        H[4] += E;
    }

    /**
     * 对应RFC3174规范中的函数K
     * 
     * @param t
     *            t
     * @return 结果
     */
    private int k(int t) {
        // K(t) = 5A827999 ( 0 <= t <= 19)
        // K(t) = 6ED9EBA1 (20 <= t <= 39)
        // K(t) = 8F1BBCDC (40 <= t <= 59)
        // K(t) = CA62C1D6 (60 <= t <= 79).
        if (t >= 0 && t <= 19) {
            return 0x5A827999;
        } else if (t <= 39) {
            return 0x6ED9EBA1;
        } else if (t <= 59) {
            return 0x8F1BBCDC;
        } else {
            return 0xCA62C1D6;
        }
    }

    /**
     * 对应RFC3174规范中的函数f
     * 
     * @param t
     *            t
     * @param B
     *            B
     * @param C
     *            C
     * @param D
     *            D
     * @return 结果
     */
    private int f(int t, int B, int C, int D) {
        // f(t;B,C,D) = (B AND C) OR ((NOT B) AND D) ( 0 <= t <= 19)
        // f(t;B,C,D) = B XOR C XOR D (20 <= t <= 39)
        // f(t;B,C,D) = (B AND C) OR (B AND D) OR (C AND D) (40 <= t <= 59)
        // f(t;B,C,D) = B XOR C XOR D (60 <= t <= 79).
        if (t >= 0 && t <= 19) {
            return (B & C) | (~B & D);
        } else if (t <= 39) {
            return B ^ C ^ D;
        } else if (t <= 59) {
            return B & C | B & D | C & D;
        } else {
            return B ^ C ^ D;
        }
    }

    public static void main(String[] args) {
        // 假设这就是我们的数据，实际使用中将data替换为实际的数据即可
        byte[] data = new byte[63];
        SHA1 sha1 = new SHA1();
        // 计算消息摘要
        byte[] digest = sha1.digest(data);
        System.out.println(Arrays.toString(digest));
    }
}
```
