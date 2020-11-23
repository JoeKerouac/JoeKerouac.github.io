# 发生错误时退出
set -o errexit
# 更改yum源为网易163的
# 先备份
# shellcheck disable=SC2046
echo "更改yum源为网易163"
cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak.$(date "+%Y-%m-%d_%H:%M:%S")
curl http://mirrors.163.com/.help/CentOS7-Base-163.repo -o /etc/yum.repos.d/CentOS-Base.repo

# 刷新缓存
yum makecache
# 更新
yum -y update

cd ~/

# 编译VIM必须的依赖
yum install -y ncurses-devel.x86_64 gcc git

if ! [ -x "$(command -v vim)" ]; then
  echo "安装vim..."
  # 下载vim最新源码
  git clone --depth=1 https://github.com/vim/vim.git
  # 切换到vim目录，然后配置，巨型安装，同时允许多字节（支持中文，--enable-multibyte选项）
  cd vim
  ./configure --with-features=huge --enable-multibyte
  make
  make install
  echo "vim安装完毕"
else
  echo "当前系统已经存在vim，跳过vim安装"
fi


# 安装net-tools等工具，clang是后边vim的ale插件进行语法检查需要使用
yum install -y net-tools bash-completion bash-completion-extras ctags clang


installVimPlugin() {
  echo -e "\n\n准备安装vim插件：$1";
  # 如果当前没有安装，则安装
  if [ ! -d $1 ]; then
    git clone --depth=1 $2 ~/.vim/bundle/$1
  else
    echo "当前vim插件[$1]已安装"
  fi
  echo "vim插件$1安装完成"
}

echo "开始手动安装初始化vim插件"
# 安装vundle管理vim插件，先判断是否存在，有可能已经存在了
installVimPlugin "Vundle.vim" "https://github.com/gmarik/vundle.git"
installVimPlugin "nerdtree" "https://github.com/scrooloose/nerdtree.git"
installVimPlugin "supertab" "https://github.com/ervandew/supertab.git"
installVimPlugin "ale" "https://github.com/dense-analysis/ale.git"
installVimPlugin "vim-bracketed-paste" "https://github.com/ConradIrwin/vim-bracketed-paste.git"
installVimPlugin "vim-fugitive" "https://github.com/tpope/vim-fugitive.git"
installVimPlugin "vim-tags" "https://github.com/vim-scripts/vim-tags.git"
installVimPlugin "taglist" "https://github.com/vim-scripts/taglist.vim.git"


# 如果vimrc配置文件已经存在，那么备份
if [ -f "${HOME}/.vimrc" ]; then
  # shellcheck disable=SC2046
  mv ~/.vimrc ~/.vimrc.bak.$(date "+%Y-%m-%d_%H:%M:%S")
fi

# 配置vim
cat << EOF > ~/.vimrc
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

" Supertab插件，使用tab键完成代码提示，依赖bash-completion，bash-completion-extras
Plugin 'https://github.com/ervandew/supertab.git'

Plugin 'https://github.com/vim-scripts/vim-tags.git'

" 依赖ctags，代码浏览器，提供快速预览文件中的函数和变量的功能
Plugin 'https://github.com/vim-scripts/taglist.vim.git'

" 异步语法提示
Plugin 'https://github.com/dense-analysis/ale.git'

" 使用该插件代替每次复制前的 set paste 命令，防止格式错乱，同时复制的时候也不会匹配后边的快捷输入
Plugin 'https://github.com/ConradIrwin/vim-bracketed-paste.git'

" vim中的git插件
Plugin 'https://github.com/tpope/vim-fugitive.git'

call vundle#end()            " Vundle必须
filetype plugin indent on    " Vundle必须
" ----------------------------Vundle配置结束----------------------------

" ----------------------------插件配置开始，依赖相关插件----------------------------

" ===========================NERDTree插件配置开始==================================
" 自动打开NERDTree（目录树），该命令依赖于NERDTree插件
autocmd vimenter * NERDTree
"配置nerdtree使用alt+1打开关闭
nmap <A-1> :NERDTreeToggle <CR>
imap <A-1> <Esc>:NERDTreeToggle <CR>
" ===========================NERDTree插件配置结束==================================


" ===========================taglist插件配置开始==================================
" 配置快速调用taglist功能的映射，注意，下面两个映射依赖于后边普通配置的alt键映射修复
" 插入模式的映射，只在插入模式有效
inoremap <A-7> <Esc>:Tlist<Enter>a
" 普通模式的映射，只在普通模式有效
nnoremap <A-7> :Tlist<Enter>
" 窗口显示在右侧，等于1是显示在左侧
let Tlist_Use_Right_Window = 2
" 如果只有taglist一个窗口，那么关闭vim
let Tlist_Exist_OnlyWindow = 1
"设置tablist插件只显示当前编辑文件的tag内容，而非当前所有打开文件的tag内容
let Tlist_Show_One_File = 1
" ===========================taglist插件配置结束==================================


