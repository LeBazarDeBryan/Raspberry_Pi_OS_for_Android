XAUTHORITY=$HOME/.Xauthority
export XAUTHORITY
LANG=C
export LANG
echo $$ > /tmp/xsession.pid
. $HOME/.xsession
