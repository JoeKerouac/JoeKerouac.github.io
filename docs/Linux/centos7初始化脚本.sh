# 更改yum源为清华大学的
# 先备份
cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
# 更改yum源
echo '
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the
# remarked out baseurl= line instead.
#
#


[base]
name=CentOS-$releasever - Base
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/os/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-7

#released updates
[updates]
name=CentOS-$releasever - Updates
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/updates/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-7



#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/extras/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-7



#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/centosplus/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-7
' > /etc/yum.repos.d/CentOS-Base.repo.bak

# 刷新缓存
yum makecache
# 更新
yum -y update

# 安装vim、net-tools工具、git
yum install -y vim net-tools bash-completion bash-completion-extras git

# 安装vundle管理vim插件
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle

# 配置vim
cat << EOF > ~/.vim
" ----------------------------Vundle配置开始----------------------------
set nocompatible              " Vundle必须
filetype off                  " Vundle必须
" 设置运行时路径包含Vundle并且初始化
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Vundle管理vim插件配置，管理的插件必须在这里配置

" Vundle管理vim插件
Plugin 'VundleVim/Vundle.vim'

" NERDTree目录树工具
Plugin 'https://github.com/scrooloose/nerdtree.git'

" Supertab插件，使用tab键完成代码提示
Plugin 'https://github.com/ervandew/supertab.git'

" 使用该插件代替每次复制前的 set paste 命令，防止格式错乱，同时复制的时候也不会匹配后边的快捷输入
Plugin 'https://github.com/ConradIrwin/vim-bracketed-paste'

" vim中的git插件
Plugin 'tpope/vim-fugitive'

call vundle#end()            " Vundle必须
filetype plugin indent on    " Vundle必须
" ----------------------------Vundle配置结束----------------------------

" ----------------------------插件配置开始，依赖相关插件----------------------------
" 自动打开NERDTree（目录树），该命令依赖于NERDTree插件
autocmd vimenter * NERDTree
"配置nerdtree使用F3打开关闭
map <F3> :NERDTreeMirror <CR>
map <F3> :NERDTreeToggle <CR>
" ----------------------------插件配置结束，依赖相关插件----------------------------


" ----------------------------普通配置开始，不依赖任何插件----------------------------
" 设置搜索时忽略大小写
set ignorecase
" 不去兼容vi命令
set nocompatible
" vim配色方案，可以在/usr/share/vim/vim62/colors中查看所有配色方案
colorscheme desert
" 在下边显示当前是命令模式还是插入模式
set showmode
" 支持256色，默认是8色
set t_Co=256
" 设置行号
set number
" 自动拆行，对于过长的行分为多行展示
set wrap
" 光标遇到圆括号、方括号、大括号时，自动高亮对应的另一个圆括号、方括号和大括号。
set showmatch
" 搜索时，高亮显示匹配结果。
set hlsearch
" 输入搜索模式时，每输入一个字符，就自动跳到第一个匹配的结果。
set incsearch
" 搜索时忽略大小写。
set ignorecase
" 只有遇到指定的符号（比如空格、连词号和其他标点符号），才发生折行。也就是说，不会在单词内部折行
set linebreak
" 突出显示当前行
set cursorline
" vim默认不启用鼠标，启用鼠标
set mouse=a
" 鼠标可以选中文本，并使用y复制、d剪切、p粘贴
set selection=exclusive
" 选中模式，鼠标和按键
set selectmode=mouse,key
" 设置自动缩进，每行的缩进与上一行相同
set autoindent
" 自动将tab键转为空格
set expandtab
" tab键转换为多少个空格
set softtabstop=4
" 设置tab键宽4个空格
set tabstop=4
" 开启语法高亮
syntax enable
" vim命令使用tab自动补全
set wildmenu
" 文件自动更新
set autoread
" 使用9跳转到行尾，默认0跳转到行首
map 9 $
" 设置在右下角显示输入的命令
set showcmd

" 输入的时候对(进行映射，输入(后会自动补全)并且将光标置于两个括号之间，下同或类似
imap ( ()<Esc>i
imap { {}<Esc>i
imap [ []<Esc>i

" 这里因为前后符号相同会导致递归，需要用inoremap防止递归
inoremap " ""<Esc>i
inoremap ' ''<Esc>i

" Java常用，因为上边定义好了自动补全括号和引号，所以这里不需要输入后括号和引号
imap psvm public static void main(String[<Esc>la args<Esc>la{<CR><CR><Esc>ki<Tab><Tab>
imap sout System.out.println(<Esc>la;<Esc>hi
" ----------------------------普通配置结束，不依赖任何插件----------------------------
EOF

# 安装vim插件
vim +PluginInstall +qall