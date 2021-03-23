#!/bin/sh

# Configuracoes
DIALOG=cdialog
BACKTITLE="Virtex Instalacao"
BASEDIR=../dist

TARGET=/var/mnt
VA_PATH=/mosman/virtex
VA_PREFIX=${TARGET}/${VA_PATH}

SCRIPT_DIR=${PWD}
TPL_CONF="${SCRIPT_DIR}/tpl"

#echo SCD: ${SCRIPT_DIR}
#echo TPL: ${TPL_CONF}
#exit;

# DEFAULTS
HTTPD_SERVER=127.0.0.1
EMAIL_SERVER=127.0.0.1
DB_NAME=virtex

# Funcoes
abortar() {

	clear;
	echo ""
	echo "Instalacao Cancelada!!!!"
	echo ""
	exit;

}



# Informacoes da Maquina

IFACELIST=`/sbin/ifconfig -l|sed -E 's/(plip|lo|sl|ppp|tun|pty|md|faith|pflog)[0-9]+//g'|sort`
HDLIST=`dmesg |grep -E '[as]d[0-9]+:'|sed -E 's/://g' |sed -E 's/ /|/'|sed -E 's/ /|/'|sed -E 's/( at ).*//g'|sed -E 's/[\<\>]//g'|sed -E 's/ /_/g'|sort`
CDLIST=`dmesg |grep -E '[as]?cd[0-9]+:'|sed -E 's/://g' |sed -E 's/ /|/'|sed -E 's/ /|/'|sed -E 's/( at ).*//g'|sed -E 's/[\<\>]//g'|sed -E 's/ /_/g'|sort`

#IFACELIST="vr0 xl0 xl1 xl2 ed0"


# ELIMINA REGISTROS DUPLICADOS DO DMESG
OLD=""
LISTA=""
for hd in ${HDLIST} ; do
	if [ "$hd" = "$OLD" ] ; then
		# HD REPEDIDO
	else
		LISTA="${LISTA} ${hd}"
	fi
	OLD="${hd}"
done
HDLIST=${LISTA}
#echo ${HDLIST}
#sed -E 's/([as]d[0-9])/{1}/g'

hd=""	# HD
tm=""	# TAMANHO
ds=""	# DESCRICAO
MENU_HD=""
LISTA=`echo ${HDLIST}|sed -E 's/\|/ /g'`
#echo "LISTA: ${LISTA}"
for info in ${LISTA} ; do
	if [ ! $hd ] ; then
		hd=${info}	
	else
		if [ ! $tm ] ; then
			tm=${info}
		else
			ds=${info}
			MENU_HD="${MENU_HD} ${hd} ${ds}(${tm})"			
			
			# zera tudo
			hd=""
			tm=""
			ds=""
		fi
		
	fi

done

MENU_HD=`echo ${MENU_HD}|sed -E 's/^ //g'`

#echo $MENU_HD


#echo "${HDLIST}"
#exit;
#${DIALOG} --clear --backtitle "$BACKTITLE" --title "ESCOLHA O DESTINO" \
#	--menu "Escolha o disco no qual sera instalado o VirtexAdmin.\n\
#ATENCAO. Todos os arquivos existentes neste disco serao removidos.\n"\ 20 51 2 \
#	"TESTE" "Laalalalalal" \
#	"T2"	"Lalalal"


disco() {

HD=

while [ "${HD}" = "" ] ; do


HD=$( $DIALOG --stdout \
	--clear \
	--backtitle "${BACKTITLE}" \
	--title "ESCOLHA O DESTINO" \
        --menu \
"Bem vindo a instalacao do VirtexAdmin. \n\
\n\
Para continuar escolha o disco qual sera \n\
instalado o VirtexAdmin. \n\
\n\
ATENCAO. O conteudo deste disco sera apagado.\n\
Selecione o disco:\n\n" 15 51 2 \
	${MENU_HD} )

# Se o HD nao foi escolhido aborta
####
if [ "${HD}" = "" ] ; then
	abortar
fi



# CONFIRMACAO DE QUE OS DADOS DO HD SERAO PERDIDOS

${DIALOG} --clear --backtitle "${BACKTITLE}" \
	--title "ATENCAO!!!!" --yesno \
"TODOS OS DADOS DO HD '${HD}' SERAO APAGADOS.\n\
\n\
DESEJA CONTINUAR.\n" 7 51

if [ "$?" -ne 0  ] ; then
	#disco
	HD=""
fi



done


}

# PARTICIONAR E FORMATAR


formata_disco() {

# DIALOG STUFF
echo "XXX"
echo 5 # 5%
echo "Inicializando o disco"
echo "XXX"



# Formata o disco
/bin/dd if=/dev/zero of=/dev/${HD} count=128 2> /dev/null > /dev/null
# Usa TODO o espaco em disco
/sbin/fdisk -I ${HD} 2> /dev/null > /dev/null
# Inicializacao do disklabel
/sbin/disklabel -rw ${HD}s1 auto 2> /dev/null > /dev/null

# Extrai o modelo a partir do disco
modelo=/tmp/label.modelo
/sbin/disklabel -r ${HD}s1 > $modelo 2> /dev/null

# Figure out how much blocks it is still avaiable
setores_disco=`/sbin/disklabel -r ${HD}s1 | /usr/bin/tr -s ' ' | \
          /usr/bin/sed 's/^ //g' | /usr/bin/grep '^c: ' | \
          /usr/bin/cut -f2 -d' '`


#
# PADROES DE TAMANHO (em MB)
###################################
raiz=1024
swap=1024
tmp=512
usr=2048
var=2048

# Define o numero de blocos de cada fatia
b_raiz=`expr $raiz \* 1024 \* 2`
b_swap=`expr $swap \* 1024 \* 2`
b_tmp=`expr $tmp \* 1024 \* 2`
b_usr=`expr $usr \* 1024 \* 2`
b_var=`expr $var \* 1024 \* 2`
# /mosman pega o resto do disco
b_mosman=`expr $setores_disco \- $b_raiz \- $b_swap \- $b_tmp \- $b_usr \- $b_var`

# Defines offset to /var and /usr slices
off_tmp=`expr $b_raiz \+ $b_swap`
off_usr=`expr $b_raiz \+ $b_swap \+ $b_tmp`
off_var=`expr $b_raiz \+ $b_swap \+ $b_tmp \+ $b_usr`
off_mosman=`expr $b_raiz \+ $b_swap \+ $b_tmp \+ $b_usr \+ $b_var`

# The base model to be used by disklabel
echo "a: $b_raiz 0 4.2BSD 0 0 0" >>  $modelo
echo "b: $b_swap $b_raiz swap" >>  $modelo 
echo "d: $b_tmp $off_tmp 4.2BSD 0 0 0" >> $modelo
echo "e: $b_usr $off_usr 4.2BSD 0 0 0"  >>  $modelo 
echo "f: $b_var $off_var 4.2BSD 0 0 0"  >>  $modelo  
echo "g: $b_mosman $off_mosman 4.2BSD 0 0 0"  >>  $modelo  

# Create disks partitions and sets it as "bootavel"
/sbin/disklabel -R -B ${HD}s1 $modelo 2>&1 > /dev/null
#sleep 2


# DIALOG STUFF
echo "XXX"
echo 10 # 5%
echo "Formatando /"
echo "XXX"

# Filesystem for /
/sbin/newfs /dev/${HD}s1a 2>&1 > /dev/null
#sleep 2

# DIALOG STUFF
echo "XXX"
echo 16 # 16%
echo "Formatando /tmp"
echo "XXX"

# Filesystem for /tmp
/sbin/newfs /dev/${HD}s1d 2>&1 > /dev/null
#sleep 2

# DIALOG STUFF
echo "XXX"
echo 22 # 22%
echo "Formatando /usr"
echo "XXX"

# Filesystem for /usr
/sbin/newfs /dev/${HD}s1e 2>&1 > /dev/null
#sleep 2

# DIALOG STUFF
echo "XXX"
echo 42 # 42%
echo "Formatando /usr"
echo "XXX"

# Filesystem for /var
/sbin/newfs /dev/${HD}s1f 2>&1 > /dev/null
#sleep 2

# DIALOG STUFF
echo "XXX"
echo 72 # 72%
echo "Formatando /mosman"
echo "XXX"

# Filesystem for /mosman
/sbin/newfs /dev/${HD}s1g 2>&1 > /dev/null

# DIALOG STUFF
#echo "XXX"
#echo 95 # 95%
#echo "Criando dispositivos"
#echo "XXX"
#sleep 2



# Make devices if it does not exists yet.
#if [ ! -c /dev/${HD} ]; then
#  (cd /dev && MAKEDEV ${HD})
#fi

#if [ ! -c /dev/${HD}s1 ]; then
#  (cd /dev && MAKEDEV ${HD}s1)
#fi

#if [ ! -c /dev/${HD}s1a ]; then
#  (cd /dev && MAKEDEV ${HD}s1a)
#fi

#if [ ! -c /dev/${HD}s1b ]; then
#  (cd /dev && MAKEDEV ${HD}s1b)
#fi

#if [ ! -c /dev/${HD}s1d ]; then
#  (cd /dev && MAKEDEV ${HD}s1e)
#fi

#if [ ! -c /dev/${HD}s1e ]; then
#  (cd /dev && MAKEDEV ${HD}s1e)
#fi

#if [ ! -c /dev/${HD}s1f ]; then
#  (cd /dev && MAKEDEV ${HD}s1e)
#fi

#if [ ! -c /dev/${HD}s1g ]; then
#  (cd /dev && MAKEDEV ${HD}s1g)
#fi

echo "XXX"
echo 100 # 100%
echo "Concluido!"
echo "XXX"



}

