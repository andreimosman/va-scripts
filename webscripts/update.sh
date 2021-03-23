#!/bin/sh
###########################################
# VirtexAdmin update app.                 #
# Mosman Consultoria e Desenvolvimento    #
# (mailto:consultoria@mosman.com.br)      #
# Andrei de Oliveira Mosman               #
##########################################

ARG=${1}

SILENCE=0

if [ "${ARG}" = "-q" ] ; then
        SILENCE=1
fi

printout() {
        if [ "${SILENCE}" -eq "0" ] ; then
                echo $@
        fi
}


LYNX=/usr/local/bin/lynx
LINKS=/usr/local/bin/links
BROWSER_OPT=-source
WGET=/usr/local/bin/wget
BROWSER=""

# Escolha do mecanismo de download da checksum
if [ -x ${WGET} ] ; then
        BROWSER=${WGET}
        BROWSER_OPT="-qO /dev/stdout"
elif [ -x ${LYNX} ] ; then
        BROWSER=${LYNX}
elif [ -x ${LINKS} ] ; then
        BROWSER=${LINKS}
fi

FAZUPDATE=1

install -d /mosman/virtex
cd /mosman/virtex
if [ -f va.tar.gz ] ; then
   #rm va.tar.gz

   if [ "" != "${BROWSER}" ] ; then
        CK=$( md5 va.tar.gz | cut -d '=' -f 2 | sed -E 's/ //g' )
        CK_REMOTO=$( ${BROWSER} ${BROWSER_OPT} http://dev.mosman.com.br/virtex-update/va.tar.gz.md5 )

        if [ "${CK}" != "${CK_REMOTO}" ] ; then
                #echo "FAZ DOWNLOAD";
        else
                #echo "NAO FAZ DOWN";
                FAZUPDATE=0
        fi
   fi
fi

if [ "${FAZUPDATE}" -eq 1 ] ; then
        printout "ATUALIZANDO SISTEMA... AGUARDE"
        #echo "FAZ UPDATE!!!";
        if [ -f va.tar.gz ] ; then
                rm va.tar.gz
        fi
        wget -q http://dev.mosman.com.br/virtex-update/va.tar.gz
        cd /
        tar -xzf /mosman/virtex/va.tar.gz
        chown -R www:www /mosman/virtex/framework /mosman/virtex/app
        chmod +x /mosman/virtex/app/cgi/stats
        chmod +x /mosman/virtex/app/bin/rc.virtex
	cd /mosman/virtex/app/var/update/
	sh upd.sh
        printout "SISTEMA ATUALIZADO COM SUCESSO"
else
        printout "O SISTEMA JA ESTA ATUALIZADO"
fi
