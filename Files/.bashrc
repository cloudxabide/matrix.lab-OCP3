# .bashrc

# User specific aliases and functions
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias please='/usr/bin/sudo $(history -p !!)'

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment and startup programs
TERM=vt100
EDITOR=vi
VISUAL=vi
MYHOSTNAME=`hostname | cut -f1 -d.`
GIT_EDTIOR=vim
TITLE="`/usr/bin/whoami`@`hostname -s`"
HISTCONTROL=ignoredups

set -o vi