#
# Prepara o alvo pra copia
#####
monta_alvo() {

	echo XXX
	echo 0
	echo Montando Dispositivos
	echo XXX
	
	#sleep 1

	# Cria o MountPoint de destino
	install -d ${TARGET}
	mount /dev/${HD}s1a ${TARGET}

	# Cria os mount points
	install -d ${TARGET}/tmp
	chmod 777 ${TARGET}/tmp
	chmod +t ${TARGET}/tmp
	install -d ${TARGET}/usr
	install -d ${TARGET}/var
	install -d ${TARGET}/mosman

	# Monta a estrutura completa
	mount /dev/${HD}s1d ${TARGET}/tmp
	mount /dev/${HD}s1e ${TARGET}/usr
	mount /dev/${HD}s1f ${TARGET}/var
	mount /dev/${HD}s1g ${TARGET}/mosman
	install -d ${TARGET}/dev
	mount -t devfs dev ${TARGET}/dev
	install -d ${TARGET}/mnt
	mount -t cd9660 /dev/acd0 ${TARGET}/mnt

	# Permissoes
	chmod +t ${TARGET}/tmp
	
	echo XXX
	echo 100
	echo Finalizado
	echo XXX
	
	#sleep 1

}

#
# Desmonta o alvo
#####
desmonta_alvo() {
	
	echo XXX
	echo 0
	echo Desmontando dispositivos
	echo XXX
	
	#sleep 1

	umount ${TARGET}/mosman
	umount ${TARGET}/var
	umount ${TARGET}/usr
	umount ${TARGET}/tmp
	umount ${TARGET}/dev
	# cdrom
	umount ${TARGET}/mnt
	umount ${TARGET}
	
	echo XXX
	echo 100
	echo Finalizado
	echo XXX
	#sleep 1

}

# INSTALAR BASE (INCLUINDO KERNEL E BOOT)
instala_base() {
	#echo "BASEDIR: ${BASEDIR}"
	echo XXX
	echo 6
	echo Instalando a base do FREEBSD 6.1
	echo XXX

	# COPIA A BASE
	cat ${BASEDIR}/base/base.?? | tar --unlink -xpzf - -C ${TARGET} 2>&1 >/dev/null
	cp ${BASEDIR}/mosman/localtime ${TARGET}/etc
	install -d ${TARGET}/cdrom
	
	echo XXX
	echo 72
	echo Instalando o kernel
	echo XXX

	# COPIA O KERNEL
	cat ${BASEDIR}/kernel/kernel.?? | tar --unlink -xpzf - -C ${TARGET} 2>&1 >/dev/null

	echo XXX
	echo 85
	echo Instalando Virtex
	echo XXX

	# Instala Virtex 
	tar -C ${TARGET} -zxf ${BASEDIR}/mosman/va.tar.gz
	tar -C ${TARGET} -zxf ${BASEDIR}/mosman/splash.tgz	
	install -d ${TARGET}/${VA_PATH}/dados/emails
	install -d ${TARGET}/${VA_PATH}/dados/hospedagem
	install -d ${TARGET}/${VA_PATH}/dados/logs
	install -d ${TARGET}/${VA_PATH}/dados/named
	install -d ${TARGET}/${VA_PATH}/dados/carnes
	install -d ${TARGET}/${VA_PATH}/dados/estatisticas
	install -d ${TARGET}/${VA_PATH}/dados/contratos

	chroot ${TARGET} chown -R nobody:nobody ${VA_PATH}
	
	echo XXX
	echo 100
	echo Finalizado
	echo XXX
	
	
	#sleep 2

}

# CONFIGURACOES ADICIONAIS
instala_configs() {

	echo XXX
	echo 1
	echo Configurando FSTAB
	echo XXX

	# FSTAB
	echo -n > ${TARGET}/etc/fstab
	echo "/dev/${HD}s1b	none	swap	sw	0	0" >> ${TARGET}/etc/fstab
	echo "/dev/${HD}s1a	/	ufs	rw	1	1" >> ${TARGET}/etc/fstab
	echo "/dev/${HD}s1g	/mosman	ufs	rw	2	2" >> ${TARGET}/etc/fstab
	echo "/dev/${HD}s1d	/tmp	ufs	rw	2	2" >> ${TARGET}/etc/fstab
	echo "/dev/${HD}s1e	/usr	ufs	rw	2	2" >> ${TARGET}/etc/fstab
	echo "/dev/${HD}s1f	/var	ufs	rw	2	2" >> ${TARGET}/etc/fstab
	echo "/dev/acd0	/cdrom	cd9660	ro,noauto	0	0" >> ${TARGET}/etc/fstab

	#sleep 1
	
	echo XXX
	echo 54
	echo Configurando RC Basico
	echo XXX

	# RC.CONF INICIAL
#	echo 'hostname=virtex'  >> ${TARGET}/etc/rc.conf
#	echo 'firewall_enable="YES"' >> ${TARGET}/etc/rc.conf
#	echo 'firewall_script="/etc/rc.firewall"' >> ${TARGET}/etc/rc.conf
#	echo 'firewall_type="open"'  >> ${TARGET}/etc/rc.conf
	
	#sleep 1
	
	echo XXX
	echo 100
	echo Conluido
	echo XXX
	
	#sleep 1
	
}

