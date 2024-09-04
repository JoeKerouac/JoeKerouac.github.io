# idea插件开发之bean复制插件
## 背景
周末在家无事做，顺手开发了一个之前一直想要做的插件，那就是bean复制插件。

在项目中，由于代码分层设计，对于同样一个数据我们通常会定义不同层的`实体`，例如`xxxEntity`、`xxxDTO`、`xxxVO`等，这些不同的`实体`通常会具有很多相同的字段，在使用时我们需要在进入不同层时将一个类型的对象转换为另外一个类型的对象，此时我们有两种选择：
 
- 1、手动`new`出来一个对象`target`，然后手动编代码调用`get`、`set`方法将`source`中的字段copy到`target`中；
- 2、使用各种框架的`BeanUtils.copyProperties`方法来将`source`中的字段复制到`target`中；

对于这两种方案，各有利弊：

- 如果项目开发比较急，或者想要懒省事，我们通常会使用`BeanUtils.copyProperties`，因为不需要写代码逐个字段去复制，大大减少工作量，但是性能差、代码重构不友好、不太方便阅读，如果是新人接手项目，很难找到某个字段都在哪里使用了，相信接手过老项目的人深有体会；
- 对于一些核心模块，或者有性能要求的，通常我们会手动编码调用对象的`get`、`set`方法来逐个字段复制，这样性能高、代码重构友好、方便阅读，可以很快速找到某个字段的依赖方，但是工作量会比较大：

那有没有一种可能，让我们拥有这两种方案的优势，而又没有各自的劣势呢？

![我全都要.webp](../../resource/idea/我全都要.webp)

当然是有的，如果我们可以自动生成之前需要手动生成的`get`、`set`调用复制bean字段，那不就既有性能、代码重构友好、方便阅读等优势，又有高效开发的优势了嘛；其实在很早我就有这种想法，想要开发一个插件，能够自动生成bean复制代码替代BeanUtils.copyProperties，但是苦于没有时间(~~懒~~)，就没有做，正好上周又想起来这件事了，周末就花了点儿时间来研究了下；




## 插件开发
### 准备工作
通过一番简单快速的学习，我们准备好以下事项，就可以开始开发了

> 官方插件开发文档参考: https://plugins.jetbrains.com/docs/intellij/developing-plugins.html

- 1、idea，虽然也可以用其他IDE开发，但是毕竟是开发idea的插件，最好还是安装一个最新版的idea；
- 2、学习Gradle的基本使用，因为最新版插件开发默认使用Gradle作为构建系统；

安装好idea后，需要安装一个插件：`Plugn DevKit`，该开发套件在`2023.2`版本以前是跟idea捆绑的，但是从`2023.2`以后就独立作为一个插件不在捆绑在idea了；

### 开始开发
首先，我们要创建一个插件项目，可以通过菜单栏的`file->new->project->IDE Plugin`来创建一个插件项目，项目结构如下；默认是用`kotlin`语言开发的，源码目录是`src/main/kotlin`，因为我是主要使用Java作为主语言开发的，所以就给替换为`src/main/java`了；

```
plugin/
├── .gradle/
├── .idea/
├── .run/
├── gradle/
├── src/
│   └── main
│       ├── java
│       └── resources
├── .gitignore
├── build.gradle.kts
├── project.iml
├── gradle.properties
├── gradlew
├── gradlew.bat
└── settings.gradle.kts
--
```

对于构建脚本`build.gradle.kts`，这里不详细讲，可以自行学习`gradle`（这个文件是kotlin语法的，所以还要学习一些简单的kotlin语法），主要讲下我们的实现思路，我们目标是通过调用`get`、`set`方法把source对象的字段复制到target中，所以需要以下步骤：

1、在`code->generate`处注册一个菜单（快捷键alt+insert）
2、获取target变量，我们选取当前光标所在位置的变量作为target变量，此时需要校验光标所处位置是否是变量名，如果不是，则隐藏菜单；
3、让用户手动输入source变量名；
4、检查指定名字的变量是否存在，与target是否有同名字段，字段类型是否相同，把同名、同类型的字段挑出来，让用户自己选择要复制的字段；
5、生成调用`get`、`set`方法复制字段的代码；

最终效果如下：

![使用示例.webp](../../resource/idea/使用示例.gif)


> 插件已经在idea的插件市场发布，需要的可以在插件市场搜索`BeanCopy`来安装，目前是0.0.1版本，如果需要源码，可以在https://github.com/JoeKerouac/idea-bean-copy-plugin找到；由于时间有限，这里不详细说明实现了，有需要的可以自行查看源码或者联系作者；

# 联系我
- 作者微信：JoeKerouac
- 微信公众号（文章会第一时间更新到公众号，如果搜不出来可能是改名字了，加微信即可=_=|）：代码深度研究院
- GitHub：https://github.com/JoeKerouac

