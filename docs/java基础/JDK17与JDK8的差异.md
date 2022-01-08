# JDK17的一些新特性
> 限于篇幅，本文仅列举其中一些差异，而不是全部差异；


## instanceof
JDK8中的语法：
```
Object o = something;
if (o instanceof String) {
    String str = (String)o;
    // do something
}
```

在JDK17中我们可以这样写：
```
Object o = something;
if (o instanceof String str) {
    // do something, 注意上边String后边跟了一个str，相当于把o强转为String同时使用变量名str引用，我们后续可以直接使用str而不用再加一层强转了
}
```

## switch
### 普通switch
如果switch中只有一条语句时，JDK8中的语法：
```
String str = something;
switch (str) {
    case "123":
        System.out.println(str);
        break;
    case "456":
        System.out.println(str);
        break;
}
```
可以看出每个case后边都需要一个 `break` ，否则会穿透到后边的 `case` 语句；

JDK17中的语法：
```
String str = something;
switch (str) {
    case "123" -> System.out.println(str);
    case "456" -> System.out.println(str);
    default -> System.out.println(str);
}
```


### switch的模式匹配
JDK8中的语法：
```
Object o = something;
if (o instanceof String) {
    String str = (String)o;
    // do something
} else if (o instanceof Integer) {
    Integer integer = (Integer)o;
    // do something
}
```

在JDK17中我们可以这样写（case语句也可以展开，这里为了省事就用了这种写法）：
```
Object o = something;

switch (o) {
    case Integer i -> System.out.println(i);
    case String str -> System.out.println(str);
    default -> System.out.println(o);
}
```

### null值处理
传统（JDK8）switch语句需要提前判null，否则会抛出NPE：
```
String str = something;
if (str == null) {
    // do something
    return;
}
switch (str) {
    case "123":
        System.out.println(str);
        break;
    case "456":
        System.out.println(str);
        break;
}
```

JDK17中无需判空，可以直接 `case null` ：
```
String str = something;
switch (str) {
    case null -> System.out.println("null");
    case "123" -> System.out.println(str);
    case "456" -> System.out.println(str);
    default -> System.out.println(str);
}

```

### 复杂条件的case优化：
对于以下代码：
```
class Shape {}
class Rectangle extends Shape {}
class Triangle  extends Shape { int calculateArea() { ... } }

static void testTriangle(Shape s) {
    switch (s) {
        case null:
            break;
        case Triangle t:
            if (t.calculateArea() > 100) {
                System.out.println("Large triangle");
                break;
            }
        default:
            System.out.println("A shape, possibly a small triangle");
    }
}

```

可以优化为：
```
class Shape {}
class Rectangle extends Shape {}
class Triangle  extends Shape { int calculateArea() { ... } }

static void testTriangle(Shape s) {
    switch (s) {
        case Triangle t && (t.calculateArea() > 100) ->
            System.out.println("Large triangle");
        default ->
            System.out.println("A shape, possibly a small triangle");
    }
}
```

## 密封类（sealed Class）
在JDK8中，如果我们一个类只想要只想要指定的子类（我们自己编写的类）实现，而不希望其他依赖方自己实现（这种场景在框架编写中很常见），我们通常的方法是将构造器设置为私有的，然后使用
静态内部类来继承该类，或者将构造器设置为package访问级别的，然后在同一个包中编写类来继承；这两种方式虽然都能实现我们的目标（在某些场景也能被打破，例如用户自己编写了一个同名包，然
后就能在包中继续继承该类了），但是都不是太优雅，在我们升级JDK17后该问题也将被解决，JDK17中引入了一个新的关键字 `sealed` 用来修饰我们不想要其他人私自继承的类（或者接口），然后使用
`permits` 关键字指定都有那些类可以继承本类，用法如下：

```
public abstract sealed class TestA permits TestB {
    
}

public class TestB extends TestA {
    
}
```
这里我们使用 `sealed` 关键字声明 `TestA` 不能随便被其他类继承，然后使用 `permits` 声明只有 `TestB` 才能继承 `TestA` ，注意，这里 `TestB` 和 `TestA` 必须在同一个包中，如
果不在同一个包中，那么 `permits` 关键字后的 `TestB` 必须带包名（例如com.JoeKerouac.TestB）；