config_senha_modotexto() {

	echo -n
	
	while ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --title "SENHA" --yesno "DESEJA CONFIGURAR A SENHA DO ROOT?" 8 50 ; do
	
		if ! chroot ${TARGET} /usr/bin/passwd ; then
			sleep 1
			${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --msgbox "Erro ao registrar a senha" 8 50
		else
			break
		fi
	
	done

}


#
# Configuracoes do VA
########################

#
# Codes
#

# codigos p/ tipo servidor
ST_MASTER_CODE=1
ST_SLAVE_CODE=2

# codigos para atuadores
A_BLTCP_CODE=1
A_BLPPPOE_CODE=2
A_DISCADO=3
A_EMAIL=4
A_HOSP=5

PACKAGE_DIR="../packages"

# verifica se existe determinado valor dentro de array
in_array() {
	v=$1
	shift
	for i in "$@"; do
		if test "$i" = "$v"; then
			return 0
		fi
	done
	return 1
}



tipo_servidor() {

	SERVER_TYPE=""
	while [ "${SERVER_TYPE}" = "" ] ; do

		SERVER_TYPE=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
			--title "Tipo de Servidor" \
	  		--radiolist "Selecione o tipo de servidor:" 10 40 4 \
	        	$ST_MASTER_CODE "Master (ou unico)" on \
		        $ST_SLAVE_CODE "Slave (atuador bandalarga)" off )

		if [ "$?" -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a instalacao???" 8 50 ; then
				abortar;
			fi

			continue
		fi
		
		ATUADORES=""
	
		if [ "${SERVER_TYPE}" -eq "${ST_MASTER_CODE}" ] ; then # Tipo de servidor master
			# Email e Hospedagem on
			#options="$A_EMAIL Email on $A_HOSP Hospedagem on "
			ATUADORES="3 4 5"
		else
			# Email e Hospedagem off
			#options="$A_EMAIL Email off $A_HOSP Hospedagem off "
			ATUADORES=""
		fi

	done

}


# Instalacao de pacotes
####

confirma_instalacao() {

	while true ; do
		${DIALOG} --backtitle "$BACKTITLE" --title "Instalar ?"  --yesno "O instalador esta pronto para iniciar a instalacao.\n\nTODOS OS DADOS DO HD SERAO PERDIDOS\n\nDeseja Continuar?" 10 55
		if [ $? -ne 0 ] ; then # nao continuar com a instalacao

			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a instalacao???" 8 50 ; then
				abortar;
			fi

			continue

		fi
		
		break
	done

}


sys_pkg_add() {
	OPT="$1"
	PKG_LIST=$2

	(
		i=1
		TOTAL=$( echo $PKG_LIST | wc -w )
		# enquanto estiver instalando os pacotes
		echo 'cd /mnt/packages' > ${TARGET}/pkg.sh
		if [ "${OPT}" = "n" ] ; then
			# Pacotes normais
			echo 'pkg_add $1 2>&1 >/dev/null' >> ${TARGET}/pkg.sh
		else
			# Pacotes com scripts medonhos
			echo 'pkg_add -I $1 2>&1 >/dev/null' >> ${TARGET}/pkg.sh
		fi
		#echo 'echo LALALA: $1' >> ${TARGET}/pkg.sh
		#echo 'sleep 1' >> ${TARGET}/pkg.sh
		
		#export PKG_PATH=/mnt/packages
		
		#PKGLOG=/var/pkg_log.txt

		for pkg in $PKG_LIST; do
			PCT=$(($i*100/$TOTAL))

 			# envia a porcentagem para o dialog
			echo "XXX"
	  		echo $PCT
  			echo "Instalando ${pkg#*/}..."
			echo "XXX"
			#let i++
			i=$(($i+1))
 			#sleep 1s 
			#pkg_add -f -I -C ${TARGET} /mnt/${pkg#*/}
			#chroot ${TARGET} pkg_add -I /mnt/${pkg#*/} 2>&1 > /dev/null
			chroot ${TARGET} sh /pkg.sh ${pkg#*/}
			#if [ "${OPT}" = "n" ] ; then
			#	pkg_add -C /var/mnt /mnt/packages/${pkg#*/} 2>&1 >> ${PKGLOG}
			#else
			#	pkg_add -C /var/mnt -I /mnt/packages/${pkg#*/} 2>&1 >> ${PKGLOG}
			#fi
			
	  	done
	  	
	  	#rm ${TARGET}/pkg.sh
 
	  	# instalacao finalizada, mostra a porcentagem final
  		echo 100
  	
	  ) 
	  



}

va_instala_pacotes() {

	PKG_HOSP="proftpd"
	PKG_HOSP_ESP=""
	PKG_EMAIL="courier-imap courier-authlib-base"
	PKG_EMAIL_ESP="postfix"

	PKG_EXCLUDE="php5-snmp"
	

	# regex para remover da lista os pacotes que nao serao instalados
	rgx=""
	rgx_e=""
	#in_array $A_HOSP "${ATUADORES[@]}"
	in_array "$A_HOSP" ${ATUADORES}
	if [ $? -eq 1 ] ; then
		for i in $PKG_HOSP; do
			rgx="${rgx}^${i}|"
		done
	else
		for i in $PKG_HOSP_ESP; do
			rgx_e="${rgx}${i}|"
		done
	fi

#	in_array $A_EMAIL "${ATUADORES[@]}"
	in_array "$A_EMAIL" ${ATUADORES}
	if test $? -eq 1; then
		for i in $PKG_EMAIL; do
			rgx="${rgx}^${i}|"
		done
	else
		for i in $PKG_EMAIL_ESP; do
			rgx_e="${rgx}${i}|"
		done
	fi

	# Lista de pacotes que serao excluidos da instalacao
	for i in $PKG_EXCLUDE $PKG_EMAIL_ESP $PKG_HOSP_ESP; do
		rgx="${rgx}^${i}|"	
	done

	# Monta lista completa
	FULL_LIST_FILE=/tmp/package.$$.fulllist
	
	ls -1 $PACKAGE_DIR/ > ${FULL_LIST_FILE}

	rgx=$( echo $rgx | sed -E 's/\|$//g' )
	if test -n "$rgx"; then
		rgx=${rgx%|}
		#PKG_LIST=$( cat ${FULL_LIST_FILE} | grep -v -E "$rgx" )
		#for i in $( ls -1 $PACKAGE_DIR/ | grep -v -E '$rgx' ); do
		for i in $( cat ${FULL_LIST_FILE} | grep -v -E "$rgx" ); do
			PKG_LIST="$PKG_LIST $i"
		done
	else
		PKG_LIST=$( cat ${FULL_LIST_FILE} )
		#for i in $PACKAGE_DIR/*; do
		#	PKG_LIST="$PKG_LIST $i"
		#done
	fi
	
	# Instala os pacotes que nao contem scripts que requer input do usuario
	#echo "PKGS BONS"
	sys_pkg_add "n" "${PKG_LIST}"

	PKG_LIST=""
	rgx_e=$( echo $rgx_e | sed -E 's/\|$//g' )
	for i in $( ls -1 $PACKAGE_DIR/ | grep -E "$rgx_e" ); do
		PKG_LIST="$PKG_LIST $i"
	done
	
	# Instala os pacotes que contem scrips escrotos
	#echo "PKGS ESCROTOS"
	#echo ""
	sys_pkg_add "x" "${PKG_LIST}" 


}

#
# Configurar Interface Externa
#
va_interface_externa() {
	NETWORK_CONF=${VA_PREFIX}/app/etc/network.ini
	
	${DIALOG} --stdout --title "Network"  --yesno "Voce deseja configurar a interface externa ?" 7 55 
	if [ $? -ne 0 ]; then
		return
	fi

	#itfs=( xl0 ed0 vr0 plip0 lo0 )

	# Configurar interface externa
	a=0
	options=""
	#itfs=${IFACELIST}
	#for i in ${IFACELIST}; do
	#	if test $a -eq 0; then
	#		st="on"
	#	else
	#		st="off"
	#	fi 
	#	#let a++
	#	a=`expr ${a} \+ 1`
	#	options="$options $a $i $st "
	#done
	
	options=""
	num=0
	
	for iface in ${IFACELIST} ; do
		options="${options} $iface Rede"
		num=`expr ${num} \+ 1`
		#echo $iface
	done
	#echo
	#echo ${options}
	#sleep 2
	
	while [ -z "${EXTIF}" ] ; do
	
		EXTIF=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
			--title Network \
			--menu "Selecione a interface externa:" 12 40 $num \
			$options )
		if [ "$?" -ne 0 ] ; then

			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao da rede???" 8 50 ; then
				break;
			fi
		fi

		if [ ! -z "${EXTIF}" ] ; then

			cancel=0
			IP=""
			while test -z "$IP"; do
				IP=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "IP Address da Interface Externa" --inputbox "IP ${EXTIF}:" 8 40 )
				if test $? -ne 0; then
					cancel=1
					break;
				fi			
			done
			if [ $cancel -eq 1 ]; then
				EXTIF=""
				continue
			fi 
			
			cancel=0
			NETMASK=""			
			while test -z "$NETMASK"; do
				NETMASK=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "Netmask da Interface Externa" --inputbox "Netmask ${EXTIF}:" 8 40 "255.255.255.0" )
				if test $? -ne 0; then
					cancel=1
					break;
				fi						
			done
			if [ $cancel -eq 1 ]; then
				EXTIF=""
				continue
			fi 
			
			cancel=0
			GATEWAY=""
			while test -z "$GATEWAY"; do
				GATEWAY=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "Gateway da Inteface Externa" --inputbox "Gateway ${EXTIF}:" 8 40 )
				if test $? -eq 0 ; then
					if [ -z "GATEWAY" ] ; then
						# O cara opcionalmente deixou em branco
						if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja ignorar a configuracao do gateway (deixar em branco) ???" 8 50; then
							break;
						else
							continue;
						fi
					fi
				else
					cancel=1
					break;
				fi			
			done
			
			if [ $cancel -eq 1 ]; then
				EXTIF=""
				continue
			fi 

			cancel=0
			NAT=""
			# TODO: SE FOR A UNICA INTERFACE NAO PERGUNTA DO NAT
			if [ $num -le 1 ] ; then
				NAT="0"
			else
				while test -z "$NAT"; do
					${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja habilitar NAT na interface ???" 8 50
					RETORNO=$?
					if [ ${RETORNO} -eq 0 ] ; then
						NAT="1"
					else
						if [ ${RETORNO} -eq 1 ] ; then
							NAT="0"
						else
							NAT=""
							cancel=1
							break;
						fi
					fi
				done
				if [ $cancel -eq 1 ]; then
					EXTIF=""
					continue
				fi 
				cancel=0
			fi

			DEFAULT_GATEWAY=$GATEWAY
			EXTIP=$IP
			EXTNETMASK=$NETMASK
					
			cat <<EOF > $NETWORK_CONF
[${EXTIF}]		
status=up
type=external
ipaddr=$IP
netmask=$NETMASK
gateway=$GATEWAY
nat=${NAT}

EOF

		fi
	done
}


