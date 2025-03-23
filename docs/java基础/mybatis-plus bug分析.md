# mybatis-plus缓存bug分析
前段时间在使用mybatis-plus的过程中，发现了一些bug（最新版本均已修复），现在分享一下；

## 分页缓存bug

> 这里使用的mybatis-plus版本是3.0.7.1

在项目中有一个场景是需要把数据从数据库全查出来，然后进行一些处理，因为考虑到数据量可能会特别大，就使用了mybatis-plus的分页查询功能，代码如下：

```java
package com.github.joekerouac.mybatis.plus.demo;

import com.baomidou.mybatisplus.core.metadata.IPage;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.List;

@Service
public class DemoCode {

    @Resource
    private UserRepository userRepository;

    @Transactional
    public void test1() {
        int pageNo = 1;
        int size = 200;
        while (true) {
            IPage<UserEntity> page = userRepository.selectPage(pageNo++, size);
            List<UserEntity> records = page.getRecords();
            for (UserEntity record : records) {
                // do something
            }
            if (page.getCurrent() >= page.getSize()) {
                break;
            }
        }
    }

}

```

这段代码在开发环境跑的时候没什么问题，可是到了测试环境就开始死循环，数据库、应用程序都快搞爆了，然后就赶紧进行了版本回退，然后就开始找问题，但是试了许久，开发环境就是没有复现，最终在快要放弃准备在测试环境远程debug的时候，发现了一个差异点，那就是开发和测试环境的数据量不同，测试环境有200多条数据，而开发只有40多条，而我这里的分页恰好也是200，有没有可能是这个导致的呢？抱着试一试的态度，将开发环境数据也增加到200以上，结果程序一跑，发现真的是这个导致的，debug的时候发现这里每次查出来的数据都是一样的，所以怀疑是缓存的问题，熟悉mybatis的朋友都知道，mybatis是有二级缓存的，其中一级缓存是SqlSession级别的，默认是打开的，我项目中也没有专门关闭，所以这个缓存就是开着的；

> 注意，这里是有事务注解的，这也是一级缓存能生效的前提；


接下来在缓存处开始debug，核心代码在`org.apache.ibatis.executor.BaseExecutor#query(org.apache.ibatis.mapping.MappedStatement, java.lang.Object, org.apache.ibatis.session.RowBounds, org.apache.ibatis.session.ResultHandler, org.apache.ibatis.cache.CacheKey, org.apache.ibatis.mapping.BoundSql)`这里，通过debug发现，每次查询时的CacheKey都是一样的，所以最终就走了缓存而不是数据查询，接下来问题就好解决了，我们找到了创建CacheKey的地方`org.apache.ibatis.executor.BaseExecutor#createCacheKey`，在这里可以发现 ，这里并没有把mybatis-plus的分页参数更新到CacheKey中，想想也是，mybatis-plus是mybatis之上的框架，是基于mybatis的增强工具，mybatis又怎么会把他的分页参数更新进来呢，那不就是倒反天罡嘛；


到这里，问题也就明确了，因为我们只是修改了分页参数，想要查询下一页的数据，但是却因为缓存key没有被正确的更新，导致mybatis错误的命中了缓存，最终把上一次的数据返回了，导致当实际数据大于1页的时候，业务中发生了死循环，因为第二次开始查询的结果都是返回的第一次的结果，永远有下一页；找到了问题，解决也就简单了，只需要在这里将mybatis-plus的分页参数更新进去就行了，不过在我做之前，去看了mybatis-plus仓库，发现他们在3.1.0这个版本已经修复了，对比了下我们项目中使用的3.0.7.1，变更不算大，所以就升级到了该版本，3.1.1版本的解决方案也很简单，就是上边这个思路，在创建CacheKey的时候把分页参数更新了进去，详情可以参考`com.baomidou.mybatisplus.core.executor.AbstractBaseExecutor#createCacheKey`，这个方法里边将mybatis-plus的分页参数也更新到了CacheKey中，这样当我们在事务中分页查询的时候就不会有错误的缓存了；


