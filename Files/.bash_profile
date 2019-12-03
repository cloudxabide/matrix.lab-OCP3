# .bash_profile

# Get the aliases and functions
if [ -r ~/.bashrc ]; then
	. ~/.bashrc
fi

#  Source Secondary bash_profile(s) - EXPIREMENTAL
# I'm still working on the cleanest way to do this... source any "additional" profiles
if [ -f .bash_profile.d/* ]; then . ~/.bash_profile.d/*; fi

# User specific environment and startup programs
# If you need something to run every time you "login", then add it here.

