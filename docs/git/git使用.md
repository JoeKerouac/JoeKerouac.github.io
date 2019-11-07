# git本地创建项目提交到GitHub
- 1、在GitHub创建一个项目；
- 2、在本地创建一个maven项目；
- 3、在本地maven项目目录里边执行命令`git init`；
- 4、将本地文件添加到git；
- 5、使用`git remote add origin [你的git仓库链接]`
- 6、提交本地文件到远程，如果远程仓库已有文件，那么需要使用`git push --allow-unrelated-histories`命令来push，否则会被拒绝提交；
# git本地创建分支提交到远程：
```
git branch 分支名
git push --set-upstream origin 分支名
```
这样就能将本地新建分支提交到远程了，upstream

# git创建PR流程：
1. 首先fork项目
2. 然后将项目clone到本地（fork到自己的仓库地址）
3. 创建一个分支
4. 在该分支工作并commit/push
5. push完成后到github上切换到自己创建的分支然后提交PR

# git历史提交作者修改（用于之前提交作者、邮箱设置错误）：
1. 使用git clone --bare git项目地址将项目迁出
2. 切换到项目目录
3. 在命令行输入：
 ```
git filter-branch --env-filter '
OLD_EMAIL=原来使用的邮箱（错误邮箱）
CORRECT_NAME=正确的作者
CORRECT_EMAIL=正确的邮箱
if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
export GIT_COMMITTER_NAME="$CORRECT_NAME"
export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
export GIT_AUTHOR_NAME="$CORRECT_NAME"
export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags
```
4. 输入以上命令回车
5. 最后输入以下命令并回车：
```
git push --force --tags origin 'refs/heads/*
```

6. 最后到github上查看作者是否更改


# fork项目新分支拉取
1. 将项目B clone 到本地

   git clone -b master 项目B的git地址

2. 将项目A的git地址，添加至本地的remote

   git remote add upstream 项目A的git地址

3. 在本地新建一个分支，该分支的名称最好与项目A中新增的那个分支的名称相同以便区分

   git checkout -b 新分支名称

4. 从项目A中将新分支的内容 pull 到本地
   
   git pull upstream 新分支名称

5. 将 pull 下来的分支 push 到项目B 中去
   
   git push origin 新分支名称

其中，上面的 3 和 4 两步可以合并为下面的这一步：

git checkout -b 新分支名称 upstream/新分支名称


git reset命令参数：
- --soft参数告诉Git重置HEAD到另外一个commit，但也到此为止。如果你指定--soft参数，Git将停止在那里而什么也不会根本变化。这意味着index,working copy都不会做任何变化，所有的在original HEAD和你重置到的那个commit之间的所有变更集都放在stage(index)区域中。
- --hard参数将会blow out everything.它将重置HEAD返回到另外一个commit(取决于~12的参数），重置index以便反映HEAD的变化，并且重置working copy也使得其完全匹配起来。这是一个比较危险的动作，具有破坏性，数据因此可能会丢失！如果真是发生了数据丢失又希望找回来，那么只有使用：git reflog命令了。makes everything match the commit you have reset to.你的所有本地修改将丢失。如果我们希望彻底丢掉本地修改但是又不希望更改branch所指向的commit，则执行git reset --hard = git reset --hard HEAD. i.e. don't change the branch but get rid of all local changes.另外一个场景是简单地移动branch从一个到另一个commit而保持index/work区域同步。这将确实令你丢失你的工作，因为它将修改你的work tree！
- --mixed是reset的默认参数，也就是当你不指定任何参数时的参数。它将重置HEAD到另外一个commit,并且重置index以便和HEAD相匹配，但是也到此为止。working copy不会被更改。所有该branch上从original HEAD（commit）到你重置到的那个commit之间的所有变更将作为local modifications保存在working area中，（被标示为local modification or untracked via git status)，但是并未staged的状态，你可以重新检视然后再做修改和commit

如果有某个错误被提交到远程希望删除本次提交回到上次提交，可以先使用命令

`git reset --hard HEAD~1`(注意，1表示删除最近一次的，如果是最近两次就是2，以此类推)

然后使用命令

`git push --force`

这样就能将远程最近一次的提交删除（警告：如果push前有其他人push内容到该分支，那么其他人的push将会被删除）。

# 创建新分支并提交
新分支创建完毕后需要使用命令`git push --set-upstream [remote，例如origin] [分支名]`建立本地到远程的链接才能提交上去。（如果不用这个将不能提交，或者在新分支中更改点儿东西然后使用IDE提交也行）

# 创建tag
使用命令：
```
git tag -a tag名
```
为当前（HEAD）创建tag，如果想为过往commit创建tag只需要执行命令：
```
git tag -a tag名 commit-id
```
其中commit-id是指定commit的校验和

# 提交tag
使用命令：
```
git push origin --tags
```
提交本地所有tag。或者也可以使用以下命令来提交单个tag：
```
git push origin tag名
```

**注意：tag提交完毕后会在github自动生成一个release，包含tag版本的源码。**

# 删除tag
本地删除：
```
git tag -d tag名
```
提交到远程：
```
git push origin :删除的tag名
```
注意：冒号和origin中间有一个空格。

#查看日志
git log -2：查看最近两次

git log --pretty=oneline -2 查看最近两次提交，并且在一行显示（只显示id和msg）。

# git常见问题
- 拉取代码时提示`filename too long`，原因：git有可以创建4096长度的文件名，然而在windows最多是260，因为git用了旧版本的windows api，解决方案：使用命令`git config --global core.longpaths true`
- git checkout到指定commit，此时
# 查看两个分支的差异文件
git diff 分支名 --stat
git diff commit-id commit-id --stat

说明： 第一个命令查看两个分支的差异文件，其中--stat表示查看统计信息而不是详细信息，第二个命令查看两个commit中间的文件差异；

# 删除最近一次commit
git reset HEAD~
该命令会将最近一次提交到本地缓存区的文件回退到未提交状态，并不会删除，此时你仍然可以修改然后继续提交，或者选择删除修改
