# ConcurrentModificationException
## 异常分析
相信写过一些Java代码的人都遇到过这个异常，一般都是由以下代码引起的：
```
import java.util.List;
import java.util.ArrayList;

public class Test{
    public static void main(String[] args){
      List<String> list = new ArrayList<>();
      list.add("123");
      list.add("456");
      list.add("789");
      for(String obj : list){
          list.remove(obj);
      }
    }
}
```
上述代码最终会引发java.util.ConcurrentModificationException，那么为什么呢？首先我们将上述代码反编译，得到如下结果（如果对foreach语法糖比较了解可以忽略）：
```
public class Test {
  public Test();
    Code:
       0: aload_0
       1: invokespecial #1                  // Method java/lang/Object."<init>":()V
       4: return
    LineNumberTable:
      line 4: 0

  public static void main(java.lang.String[]);
    Code:
       0: new           #2                  // class java/util/ArrayList
       3: dup
       4: invokespecial #3                  // Method java/util/ArrayList."<init>":()V
       7: astore_1
       8: aload_1
       9: ldc           #4                  // String 123
      11: invokeinterface #5,  2            // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
      16: pop
      17: aload_1
      18: ldc           #6                  // String 456
      20: invokeinterface #5,  2            // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
      25: pop
      26: aload_1
      27: ldc           #7                  // String 789
      29: invokeinterface #5,  2            // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
      34: pop
      35: aload_1
      36: invokeinterface #8,  1            // InterfaceMethod java/util/List.iterator:()Ljava/util/Iterator;
      41: astore_2
      42: aload_2
      43: invokeinterface #9,  1            // InterfaceMethod java/util/Iterator.hasNext:()Z
      48: ifeq          72
      51: aload_2
      52: invokeinterface #10,  1           // InterfaceMethod java/util/Iterator.next:()Ljava/lang/Object;
      57: checkcast     #11                 // class java/lang/String
      60: astore_3
      61: aload_1
      62: aload_3
      63: invokeinterface #12,  2           // InterfaceMethod java/util/List.remove:(Ljava/lang/Object;)Z
      68: pop
      69: goto          42
      72: return
    LineNumberTable:
      line 6: 0
      line 7: 8
      line 8: 17
      line 9: 26
      line 10: 35
      line 11: 61
      line 12: 69
      line 13: 72
}
```
将上述代码翻译出来等价于下列代码：
```
import java.util.List;
import java.util.ArrayList;
import java.util.Iterator;

public class Test{
    public static void main(String[] args){
      List<String> list = new ArrayList<>();
      list.add("123");
      list.add("456");
      list.add("789");
      Iterator<String> iterator = list.iterator();
      while (iterator.hasNext()){
          String obj = iterator.next();
          list.remove(obj);
      }
    }
}
```
然后我们查看`iterator.hasNext()`源码，可以发现第一行调用了`checkForComodification`方法，我们查看这个方法：

```
final void checkForComodification() {
    if (modCount != expectedModCount)
        throw new ConcurrentModificationException();
}
```
在`modCount != expectedModCount`这个条件成立的时候会抛出`ConcurrentModificationException`异常，那么这个条件是怎么成立的呢？

1、首先我们查看`modCount`的来源，可以发现`modCount`的值等于当前List的`size`，当调用`List.remove`方法的时候`modCount`也会相应的减1；

2、然后我们查看`expectedModCount`的来源，可以看到是在构造`Iterator`（这里使用的是ArrayList的内部实现）的时候，有一个变量赋值，将`modCount`
的值赋给了`expectedModCount`；

3、最后当我们执行循环调用`List.remove`方法的时候，`modCount`改变了但是`expectedModCount`并没有改变，当第一次循环结束删除一个数据准
备第二次循环调用`iterator.hasNext()`方法的时候，`checkForComodification()`方法就会抛出异常，因为此时`List`的`modCount`已经变为
了2，而`expectedModCount`仍然是3，所以会抛出`ConcurrentModificationException`异常；

## 解决方法
那么如何解决该问题呢？我们查看`java.util.ArrayList.Itr`（ArrayList中的Iterator实现）的源码可以发现，在该迭代器中有一个`remove`方法可以
删除当前迭代元素，而且会同时修改`modCount`和`expectedModCount`，这样在进行`checkForComodification`检查的时候就不会抛出异常了，该`remove`
方法源码如下：
```
public void remove() {
    if (lastRet < 0)
        throw new IllegalStateException();
    checkForComodification();

    try {
        ArrayList.this.remove(lastRet);
        cursor = lastRet;
        lastRet = -1;
        expectedModCount = modCount;
    } catch (IndexOutOfBoundsException ex) {
        throw new ConcurrentModificationException();
    }
}
```
其中`ArrayList.this.remove(lastRet);`这一行会改变`modCount`的值，而后边会同步的修改`expectedModCount`的值等于`modCount`的值；


现在修改我们开头的程序如下就可以正常运行了：
```
import java.util.List;
import java.util.ArrayList;
import java.util.Iterator;

public class Test{
    public static void main(String[] args){
      List<String> list = new ArrayList<>();
      list.add("123");
      list.add("456");
      list.add("789");
      Iterator<String> iterator = list.iterator();
      while (iterator.hasNext()) {
          System.out.println("移除：" + iterator.next());
          iterator.remove();
      }
    }
}
```

# 关于作者
- 微信：qiao1213812243
- 微信公众号：代码深度研究院
- GitHub首页:https://github.com/JoeKerouac