va_config_hospedagem() {
	HOSP_CONF=${VA_PREFIX}/app/etc/hospedagem.ini

	# Cria o arquivo com informacoes dummy
	cat <<EOF > $HOSP_CONF
[127.0.0.1]
enabled=0

EOF

}

va_config_email() {
	EMAIL_CONF=${VA_PREFIX}/app/etc/email.ini

	# Cria o arquivo com informacoes dummy
	cat <<EOF > $EMAIL_CONF
[127.0.0.1]
enabled=0

EOF

}

va_config_dns() {
	DNS_CONF=${VA_PREFIX}/app/etc/dns.ini

	# Cria o arquivo com informacoes dummy
	cat <<EOF > $DNS_CONF
[127.0.0.1]
enabled=0

EOF

}

va_config_bandalarga() {

	# remove interface externa da lista
	if [ -n "$EXTIF" ]; then
		IFACELIST_INTERNAS=$( echo $IFACELIST | sed -E "s/$EXTIF//g" | sed -E "s/  / /g")
	else
		IFACELIST_INTERNAS=$IFACELIST
	fi

	options=""
	num=0
	
	for iface in ${IFACELIST_INTERNAS} ; do
		options="${options} $iface Rede"
		num=`expr ${num} \+ 1`
	done

	
	sleep 5
	
	if [ ! -n "${IFACELIST_INTERNAS}" ] ; then
		return
	else
		CONF_CLIENTES_BL=""
		# Deseja configurar clientes de Banda Larga ?
		while [ -z "${CONF_CLIENTES_BL}" ] ; do
			${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja fornecer acesso Banda Larga (radio/cabo) nesta maquina ???" 8 50 
			RESPOSTA=$?
			
			if [ $RESPOSTA -eq 0 ] ; then
				CONF_CLIENTES_BL="sim"
			else
				if [ $RESPOSTA -eq 1 ] ; then
					CONF_CLIENTES_BL="nao"
				else
					CONF_CLIENTES_BL=""
					if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao do atuador Banda Larga???" 8 50 ; then
						cancel=1
						break;
					fi
				fi
			fi
		done
	fi
	
	# TODO: Escolher quais os tipos de acesso bandalarga que serao fornecidos.

	ATUADORES_BL=""
	
	while [ "${ATUADORES_BL}" = "" ] ; do

		ATUADORES_BL=$( ${DIALOG} --stdout  --backtitle "$BACKTITLE" \
			--checklist "Selecione os Atuadores de Banda Larga:" 12 40 5 \
			$A_BLTCP_CODE "TCP/IP" on \
			$A_BLPPPOE_CODE "PPPOE" on \
			)

		if [ "$?" -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao dos atuadores de Banda Larga ???" 8 50 ; then
				break;
			fi

			continue
		fi

		ATUADORES_BL=`echo $ATUADORES_BL | sed -e 's/"//g'`
		
	done
	
	ATUADORES="${ATUADORES} ${ATUADORES_BL}"
	
}

va_config_tcpip() {
	TCPIP_CONF=${VA_PREFIX}/app/etc/tcpip.ini

	# Cria o arquivo com informacoes dummy
	cat <<EOF > $TCPIP_CONF
[zz]
nas_id=0
enabled=0

EOF


	# Verifica se a configuracao do TCPIP foi setada na tela de selecao de Atuadores
	if ! echo "$ATUADORES" | grep -q "$A_BLTCP_CODE" ; then 
		return
	fi

	if [ -n "${IFACELIST_INTERNAS}" ] ; then

		if [ "${CONF_CLIENTES_BL}" = "sim" ] ; then

			INTIF=""
			while [ -z "${INTIF}" ] ; do
				cancel=0
				INTIF=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
					--title "BANDA LARGA TCPIP" \
					--menu "Selecione a interface (placa) utilizada para clientes tcp/ip:" 12 40 $num \
					$options )

				if [ $? -ne 0 ] ; then
					# Confirmar se o cara deseja cancelar a instalacao
					if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao do atuador tcp/ip???" 8 50 ; then
						cancel=1
						break;
					fi
				fi
			done
			NAS_ID=1

		cat <<EOF > $TCPIP_CONF
[${INTIF}]
nas_id=$NAS_ID
enabled=1
fator=2

EOF


	
		fi
	fi
	
}

va_config_pppoe() {
	PPPOE_CONF=${VA_PREFIX}/app/etc/pppoe.ini
	NETWORK_CONF=${VA_PREFIX}/app/etc/network.ini

	# Cria o arquivo com informacoes dummy
	cat <<EOF > $PPPOE_CONF
[zz]
nas_id=0
enabled=0

EOF


	# Verifica se a configuracao do TCPIP foi setada na tela de selecao de Atuadores
	if ! echo "$ATUADORES" | grep -q $A_BLPPPOE_CODE ; then 
		return
	fi

	if [ -n "${IFACELIST_INTERNAS}" ] ; then

		if [ "${CONF_CLIENTES_BL}" = "sim" ] ; then

			INTIF=""
			while [ -z "${INTIF}" ] ; do
				cancel=0
				INTIF=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
					--title "BANDA LARGA PPPoE" \
					--menu "Selecione a interface (placa) utilizada para clientes pppoe:" 12 40 $num \
					$options )

				if [ $? -ne 0 ] ; then
					# Confirmar se o cara deseja cancelar a instalacao
					if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao do atuador pppoe???" 8 50 ; then
						cancel=1
						break;
					fi
				fi
			done
			NAS_ID=2
			
			if [ ! -z "${INTIF}" ] ; then
			
		cat <<EOF > $PPPOE_CONF
[${INTIF}]
nas_id=$NAS_ID
enabled=1
fator=2

EOF

		cat <<EOF >> $NETWORK_CONF

[${INTIF}]
status=up	

EOF
			fi

		fi
	fi

}