> 演示代码参考: https://github.com/JoeKerouac/mybatis-plus-demo

## 租户缓存bug
在解决上边分页缓存问题后不久，又发现一个新问题，那就是在同一个事务中，切换租户上下文会导致错误缓存，因为有了上边的经验，我们直接找到了缓存key创建的地方，经过对比，发现切换租户前后的缓存一模一样，实际上他们的sql应该是不同的（租户不同），但是可以观察到这里的sql是一模一样的，并没有添加租户条件，继续分析mybatis-plus后可以发现，mybatis-plus的租户插件是依赖于分页插件`com.baomidou.mybatisplus.extension.plugins.PaginationInterceptor`的，在这里拦截修改了sql，为sql添加了租户条件，但是分页拦截器拦截的是Connection的prepare方法，实际上mybatis是先执行的`org.apache.ibatis.executor.BaseExecutor#query(org.apache.ibatis.mapping.MappedStatement, java.lang.Object, org.apache.ibatis.session.RowBounds, org.apache.ibatis.session.ResultHandler, org.apache.ibatis.cache.CacheKey, org.apache.ibatis.mapping.BoundSql)`，缓存逻辑也是在这里处理的，如果当前没有缓存，才会继续执行查询方法，最终调用到Connection的prepare方法，然后被mybatis-plus拦截，动态添加租户条件，所以在生成缓存key时还未到mybatis-plus的分页拦截器，此时sql中并不包含租户，sql的参数中也没有租户，自然缓存key也不会包含租户信息，这就导致了只是切换租户，查询条件不变的情况下，第二次查询错误的命中了第一次查询的缓存；

既然找到了问题，那么也好解决：

- 方案一：在创建CacheKey的时候定制化处理，将租户信息注入，像分页参数那样；
- 方案二：提前修改sql，在创建CacheKey之前就把租户信息动态添加到sql中，那就需要修改分页插件的拦截点；

通过查看mybatis-plus源码，发现其在3.4.0中将该问题解决了，解决方案就是采用的上边的方案二，将插件的拦截点提前，实现上做了更通用的处理，通过`com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor`做了拦截点，但是并没有任何实际插件逻辑，而是在内部又将拦截点的调用分发给了`com.baomidou.mybatisplus.extension.plugins.inner.InnerInterceptor`接口，无论是租户插件还是分页插件都实现了该接口，最终在生成CacheKey之前将修改同步到了sql中，变更了当前要执行的sql，这样当租户或者分页参数变更后sql也会变更CacheKey自然也会不同，此时也就无需再hack CacheKey的创建了，这样做有个好处，就是后边如果需要添加其他动态sql修改插件，那么都会在创建CacheKey之前执行，最终保证动态变更的内容会同步到CacheKey中，不会让mybatis使用错误的缓存；


需要注意的是，我们注册添加`com.baomidou.mybatisplus.extension.plugins.inner.InnerInterceptor`的租户实现和分页实现时，一定要在注册分页实现`com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor`之前注册租户实现`com.baomidou.mybatisplus.extension.plugins.inner.TenantLineInnerInterceptor`，因为在分页插件的`com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor#willDoQuery`方法中为了获取总数据量，需要执行一个count sql，分页插件在willDoQuery方法中手动调用了sql执行函数来执行count sql，如果租户插件在分页插件之后执行，那么这里的count sql执行时创建的CacheKey中就不会有租户的信息，仍然会在只变更租户而不改变其他条件的场景下导致count sql执行时使用错误的缓存；同理，如果还有其他动态修改sql的插件，也需要注册在分页插件之前；


# 联系我
- 作者微信：JoeKerouac
- 微信公众号（文章会第一时间更新到公众号，如果搜不出来可能是改名字了，加微信即可=_=|）：代码深度研究院
- GitHub：https://github.com/JoeKerouac