" ===========================ale插件配置开始==================================
" 使用clang对c、c++进行语法检查，需要保证机器上有clang（yum install clang）
let g:ale_linters = {
\   'c++': ['clang'],
\   'c': ['clang'],
\}
" 自定义error和warning图标
let g:ale_sign_error = '✗'
let g:ale_sign_warning = '⚡'
"显示Linter名称,出错或警告等相关信息
let g:ale_echo_msg_error_str = 'E'
let g:ale_echo_msg_warning_str = 'W'
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
" 普通模式下，sp前往上一个错误或警告，sn前往下一个错误或警告
nmap sp <Plug>(ale_previous_wrap)
nmap sn <Plug>(ale_next_wrap)
" <Leader>d查看错误或警告的详细信息（<Leader>键就是反斜杠\键）
nmap <Leader>d :ALEDetail<CR>

" 自定义的ALE状态栏，显示当前的语法错误数量
function! LinterStatus() abort
    let l:counts = ale#statusline#Count(bufnr(''))

    let l:all_errors = l:counts.error + l:counts.style_error
    let l:all_non_errors = l:counts.total - l:all_errors

    return l:counts.total == 0 ? 'OK' : printf(
    \  '%d ⚡   %d ✗',
    \  all_non_errors,
    \  all_errors
    \)
endfunction
" 设置状态栏显示内容
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]\ %{strftime(\"%y/%m/%d/\ -\ %H:%M\")}\   %{LinterStatus()}
" ===========================ale插件配置结束==================================

" ----------------------------插件配置结束，依赖相关插件----------------------------


" ----------------------------普通配置开始，不依赖任何插件----------------------------
" 开启语法高亮
syntax enable
syntax on
" history文件需要记录的行数
set history=500
" 默认情况下vim中删除键只能删除本次打开文件新插入的内容，该配置可以使删除键随意删除内容
set backspace=2
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
" vim命令使用tab自动补全
set wildmenu
" 文件自动更新
set autoread
" 使用9跳转到行尾，默认0跳转到行首
map 9 $
" 设置在右下角显示输入的命令
set showcmd
" 设置右下角显示当前光标行号信息
set ruler

" 修复alt快捷键映射问题，因为alt+key通过终端发送到Linux的实际上是Esc+key，也就是当你按下Alt+1的时候实际通过终端发送到Linux上的是Esc+1，所以
" 这里通过循环的方式，将Alt+[0-9]的快捷键都重新映射为Esc+[0-9]，这样可以最简单的解决快捷键映射问题，但是这有可能造成一个新的问
" 题，就是当我们按下Alt+1的时候实际上vim感知到的是Esc+1，而当我们真的想按下Esc+1的时候有可能跟我们的alt快捷键冲突，例如设置alt+i是删除，这样
" 当我们使用Esc从插入模式退出到普通模式，然后迅速的按i想要进入插入模式时，此时实际会执行删除操作，不过该问题可以通过设置较短的timeoutlen来解决
" 设置mapping延迟，单位毫秒，超过该时间后key map失效
set timeoutlen=1000
" 设置key code的延迟
set ttimeoutlen=1000
let c='a'

let c='0'
while c <= '9'
  exec "set <M-".toupper(c).">=\e".c
  exec "imap \e".c." <M-".toupper(c).">"
  let c = nr2char(1+char2nr(c))
endw


" 输入的时候对(进行映射，输入(后会自动补全)并且将光标置于两个括号之间，下同或类似
imap ( ()<Esc>i
imap { {}<Esc>i
imap [ []<Esc>i

" 这里因为前后符号相同会导致递归，需要用inoremap防止递归
inoremap " ""<Esc>i
inoremap ' ''<Esc>i


" 在插入模式下将ctrl+h、j、k、l分别映射为左、下、上、右方向键
inoremap <C-h> <Esc>i
inoremap <C-j> <Esc>ja
inoremap <C-k> <Esc>ka
inoremap <C-l> <Esc>la

" Java常用，因为上边定义好了自动补全括号和引号，所以这里不需要输入后括号和引号
imap psvm public static void main(String[<Esc>la args<Esc>la{<CR><CR><Esc>ki<Tab><Tab>
imap sout System.out.println(<Esc>la;<Esc>hi
" ----------------------------普通配置结束，不依赖任何插件----------------------------
EOF

# 安装vim插件
vim +PluginInstall +qall

# 将vi重命名为vim
cat << EOF >> ~/.bash_profile
alias vi=vim
EOF

echo -e "\n\n安装清单："
echo -e "\t|___更改yum源为网易163"
echo -e "\t|___安装gcc"
echo -e "\t|___安装ncurses-devel.x86_64"
echo -e "\t|___安装vim"
echo -e "\t|___安装net-tools"
echo -e "\t|___安装bash-completion"
echo -e "\t|___安装bash-completion-extras"
echo -e "\t|___安装git"
echo -e "\t|___安装clang"
echo -e "\t|___vim插件安装列表："
echo -e "\t|\t|___Vundle.vim"
echo -e "\t|\t|___nerdtree"
echo -e "\t|\t|___supertab"
echo -e "\t|\t|___ctags-vim"
echo -e "\t|\t|___ale"
echo -e "\t|\t|___vim-bracketed-paste"
echo -e "\t|\t|___vim-fugitive"
echo -e "\t|___系统vi命令替换为vim"
echo -e "enjoy that"