va_config_si() {
	I_HOSTS_CONF=${VA_PREFIX}/app/etc/infocenter.hosts.ini
	I_SERVER_CONF=${VA_PREFIX}/app/etc/infocenter.server.ini	
	I_USERS_CONF=${VA_PREFIX}/app/etc/infocenter.users.ini
	
	# GERA INFORMACOES DO ALEM
	CHAVE=$( head -c 10 /dev/random | b64encode /dev/null |sed -E 's/^begin.*//g' | sed -E 's/=//g' | sed -E 's/[^A-Za-z0-9]/x/g' | grep -v -E '^$' )
	U="virtex"
	PASS=$( head -c 10 /dev/random | b64encode /dev/null |sed -E 's/^begin.*//g' | sed -E 's/=//g' | sed -E 's/[^A-Za-z0-9]/x/g' | grep -v -E '^$' )
	
# gen ini files
cat <<EOF > $I_HOSTS_CONF
[local]
host=127.0.0.1
port=11000
chave=$CHAVE
username=$U
password=$PASS
enabled=1
EOF

cat <<EOF > $I_SERVER_CONF
[geral]
chave=$CHAVE
host=0.0.0.0
port=11000
EOF

cat <<EOF > $I_USERS_CONF
[$U]
password=$PASS
enabled=1
EOF

}


va_host_config() {
	
	if [ "${SERVER_TYPE}" -eq "${ST_MASTER_CODE}" ] ; then 
		HOSTDOMAIN="virtexadmin"
	else
		HOSTDOMAIN="atuador"
	fi

}

va_config_domain () {
	NOME_PROVEDOR=""
	while test -z "$NOME_PROVEDOR"; do
		NOME_PROVEDOR=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "Preferencias" --inputbox "Nome do Provedor:" 8 40 )
		if [ $? -ne 0 ] ; then
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja que o Nome do Provedor fique em branco???" 8 50 ; then					
				NOME_PROVEDOR=""
				break;
			fi
		fi
	done

	if test $SERVER_TYPE -eq $ST_MASTER_CODE; then # Master
		DOMAIN=""
		SUGESTAO=$( echo ${NOME_PROVEDOR} | sed -E 's/ //g' | sed -E "y/ABCDEFGHIJKLMNOPQRSTWXYZ/abcdefghijklmnopqrstwxyz/" )
		while test -z "$DOMAIN"; do
			DOMAIN=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao" --inputbox "Dominio Padrao:" 8 40 "${SUGESTAO}.com.br" )
			if [ $? -ne 0 ] ; then
				# Confirmar se o cara deseja cancelar a instalacao
				if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao de Dominio???" 8 50 ; then
					break;
				fi
			fi
		done	
	fi
}

# Configura conexao com o banco de dados
va_config_conn() {
	VIRTEX_CONF=${VA_PREFIX}/app/etc/virtex.ini

	if [ $SERVER_TYPE -eq $ST_SLAVE_CODE ] ; then
		#
		# SLAVE
		#
		
		while test -z "$DB_IP"; do
			DB_IP=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao de acesso ao servidor Master" --inputbox "IP:" 8 50 )
			if [ $? -ne 0 ] ; then
				continue;
			fi
		done
		MASTER_IP=$DB_IP

		while test -z "$DB_USER"; do
			DB_USER=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao de acesso ao servidor Master" --inputbox "Usuario:" 8 50 )
			if [ $? -ne 0 ] ; then
				continue
			fi
		done

		while test -z "$DB_PASS"; do
			DB_PASS=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao de acesso ao servidor Master" --inputbox "Senha:" 8 50 )
			if [ $? -ne 0 ] ; then
				continue
			fi
		done
	else
		#
		# Master
		#
	
		while test -z "$DB_USER"; do
			DB_USER=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao Banco de Dados - Criacao de Conta" --inputbox "Usuario:" 8 50 virtex )
			if [ $? -ne 0 ] ; then
				continue
			fi
		done

		while test -z "$DB_PASS"; do
			SUGESTAO=$( head -c 10 /dev/random | b64encode /dev/null |sed -E 's/^begin.*//g' | sed -E 's/=//g' | sed -E 's/[^A-Za-z0-9]/x/g' | grep -v -E '^$' )
			DB_PASS=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao Banco de dados - Criacao de Conta" --inputbox "Senha:" 8 50 "${SUGESTAO}" )
			if [ $? -ne 0 ] ; then
				continue
			fi
		done
		DB_IP="127.0.0.1"
	fi

	#
	# Configurar virtex.ini
	#

	cat <<EOF > $VIRTEX_CONF
[geral]
empresa=$NOME_PROVEDOR
debug=0
https_only=0

[DB]
dsn=pgsql://${DB_USER}:${DB_PASS}@${DB_IP}/virtex

EOF
}




va_config_service_ftp() {
	PROFTPD_CONF="${TARGET}/usr/local/etc/proftpd.conf"
	# Verifica se a configuracao do Hospedagem foi setada na tela de selecao de Atuadores
	if ! echo "$ATUADORES" | grep -q $A_HOSP; then 
		return
	fi
	
	if [ -z "${EXTIP}" ] ; then
		FTP_SERVER_ADDRESS=127.0.0.1
	else
		FTP_SERVER_ADDRESS=${EXTIP}
	fi
	

	# Backup
	if [ -f "${PROFTPD_CONF}" ] ; then
		cp $PROFTPD_CONF ${PROFTPD_CONF}.bak
	fi
	echo "" > $PROFTPD_CONF
	cat $TPL_CONF/proftpd.conf | while read LINE; do eval echo \"$LINE\" >> $PROFTPD_CONF; done
}

va_config_service_mail() {
	POSTFIX_CONF="${TARGET}/usr/local/etc/postfix/main.cf"
	AUTHLIB_CONF="${TARGET}/usr/local/etc/authlib/authpgsqlrc"
	SMTPD_CONF="${TARGET}/usr/local/etc/postifx/smtpd.conf"
	
	# Verifica se a configuracao de Email foi setada na tela de selecao de Atuadores
	if ! echo "$ATUADORES" | grep -q $A_EMAIL; then 
		return
	fi

	# smtpd.conf
	if [ -f "$SMTPD_CONF" ]; then 
		cp $SMTPD_CONF ${SMTPD_CONF}.bak
	fi

	install -d ${TARGET}/usr/local/etc/postifx
	echo "" > $SMTPD_CONF
	cat $TPL_CONF/smtpd.conf | while read LINE; do eval echo \"$LINE\" >> $SMTPD_CONF; done		
	

	# mail.conf
	if [ -f "$POSTFIX_CONF" ]; then
		cp $POSTFIX_CONF ${POSTFIX_CONF}.bak
	fi

	echo "" > $POSTFIX_CONF
	cat $TPL_CONF/main.cf | while read LINE; do eval echo \"$LINE\" >> $POSTFIX_CONF; done


	# authlib
	if [ -f "$AUTHLIB_CONF" ]; then
		cp $AUTHLIB_CONF ${AUTHLIB_CONF}.bak
	fi

	echo "" > $AUTHLIB_CONF
	cat $TPL_CONF/authpgsqlrc | while read LINE; do eval echo \"$LINE\" >> $AUTHLIB_CONF; done

}


