set -e

###################################################################################################################
##
## 将Linux内核代码推送到自己的git仓库，注意，要有一个干净的git仓库，同时需要能访问外网；
## 为什么不直接在GitHub等网站直接镜像仓库？仓库过大，镜像失败；完整内核仓库大小2.5G左右；
## 注意，执行前要确保本地存储的有git账号密码，否则过程中需要手动输入
##
###################################################################################################################


# 工作目录，这个目录要自己创建
WORK_DIR=/root/tmp
# 原始仓库
ORIGIN_DIR=${WORK_DIR}/linus
# 新仓库
NEW_DIR=${WORK_DIR}/self
# 自己的git仓库
self_git_url=

# linus本人的git仓库
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ${ORIGIN_DIR}
git clone ${self_git_url} ${NEW_DIR}


cat << EOF > ${WORK_DIR}/tmp.sh
set -e

# 原始仓库路径
ORIGIN_DIR=${ORIGIN_DIR}
# 新仓库
NEW_DIR=${NEW_DIR}

EOF

cat << "EOF" >> ${WORK_DIR}/tmp.sh
# 要拉取的分支
BRANCH=$1

echo "准备处理${BRANCH}分支"

# 切换到原始仓库拉取指定分支代码
cd ${ORIGIN_DIR}
git co ${BRANCH}
echo "删除老文件"
rm -rf ${NEW_DIR}/*
echo "拷贝新文件"
cp -r * ${NEW_DIR}
cd ${NEW_DIR}
echo "准备git add"
git add --all
echo "准备commit"
git commit --all -m "迁移"
echo "准备提交"
git push origin master:main
git push origin master:${BRANCH}

EOF


cd ${ORIGIN_DIR}
git tag | xargs -I {} sh ${WORK_DIR}/tmp.sh {}