va_config_php() {
	# Copiando ioncube
	EXT_DIR=$( chroot ${TARGET} /usr/local/bin/php-config --extension-dir )
	IONCUBE=ioncube_loader_fre_5.1.so

	cp ${BASEDIR}/mosman/${IONCUBE} ${TARGET}/$EXT_DIR

	# sobrescrevendo php.ini
	if [ -f ${TARGET}/usr/local/etc/php.ini ] ; then
		cp ${TARGET}/usr/local/etc/php.ini ${TARGET}/usr/local/etc/php.ini.mosman
	fi
	cp $TPL_CONF/php.ini ${TARGET}/usr/local/etc/php.ini

	cat <<EOF >> ${TARGET}/usr/local/etc/php.ini

[zend]
zend_extension = ${EXT_DIR}/${IONCUBE}

EOF

	# Criando Links
	chroot ${TARGET} ln -s /lib/libm.so.4 /lib/libm.so.2 >/dev/null 2>&1
	chroot ${TARGET} ln -s /lib/libc.so.6 /lib/libc.so.4 >/dev/null 2>&1
	chroot ${TARGET} ln -s /lib/libc.so.4 /lib/libc.so.2 >/dev/null 2>&1

	# HTTPD
	HTTPD_INC=/usr/local/etc/apache2/Includes
	#cp httpd.index.conf ${HTTPD_INC}
	cp $TPL_CONF/httpd.php.conf ${TARGET}/${HTTPD_INC}

	chroot ${TARGET} ln -s ${VA_PATH}/app/etc/httpd.frontend.conf $HTTPD_INC/httpd.frontend.conf >/dev/null 2>&1
	#chroot ${TARGET} apachectl restart >/dev/null 2>&1
}


va_config_db() {
	FIRSTBOOT_SCRIPT=${VA_PREFIX}/install/firstboot.sh
	install -d ${VA_PREFIX}/install

	#PG_HBA=/usr/local/pgsql/data/pg_hba.conf
	PG_HBA=${VA_PREFIX}/dados/bd/data/pg_hba.conf
	#DB_INSTALL_SCRIPTS=${VA_PREFIX}/sql
	DB_INSTALL_SCRIPTS=${VA_PATH}/sql

	# Verifica se eh uma instalacao master
	if [ $SERVER_TYPE -ne $ST_MASTER_CODE ]; then
		return	
	fi

	# rc.conf p/ poder rodar o rcscript
	echo 'postgresql_enable="YES"' >> ${TARGET}/etc/rc.conf

	# Cria o usuario
	#echo "pgsql:*:70:70::0:0:PostgreSQL Daemon:/usr/local/pgsql:/bin/sh" >> ${TARGET}/etc/master.passwd
	#echo "pgsql:*:70:" >> ${TARGET}/etc/group
	#chroot ${TARGET} pwd_mkdb /etc/master.passwd

	# Se o /usr/local/pgsql existir renomeie ele.
	if [ -d "${TARGET}/usr/local/pgsql" ]; then
		rm -rf ${TARGET}/usr/local/pgsql_old
		mv ${TARGET}/usr/local/pgsql ${TARGET}/usr/local/pgsql_old
	fi
	install -d ${VA_PREFIX}/dados/bd/data
	chroot ${TARGET} ln -s ${VA_PATH}/dados/bd /usr/local/pgsql 2>&1 >/dev/null 
	chmod 700 ${VA_PREFIX}/dados/bd/data 2>&1 >/dev/null 
	chown -R 70 ${VA_PREFIX}/dados/bd 2>&1 >/dev/null 
	chgrp -R 70 ${VA_PREFIX}/dados/bd 2>&1 >/dev/null 
	
	# Inicializa o DB antes de copiar as configuracoes
	chroot ${TARGET} sh /usr/local/etc/rc.d/010.pgsql.sh initdb 2>&1 > /dev/null
	echo > $FIRSTBOOT_SCRIPT
	echo 'echo "EXECUTANDO CONFIGURACOES INICIAIS... "' >> $FIRSTBOOT_SCRIPT
	echo 'echo "(Este processo pode levar alguns minutos)"' >> $FIRSTBOOT_SCRIPT
	echo 'echo ""' >> $FIRSTBOOT_SCRIPT
	echo "/usr/local/bin/createuser -a -d -U pgsql $DB_USER > /var/log/firstboot.log 2>&1" >> $FIRSTBOOT_SCRIPT
	echo "/usr/local/bin/psql -U pgsql template1 -c \"ALTER USER $DB_USER WITH PASSWORD '$DB_PASS'\" > /var/log/firstboot.log 2>&1" >> $FIRSTBOOT_SCRIPT
	echo "/usr/local/bin/createdb -E LATIN1 -U $DB_USER $DB_NAME > /var/log/firstboot.log 2>&1" >> $FIRSTBOOT_SCRIPT
	echo "/usr/local/bin/psql -U $DB_USER $DB_NAME > /var/log/firstboot.log 2>&1 < $DB_INSTALL_SCRIPTS/virtex.sql"  >> $FIRSTBOOT_SCRIPT
	echo "/usr/local/bin/psql -U $DB_USER $DB_NAME > /var/log/firstboot.log 2>&1 < $DB_INSTALL_SCRIPTS/cftb_cidade.sql" >> $FIRSTBOOT_SCRIPT
	echo "/usr/local/bin/psql -U $DB_USER $DB_NAME > /var/log/firstboot.log 2>&1 < $DB_INSTALL_SCRIPTS/firstnas.sql" >> $FIRSTBOOT_SCRIPT
	#echo "echo 'insert into cftb_nas_rede select rede,1 as id_nas from cftb_rede'|/usr/local/bin/psql -U $DB_USER $DB_NAME > /var/log/firstboot.log 2>&1" >> $FIRSTBOOT_SCRIPT
	echo "/usr/local/bin/psql -U $DB_USER $DB_NAME -c \"INSERT INTO pftb_preferencia_geral VALUES (1, '$DOMAIN','$NOME_PROVEDOR','127.0.0.1','$HTTPD_SERVER','$HTTPD_SERVER','$HTTPD_SERVER',65534,65534,'$EMAIL_SERVER',65534,65534,'$EMAIL_SERVER','$EMAIL_SERVER','',0,'')\" > /var/log/firstboot.log 2>&1" >> $FIRSTBOOT_SCRIPT

	#pg_hba
	echo "host	$DB_NAME	$DB_USER	0.0.0.0/0	password" >> $PG_HBA

	# postgresqlconf
	cp $TPL_CONF/postgresql.conf ${VA_PREFIX}/dados/bd/data
}


va_config_crontab() {
	cat ${TPL_CONF}/crontab.txt |sed -E 's/#.*//g'|grep -v -E '^$' > ${VA_PREFIX}/install/crontab.txt
	if ! echo "$ATUADORES" | grep -q $A_HOSP; then
		cp ${VA_PREFIX}/install/crontab.txt ${VA_PREFIX}/install/crontab.txt.bak
		cat ${VA_PREFIX}/install/crontab.txt.bak | grep -v -E 'vtx-graph' > ${VA_PREFIX}/install/crontab.txt
		rm ${VA_PREFIX}/install/crontab.txt.bak
	fi
                                                                
	chroot ${TARGET} crontab -u root ${VA_PATH}/install/crontab.txt
}

va_config_sysctl() {
	SYSCTL_CONF=${TARGET}/etc/sysctl.conf
	cat <<EOF > ${SYSCTL_CONF}
net.inet.ip.forwarding=1
net.link.ether.ipfw=1
net.inet.ip.fw.one_pass=1
net.inet.tcp.rfc1323=0
EOF
}

va_config_rc() {
	RC_CONF=${TARGET}/etc/rc.conf
	INETD_CONF=${TARGET}/etc/inetd.conf
	SSHD_CONF=${TARGET}/etc/ssh/sshd_config
	HOSTS=${TARGET}/etc/hosts
	
	cat <<EOF > ${HOSTS}
::1                     localhost.${DOMAIN}	localhost
127.0.0.1               localhost.${DOMAIN}	localhost
EOF

	if [ ! -z "${EXTIP}" ] ; then
		cat <<EOF >> ${HOSTS}
${EXTIP}	${HOSTDOMAIN}.${DOMAIN}		${HOSTDOMAIN}
EOF
	fi
	
	if [ -f "${INETD_CONF}" ] ; then
		cp ${INETD_CONF} ${INETD_CONF}.bak
		cat ${INETD_CONF}.bak | sed -E 's/^(#)?(ftp\-proxy)/\2/g' > ${INETD_CONF}
	fi
	
	if [ -f "${SSHD_CONF}" ] ; then
		cp ${SSHD_CONF} ${SSHD_CONF}.bak
		cat ${SSHD_CONF}.bak | sed -E 's/^(#)?(PermitRootLogin) .*/\2 yes/g' > ${SSHD_CONF}
	fi
	
	# SSH
	# Gerar tranqueira e criar chave.
	##########
	RC_SSHD=${TARGET}/etc/rc.d/sshd
	
	# Tira o reseed (que estamos fazendo na mao)
	if [ -f ${RC_SSHD} ] ; then
		cp ${RC_SSHD} ${RC_SSHD}.bak
		cat ${RC_SSHD}.bak | sed -E 's/(seeded=).*/\1/g' > ${RC_SSHD}
	fi
	
	chroot ${TARGET} hostname "${HOSTDOMAIN}.${DOMAIN}"
	chroot ${TARGET} sysctl kern.random.sys.seeded=0 2>&1
	chroot ${TARGET} echo `sysctl -a` `date` `head /dev/random` 2>&1 >/dev/random 
	#chroot ${TARGET} /bin/sh /etc/rc.d/sshd keygen 2>&1 > /dev/null
	chroot ${TARGET} /usr/bin/ssh-keygen -t rsa1 -b 1024 -f /etc/ssh/ssh_host_key -N '' 2>&1 >/dev/null
	chroot ${TARGET} /usr/bin/ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N '' 2>&1 >/dev/null
	chroot ${TARGET} /usr/bin/ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' 2>&1 >/dev/null

	# Habilitar ssh gateway e inetd
	cat <<EOF > $RC_CONF
update_motd="NO"
sshd_enable="YES"
gateway_enable="YES"
inetd_enable="YES"

EOF

	# Postgresql
	if [ $SERVER_TYPE -eq $ST_MASTER_CODE ]; then # Master
	echo "OK"
		cat <<EOF >> $RC_CONF

# Banco de Dados
postgresql_enable="YES"

EOF
	fi

	# postfix
	if echo "$ATUADORES" | grep -q $A_EMAIL; then
		echo "postfix_enable=\"YES\"" >> $RC_CONF
	fi

	# Configuracao de rede


	cat <<EOF >> $RC_CONF

hostname="$HOSTDOMAIN.${DOMAIN}" 
EOF

	# Interface Externa
	if [ -n "$EXTIF" ]; then
		cat <<EOF >> $RC_CONF
defaultrouter="${DEFAULT_GATEWAY}"
ifconfig_${EXTIF}="inet ${EXTIP} netmask ${EXTNETMASK}"
EOF
	fi

	# Interfaces Internas
	
	#for i in $IFACEINT; do
	#	ITF=$( echo $i | sed -e 's/:.*$//g' )
	#	a=$( echo $i | sed -e 's/^[^:]*://g' )
	#	IP=$( echo $a | sed -e 's/:.*$//g' )
	#	NETMASK=$( echo $a | sed -e 's/^.*://g' )
	#	
	#	echo "ifconfig_${ITF}=\"inet ${IP} netmask ${NETMASK}\"" >> $RC_CONF
	#done
	
	chroot ${TARGET} mv /var/named ${VA_PATH}/named
	
	NAMED_CONF=${VA_PREFIX}/named/etc/namedb/named.conf
	RESOLV_CONF=${TARGET}/etc/resolv.conf
	
	if [ -f ${NAMED_CONF} ] ; then
		if [ ! -z ${EXTIP} ] ; then
		
			cp ${NAMED_CONF} ${NAMED_CONF}.bak
			cat ${NAMED_CONF}.bak | sed -E "s/(listen-on[^-]).*/\1 { $EXTIP; }; allow-recursion { $EXTIP; 127.0.0.1\/32; 10.0.0.0\/8; 172.16.0.0\/12; 192.168.0.0\/16; };/g" > ${NAMED_CONF}
			cat <<EOF > $RESOLV_CONF
nameserver ${EXTIP}

EOF

		fi
	fi
	

	cat <<EOF >> $RC_CONF

named_enable="YES"
named_chrootdir="${VA_PATH}/named/"

# P/ coletar estatísticas locais
snmpd_enable="YES"

# Firewall base
firewall_enable="YES"
firewall_script="${VA_PATH}/app/bin/rc.firewall"

pf_rules="${VA_PATH}/app/etc/pf.conf" 
pf_program="/sbin/pfctl"
pf_flags="" 
pflog_enable="NO"
pflog_logfile="/var/log/pflog"
pflog_program="/sbin/pflogd"
pflog_flags=""

EOF

	# Proftpd, habilita somente se hospedagem estiver habilitado
	if echo "$ATUADORES" | grep -q $A_HOSP ; then 
		echo "proftpd_enable=\"YES\"" >> $RC_CONF
	fi

	if [ $SERVER_TYPE -eq $ST_MASTER_CODE ]; then
		cat <<EOF >> $RC_CONF
apache2_enable="YES"	
#apache2ssl_enable="YES"	
EOF
	fi 

	if echo "$ATUADORES" | grep -q $A_EMAIL ; then 
		cat <<EOF >> $RC_CONF
# Email:
courier_authdaemond_enable="YES"
courier_imap_imapd_enable="YES"
courier_imap_imapd_ssl_enable="NO"
courier_imap_pop3d_enable="YES"
courier_imap_pop3d_ssl_enable="NO"
saslauthd_enable="YES"

#clamav_clamd_enable="YES"
#clamav_freshclam_enable="YES"
#clamsmtpd_enable="YES"

EOF
	fi

	# Links, permissions
	chroot ${TARGET} ln -s ${VA_PATH}/app/bin/rc /usr/local/etc/rc.d/011.virtex.sh >/dev/null 2>&1
	chmod +x ${VA_PREFIX}/app/bin/rc >/dev/null 2>&1
	chmod +x ${VA_PREFIX}/app/bin/rc.firewall >/dev/null 2>&1

	chmod 777 ${TARGET}/tmp/
	chmod 777 ${TARGET}/tmp

	if [ -f ${TARGET}/etc/profile ] ; then
		mv ${TARGET}/etc/profile ${TARGET}/etc/profile.bak
	fi

	cp ${TPL_CONF}/profile ${TARGET}/etc
	cp ${TPL_CONF}/motd ${TARGET}/etc

	if [ -f ${TARGET}/usr/local/bin/bash ] ; then
		chroot ${TARGET} chsh -s /usr/local/bin/bash root
		chroot ${TARGET} chsh -s /usr/local/bin/bash pgsql
	fi
	
	JPG_CONFIG=${TARGET}/usr/local/share/jpgraph/jpg-config.inc
	if [ -f ${JPG_CONFIG} ] ; then
		cp ${JPG_CONFIG} ${JPG_CONFIG}.bak
		cat ${JPG_CONFIG}.bak |sed -E 's/DEFINE\("CATCH_PHPERRMSG",true\)/DEFINE("CATCH_PHPERRMSG",false)/g' > ${JPG_CONFIG}
	fi

}


va_config_ppp() {
	PPP_CONF=${TARGET}/etc/ppp/ppp.conf
	PPP_LINKUP=${TARGET}/etc/ppp/ppp.linkup
	PPP_LINKDOWN=${TARGET}/etc/ppp/ppp.linkdown
	RADIUS_CONF=${TARGET}/etc/ppp/radius.conf
	
	if echo "$ATUADORES" | grep -q $A_BLPPPOE_CODE ; then 
		# ppp.conf
		if [ -f ${PPP_CONF} ] ; then
			cp $PPP_CONF ${PPP_CONF}.bak
		fi
		#cat $TPL_CONF/ppp.txt | while read LINE; do eval echo \"$LINE\" >> $PPP_CONF; done

		cat $TPL_CONF/ppp.txt | while read LINE; do 
		LINHA=$( eval echo \"$LINE\" )
   		echo $LINHA | grep -E "(.*)\:" > /dev/null
   		if [ $? -ne 0 ] ; then
			echo -n " "
   		fi
   		echo $LINHA
		done > ${PPP_CONF}

		# ppp.linkup
		if [ -f ${PPP_LINKUP} ] ; then
			cp $PPP_LINKUP ${PPP_LINKUP}.bak
		fi
		#cat $TPL_CONF/ppp.linkup | while read LINE; do eval echo \"$LINE\" >> $PPP_LINKUP; done

		cat $TPL_CONF/ppp.linkup | while read LINE; do 
		LINHA=$( eval echo \"$LINE\" )
   		echo $LINHA | grep -E "(.*)\:" > /dev/null
   		if [ $? -ne 0 ] ; then
			echo -n " "
   		fi
   		echo $LINHA
		done > ${PPP_LINKUP}

		chmod +x $PPP_LINKUP

		# ppp.linkdown
		if [ -f ${PPP_LINKDOWN} ] ; then
			cp $PPP_LINKDOWN ${PPP_LINKDOWN}.bak
		fi
		#cat $TPL_CONF/ppp.linkdown | while read LINE; do eval echo \"$LINE\" >> $PPP_LINKDOWN; done

		cat $TPL_CONF/ppp.linkdown | while read LINE; do 
		LINHA=$( eval echo \"$LINE\" )
   		echo $LINHA | grep -E "(.*)\:" > /dev/null
   		if [ $? -ne 0 ] ; then
			echo -n " "
   		fi
   		echo $LINHA
		done > ${PPP_LINKDOWN}

		chmod +x $PPP_LINKDOWN

		# radius.conf
		if [ -f ${RADIUS_CONF} ] ; then
			cp $RADIUS_CONF ${RADIUS_CONF}.bak
		fi
		cat $TPL_CONF/radius.conf | while read LINE; do eval echo \"$LINE\" >> $RADIUS_CONF; done
		chmod +x $RADIUS_CONF

	fi
}

va_config_httpd() {
	HTTPD_CONF=${TARGET}/usr/local/etc/apache2/httpd.conf	
	if [ -f ${HTTPD_CONF} ] ; then
		cp $HTTPD_CONF ${HTTPD_CONF}.bak
		#cp ${TPL_CONF}/httpd.conf $HTTPD_CONF
		if [ -z "${EXTIP}" ] ; then
			cat ${HTTPD_CONF}.bak | sed -E 's/^(User|Group) www/\1 nobody/g'| sed -E 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/g' > ${HTTPD_CONF}
		else
			cat ${HTTPD_CONF}.bak | sed -E 's/^(User|Group) www/\1 nobody/g'| sed -E 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/g' | sed -E "s/(#)?( )?(ServerName).*/\3 ${EXTIP}:80/g" > ${HTTPD_CONF}
		fi
	fi
}

va_background_config() {
	echo "XXX"
	echo 10
	echo "Configurando Sistemas de Informacao..."
	echo "XXX"
	va_config_si

	echo "XXX"
	echo 20
	echo "Configurando Host..."
	echo "XXX"
	va_host_config

	echo "XXX"
	echo 30
	echo "Configurando Servico FTP..."
	echo "XXX"
	va_config_service_ftp

	echo "XXX"
	echo 40
	echo "Configurando Servico de Email..."
	echo "XXX"
	va_config_service_mail

	echo "XXX"
	echo 50
	echo "Configurando PHP..."
	echo "XXX"
	va_config_php

	echo "XXX"
	echo 60
	echo "Configurando Crontab..."
	echo "XXX"
	va_config_crontab

	echo "XXX"
	echo 70
	echo "Configurando Scripts de Inicializacao..."
	echo "XXX"
	va_config_rc
	va_config_sysctl

	echo "XXX"
	echo 80
	echo "Configurando PPPoE..."
	echo "XXX"
	va_config_ppp

	echo "XXX"
	echo 90
	echo "Configurando WebServer..."
	echo "XXX"
	va_config_httpd

	echo "XXX"
	echo 100
	echo "Concluido..."
	echo "XXX"
	
}




va_config() {
	va_interface_externa
	va_config_bandalarga # Colhe a informacao se o usuario deseja fornecer acesso bandalarga nesta maquina
	va_config_tcpip
	va_config_pppoe
	va_config_hospedagem
	va_config_email
	va_config_dns
	va_config_domain
	va_config_conn
	va_config_db

	# Execucoes em background
	va_background_config | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "Finalizando instalacao" --gauge "Finalizando..."  8 50 0
	
}




# MAIN
#######################

#
# Escolha do HD
#######
disco
# SEGURANCA
#HD="ad0"

#
# VIRTEX ADMIN - CONFIGS INICIAIS
########################
tipo_servidor
#atuadores
confirma_instalacao
########################


#
# Instalacao do sistema operacional (FreeBSD)
######
formata_disco   | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "DISCO ${HD}" --gauge "Preparando..."  8 50 0
monta_alvo      | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "INICIALIZANDO DISPOSITIVOS" --gauge "Preparando..."  8 50 0
instala_base    | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "INSTALACAO DO FREEBSD" --gauge "Preparando..."  8 50 0
instala_configs | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "CONFIGURACOES INICIAIS" --gauge "Preparando..."  8 50 0

#
# VIRTEX ADMIN - INSTALACAO DE PACOTES
########################
va_instala_pacotes | ${DIALOG} --backtitle "$BACKTITLE" --title "Instalacao dos Pacotes" --gauge "Instalando..." 8 50 0
########################


#
# Configura a senha do usuario root
#####

#config_senha
config_senha_modotexto

#
# VIRTEX ADMIN - CONFIGURACAO DO VA
########################
va_config
########################


#
# DESMONTA O DISCO ALVO
######

desmonta_alvo | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "FINALIZANDO" --gauge "Preparando..."  8 50 0

#
# INSTALACAO FINALIZADA COM SUCESSO
#######
umount /cdrom 2>&1 >/dev/null
eject /dev/acd0
${DIALOG} --clear --backtitle "${BACKTITLE}" --title "CONCLUIDO" --msgbox "Instalacao finalizada com sucesso.\nRetire o cd e precione ok para reboot" 8 50
reboot
