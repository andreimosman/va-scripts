#!/bin/sh

# Configuracoes
DIALOG=cdialog
BACKTITLE="Virtex Instalacao"
BASEDIR=../dist

TARGET=/var/mnt
VA_PATH=/mosman/virtex
VA_PREFIX=${TARGET}/${VA_PATH}

TPL_CONF="/scripts/tpl"

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
	install -d ${TARGET}/dados/emails
	install -d ${TARGET}/dados/hospedagem
	install -d ${TARGET}/dados/logs
	install -d ${TARGET}/dados/named
	install -d ${TARGET}/dados/carnes
	install -d ${TARGET}/dados/estatisticas
	install -d ${TARGET}/dados/contratos

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


# RODAR VIRTEX.SH


# FINALIZADO

config_senha() {
	
	SENHA=""
	CONF_SENHA=""
	
	while [ "${SENHA}" != "${CONF_SENHA}" ] || [ "${SENHA}" = "" ]  ; do

		SENHA=`${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --passwordbox "Defina a senha do root" 8 50 `
		
		if [ "$?" -ne 0 ] ; then
			# Confirmar que a senha nao foi definida
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja que a senha permaneca em branco ???" 8 50 ; then
				break;
			else
				continue;
			fi
		fi
		
		CONF_SENHA=`${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --passwordbox "Confirme a senha" 8 50 `
		
		if [ "$?" -ne 0 ] ; then
			SENHA="";
			continue;
		fi

		#echo "SENHA: ${SENHA}"
		#chroot ${TARGET} /usr/bin/passwd
		#chroot ${TARGET} /usr/bin/chpass -p "${SENHA}"
		#sleep 2

		#sh altsenha.sh "${TARGET}" "${SENHA}"
		
		if [ "${SENHA}" = "" ] ; then
			${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --msgbox "ERRO: SENHA EM BRANCO!!!" 8 50
		else
			if [ "${SENHA}" = "${CONF_SENHA}" ] ; then
			
				##
				# ALTERAR A SENHA
				###################################
				
				# TODO: ALTERACAO DA SENHA
				
				
				${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --msgbox "SENHA DEFINIDA COM SUCESSO!!!" 8 50

				####################################
				# SENHA ALTERADA
				##
			else
				${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --msgbox "A senha e a confirmacao nao conferem" 8 50
			
			fi		
		fi
		
	done
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


##################################################################################################################
# Inicio do codigo do capota (convertido pra funcao)
################################

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
	        	$ST_MASTER_CODE Master on \
		        $ST_SLAVE_CODE Slave off )

		if [ "$?" -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a instalacao???" 8 50 ; then
				abortar;
			fi

			continue
		fi
	
		if test $SERVER_TYPE -eq $ST_MASTER_CODE; then # Tipo de servidor master
			# Email e Hospedagem on
			options="$A_EMAIL Email on $A_HOSP Hospedagem on"
		else
			# Email e Hospedagem off
			options="$A_EMAIL Email off $A_HOSP Hospedagem off"
		fi

	done

}

atuadores() {

	ATUADORES=""

	while [ "${ATUADORES}" = "" ] ; do

		ATUADORES=$( ${DIALOG} --stdout  --backtitle "$BACKTITLE" \
			--checklist "Selecione os Atuadores:" 12 40 5 \
			$A_BLTCP_CODE "Banda Larga TCP/IP" on \
			$A_BLPPPOE_CODE "Banda Larga PPPOE" on \
			$A_DISCADO Discado off \
			$options )

		if [ "$?" -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a instalacao???" 8 50 ; then
				abortar;
			fi

			continue
		fi

		ATUADORES=`echo $ATUADORES | sed -e 's/"//g'`
		
	done

}

confirma_instalacao() {

	while true ; do
		${DIALOG} --backtitle "$BACKTITLE" --title "Instalar ?"  --yesno "O instalador esta pronto para iniciar a instalacao.\nDeseja Continuar?" 7 55
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

va_instala_pacotes() {
	PKG_HOSP="proftpd"
	PKG_EMAIL="courier-imap courier-authlib-base postfix"
	PKG_EXCLUDE="php5-snmp"

	mount -t cd9660 /dev/acd0 ${TARGET}/mnt
	
	export PKG_PATH=/mnt/packages
	#return;

	# regex para remover da lista os pacotes que nao serao instalados
	rgx=""
	#in_array $A_HOSP "${ATUADORES[@]}"
	in_array "$A_HOSP" ${ATUADORES}
	if [ $? -eq 1 ] ; then
		for i in $PKG_HOSP; do
			rgx="${rgx}^${i}|"
		done
	fi

#	in_array $A_EMAIL "${ATUADORES[@]}"
	in_array "$A_EMAIL" ${ATUADORES}
	if test $? -eq 1; then
		for i in $PKG_EMAIL; do
			rgx="${rgx}^${i}|"
		done
	fi

	# Lista de pacotes que serao excluidos da instalacao
	for i in $PKG_EXCLUDE; do
		rgx="${rgx}^${i}|"	
	done

	# Monta lista completa
	if test -n "$rgx"; then
		rgx=${rgx%|}
		for i in $( ls -1 $PACKAGE_DIR/ | grep -v -E '$rgx' ); do
			PKG_LIST="$PKG_LIST $i"
		done
	else
		for i in $PACKAGE_DIR/*; do
			PKG_LIST="$PKG_LIST $i"
		done
	fi

	(
		i=1
		TOTAL=$( echo $PKG_LIST | wc -w )
		# enquanto estiver instalando os pacotes
		echo 'cd /mnt/packages' > ${TARGET}/pkg.sh
		echo 'pkg_add -I $1 2>&1 >/dev/null' >> ${TARGET}/pkg.sh
		#echo 'echo LALALA: $1' >> ${TARGET}/pkg.sh
		#echo 'sleep 1' >> ${TARGET}/pkg.sh
		
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
	  	done
	  	
	  	rm ${TARGET}/pkg.sh
 
	  	# instalacao finalizada, mostra a porcentagem final
  		echo 100
  	
	  ) 
	  
	  umount ${TARGET}/mnt

}

va_install_dirs() {
	chroot ${TARGET} install -d ${VA_PATH}/app/etc
	chroot ${TARGET} install -d ${VA_PATH}/etc/rc.d
	chroot ${TARGET} install -d ${VA_PATH}/install
	chroot ${TARGET} install -o 70 -g 70 -d ${VA_PATH}/dados/bd
	chroot ${TARGET} install -o 70 -g 70 -d ${VA_PATH}/dados/bd/data
}

va_cancelar_atuador() {
	${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja cancelar a configuracao deste atuador???" 8 50 
	return $?
}

va_config_email() {
	EMAIL_CONF=${VA_PREFIX}/app/etc/email.ini
	EMAIL_SERVER=""
	
	in_array "$A_EMAIL" ${ATUADORES}
	if [ "$?" -eq 0 ] ; then
		while [ "${EMAIL_SERVER}" = "" ] ; do
			EMAIL_SERVER=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "Email" --inputbox "Email Server:" 8 40 "127.0.0.1" )
			
			if [ "$?" -ne 0 ] ; then
				# Cancelou ou pressionou ESC
				va_cancelar_atuador
				
				if [ $? -eq 0 ] ; then
					EMAIL_SERVER=""
					break;
				fi
			fi
		done
		EMAIL_ENABLED=1
	fi

if [ "${EMAIL_SERVER}" = "" ] ; then
	# valores padroes
	EMAIL_SERVER="127.0.0.1"
	EMAIL_ENABLED=0
fi

# gen ini email file
cat <<EOF > $EMAIL_CONF
[$EMAIL_SERVER]
enabled=$EMAIL_ENABLED
EOF

}

va_config_hosp() {
	HOSPEDAGEM_CONF=${VA_PREFIX}/app/etc/hospedagem.ini
	HTTPD_SERVER=""
	
	in_array "$A_HOSP" ${ATUADORES}
	if [ "$?" -eq 0 ] ; then
		while [ "${HTTPD_SERVER}" = "" ] ; do
			HTTPD_SERVER=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "Hospedagem" --inputbox "HTTP Server:" 8 40 "127.0.0.1" )
			
			if [ "$?" -ne 0 ] ; then
				# Cancelou ou pressionou ESC
				va_cancelar_atuador
				
				if [ $? -eq 0 ] ; then
					HTTPD_SERVER=""
					break;
				fi
			fi
		done
		HTTPD_ENABLED=1
	fi

if [ "${HTTPD_SERVER}" = "" ] ; then
	# valores padroes
	HTTPD_SERVER="127.0.0.1"
	HTTPD_ENABLED=0
fi

# gen ini hospedagem file
cat <<EOF > $HOSPEDAGEM_CONF
[$HTTPD_SERVER]
enabled=$HTTPD_ENABLED
EOF

}

#
# Hostname
#

va_host_config() {
	while test -z "$HOSTDOMAIN"; do
		HOSTDOMAIN=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "Network" --inputbox "Hostname:" 8 40 localhost.localdomain )
	done

	HOST=${HOSTDOMAIN%.*}
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
nat=1

EOF

		fi
	done
}

#
# Configurar interfaces internas
#
va_interfaces_internas() {
	NETWORK_CONF=${VA_PREFIX}/app/etc/network.ini

	if [ -n "$EXTIF" ]; then
		IFACELIST_INTERNAS=$( echo $IFACELIST | sed -e "s/$EXTIF *//g")
	else
		IFACELIST_INTERNAS=$IFACELIST
	fi

	while [ -n "$IFACELIST_INTERNAS" ] ; do

		# Deseja configurar outras interfaces ?
		${DIALOG} --stdout --title "Network"  --yesno "Voce deseja configurar outras interfaces (internas) ?" 7 55 

		if [ "$?" -eq 0 ] ; then
			options=""
			num=0
			for iface in ${IFACELIST_INTERNAS} ; do
				options="${options} $iface Rede"
				num=`expr ${num} \+ 1`
				#echo $iface
			done
	
			INTIF=""
			while [ -z "${INTIF}" ] ; do
	
				cancel=0
				INTIF=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
					--title Network \
					--menu "Selecione a interface interna:" 12 40 $num \
					$options )
			
				if [ "$?" -ne 0 ] ; then
					# Confirmar se o cara deseja cancelar a instalacao
					if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao da rede???" 8 50 ; then
						cancel=1
						break;
					fi
				fi
			done
			if [ $cancel -eq 1 ]; then
				break;
			fi
	
			IP=""
			NETMASK=""
			if [ ! -z "${INTIF}" ] ; then

				cancel=0
				while test -z "$IP"; do
					IP=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "IP Address da Interface Externa" --inputbox "IP ${INTIF}:" 8 40 )
					if [ $? -ne 0 ] ; then
						cancel=1
						break;
					fi
				done
				if [ $cancel -eq 1 ]; then
					continue				
				fi
				
				while test -z "$NETMASK"; do
					NETMASK=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" --title "Netmask da Interface Externa" --inputbox "Netmask ${INTIF}:" 8 40 "255.255.255.0" )
					if [ $? -ne 0 ] ; then
						cancel=1
						break;
					fi
				done
				if [ $cancel -eq 1 ]; then
					continue				
				fi
				
				IFACELIST_INTERNAS=$( echo $IFACELIST_INTERNAS | sed -e "s/$INTIF *//g" )	
				IFACELIST_INTERNAS_ACTIVE="$IFACELIST_INTERNAS_ACTIVE $INTIF"
				IFACEINT="$IFACEINT ${INTIF}:${IP}:${NETMASK}"
				
				# grava configuracoes no ini
				cat <<EOF >> $NETWORK_CONF
[${INTIF}]
status=up
type=internal
ipaddr=$IP
netmask=$NETMASK

EOF
			fi
		else
			break
		fi
	done

	# Grava no ini as interfaces que nao foram configuradas
	for i in $IFACELIST_INTERNAS ; do 
		cat <<EOF >> $NETWORK_CONF
[${i}]
status=down
EOF
	done

}

va_config_pppoe() {
	PPPOE_CONF=${VA_PREFIX}/app/etc/pppoe.ini
	echo "" > $PPPOE_CONF

	# Verifica se a configuracao do PPPOE foi setada na tela de selecao de Atuadores
	if ! echo "$ATUADORES" | grep -q $A_BLPPPOE_CODE ; then 
		return
	fi

	# verifica se o tipo de servidor eh slave
	if [ $SERVER_TYPE -ne $ST_SLAVE_CODE ]; then
		return
	fi
	
	# verifica se foi configurada alguma interface interna
	if [ -z "$IFACELIST_INTERNAS_ACTIVE" ]; then
		return
	fi

	options=""
	num=0
	for iface in ${IFACELIST_INTERNAS_ACTIVE} ; do
		options="${options} $iface Rede"
		num=`expr ${num} \+ 1`
		#echo $iface
	done

	while [ -z "${PPPOEIF}" ] ; do
	
		cancel=0
		PPPOEIF=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
			--title PPPOE  \
			--menu "Selecione uma interface:" 12 40 $num \
			$options )
			
		if [ "$?" -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao de PPPOE???" 8 50 ; then
				cancel=1
				break;
			fi
		fi
	done
	if [ $cancel -eq 1 ]; then
		return
	fi

	NAS_ID=""
	while test -z "$NAS_ID"; do
		NAS_ID=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "PPPOE" --inputbox "NAS $PPPOEIF:" 8 40 )
	done

	cat <<EOF > $PPPOE_CONF
[${PPPOEIF}]
nas_id=$NAS_ID
enabled=1
fator=2

EOF
}

va_config_tcpip() {
	TCPIP_CONF=${VA_PREFIX}/app/etc/tcpip.ini
	echo "" > $TCPIP_CONF

	# Verifica se a configuracao do PPPOE foi setada na tela de selecao de Atuadores
	if ! echo "$ATUADORES" | grep -q $A_BLTCP_CODE ; then 
		return
	fi

	# remove interface externa da lista
	if [ -n "$EXTIF" ]; then
		IFACELIST_INTERNAS=$( echo $IFACELIST | sed -e "s/$EXTIF *//g")
	else
		IFACELIST_INTERNAS=$IFACELIST
	fi

	c=0
	while [ -n "$IFACELIST_INTERNAS" ] ; do
		if test $c -gt 0; then
			$DIALOG --stdout --backtitle "$BACKTITLE" --title "TCP/IP NAS ID"  --yesno "Voce deseja configurar outras intefaces (tcp/ip NAS ID)?" 7 55 
			if test $? -eq 1; then
				break
			fi
		fi
		c=`expr $c + 1`    
		
		options=""
		num=0
		for iface in ${IFACELIST_INTERNAS} ; do
			options="${options} $iface Rede"
			num=`expr ${num} \+ 1`
			#echo $iface
		done
		
		INTIF=""
		while [ -z "${INTIF}" ] ; do
			cancel=0
			INTIF=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
				--title "NAS ID TCP/IP" \
				--menu "Selecione uma interface:" 12 40 $num \
				$options )

			if [ $? -ne 0 ] ; then
				# Confirmar se o cara deseja cancelar a instalacao
				if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao de tcp/ip???" 8 50 ; then
					cancel=1
					break;
				fi
			fi
		done
		if [ $cancel -eq 1 ]; then
			break;
		fi
		
		IFACELIST_INTERNAS=$( echo $IFACELIST_INTERNAS | sed -e "s/$INTIF *//g" )	

		NAS_ID=""
		cancel=0
		while test -z "$NAS_ID"; do
			NAS_ID=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "TCP/IP NAS ID" --inputbox "NAS ID ${INTIF}:" 8 40 )
			if [ $? -ne 0 ]; then
				cancel=1
				break;
			fi			
		done
		if [ $cancel -eq 1 ]; then
			continue
		fi
		
		cat <<EOF >> $TCPIP_CONF		
[${INTIF}]
nas_id=$NAS_ID
enabled=1
fator=2

EOF
	done

	# Seta no ini as interfaces desabilitadas.
	for itf in $IFACELIST_INTERNAS; do
		cat <<EOF >> $TCPIP_CONF
	[$itf]
	enabled=0

EOF
	done
}

va_config_si() {
	I_HOSTS_CONF=${VA_PREFIX}/app/etc/infocenter.hosts.ini
	I_SERVER_CONF=${VA_PREFIX}/app/etc/infocenter.server.ini	
	I_USERS_CONF=${VA_PREFIX}/app/etc/infocenter.users .ini
	
	while test -z "$CHAVE"; do
		CHAVE=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Sistema de Informacoes" --inputbox "Defina a chave do sistema de informacoes:" 8 40 )
		if [ $? -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao do Sistema de Informacoes???" 8 50 ; then					
				return;
			fi
		fi	
	done
	while test -z "$U"; do
		U=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Sistema de Informacoes" --inputbox "Usuario:" 8 40 )
		if [ $? -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao do Sistema de Informacoes???" 8 50 ; then					
				return;
			fi
		fi
	done
	while test -z "$PASS"; do
		PASS=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Sistema de Informacoes" --inputbox "Senha:" 8 40 )
		if [ $? -ne 0 ] ; then
			# Confirmar se o cara deseja cancelar a instalacao
			if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao do Sistema de Informacoes???" 8 50 ; then					
				return;
			fi
		fi
	done

# gen ini files
cat <<EOF > $I_HOSTS_CONF
[localhost]
host=127.0.0.1
port=11000
chave=$CHAVE
username=$U
password=$PASS
enabled=1

[$HOST]
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
[$USER]
password=$PASS
enabled=1
EOF

}

va_config_domain () {
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
		while test -z "$DOMAIN"; do
			DOMAIN=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao" --inputbox "Dominio Padrao:" 8 40 "${NOME_PROVEDOR}.com.br" )
			if [ $? -ne 0 ] ; then
				# Confirmar se o cara deseja cancelar a instalacao
				if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao de Dominio???" 8 50 ; then					
					break;
				fi
			fi
		done	
	fi
}

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
			DB_PASS=$( $DIALOG --stdout --backtitle "$BACKTITLE" --title "Configuracao Banco de dados - Criacao de Conta" --inputbox "Senha:" 8 50 )
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

	if [ ! -f $PROFTD_CONF ]; then
		return
	fi
	
	# Backup
	cp $PROFTPD_CONF ${PROFTPD_CONF}.bak
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
		echo "" > $SMTPD_CONF
		cat $TPL_CONF/smtpd.conf | while read LINE; do eval echo \"$LINE\" >> $SMTPD_CONF; done		
	fi
	
	# mail.conf
	if [ -f "$POSTFIX_CONF" ]; then
		cp $POSTFIX_CONF ${POSTFIX_CONF}.bak
		echo "" > $POSTFIX_CONF
		cat $TPL_CONF/main.cf | while read LINE; do eval echo \"$LINE\" >> $POSTFIX_CONF; done
	fi

	# authlib
	if [ -f "$AUTHLIB_CONF" ]; then
		cp $AUTHLIB_CONF ${AUTHLIB_CONF}.bak
		echo "" > $AUTHLIB_CONF
		cat $TPL_CONF/authpgsqlrc | while read LINE; do eval echo \"$LINE\" >> $AUTHLIB_CONF; done
	fi
}

va_config_php() {
	# Copiando ioncube
	EXT_DIR=$( chroot ${TARGET} php-config --extension-dir )
	IONCUBE=ioncube_loader_fre_5.0.so

	cp ${IONCUBE} ${TARGET}/$EXT_DIR

	# sobrescrevendo php.ini
	cp ${TARGET}/usr/local/etc/php.ini ${TARGET}/usr/local/etc/php.ini.mosman
	cp $TPL_CONF/php.ini ${TARGET}/usr/local/etc/php.ini

	cat <<EOF > ${TARGET}/usr/local/etc/php.ini

[zend]
zend_extension = ${EXT_DIR}/${IONCUBE}

EOF

	# Criando Links
	chroot ${TARGET} ln -s /lib/libm.so.4 /lib/libm.so.2 >/dev/null 2>&1
	chroot ${TARGET} ln -s /lib/libc.so.6 /lib/libc.so.4 >/dev/null 2>&1
	chroot ${TARGET} ln -s /lib/libc.so.4 /lib/libc.so.2 >/dev/null 2>&1

	# HTTPD
	HTTPD_INC=/usr/local/etc/apache22/Includes
	#cp httpd.index.conf ${HTTPD_INC}
	cp $TPL_CONF/httpd.php.conf ${TARGET}/${HTTPD_INC}

	chroot ${TARGET} ln -s ${VA_PATH}/app/etc/httpd.frontend.conf $HTTPD_INC/httpd.frontend.conf >/dev/null 2>&1
	chroot ${TARGET} apachectl restart >/dev/null 2>&1
}

va_config_db() {
	FIRSTBOOT_SCRIPT=${VA_PREFIX}/install/firstboot.sh
	PG_HBA=/usr/local/pgsql/pg_hba
	#DB_INSTALL_SCRIPTS=${VA_PREFIX}/sql
	DB_INSTALL_SCRIPTS=${VA_PATH}/sql

	# Verifica se eh uma instalacao master
	if [ $SERVER_TYPE -ne $ST_MASTER_CODE ]; then
		return	
	fi

	# rc.conf p/ poder rodar o rcscript
	echo 'postgresql_enable="YES"' >> ${TARGET}/etc/rc.conf

	# Cria o usuario
	echo "pgsql:*:70:70::0:0:PostgreSQL Daemon:/usr/local/pgsql:/bin/sh" >> ${TARGET}/etc/master.passwd
	echo "pgsql:*:70:" >> ${TARGET}/etc/group
	chroot ${TARGET} pwd_mkdb /etc/master.passwd

	# Se o /usr/local/pgsql existir renomeie ele.
	if [ -d "${TARGET}/usr/local/pgsql" ]; then
		rm -rf ${TARGET}/usr/local/pgsql_old
		mv ${TARGET}/usr/local/pgsql ${TARGET}/usr/local/pgsql_old
	fi
	chroot ${TARGET} ln -s ${VA_PATH}/dados/bd /usr/local/pgsql >/dev/null 2>&1
	chmod 700 ${VA_PREFIX}/dados/bd/data
	chown -R 70 ${VA_PREFIX}/dados/bd
	chgrp -R 70 ${VA_PREFIX}/dados/bd

	echo "createuser -a -d -U pgsql $DB_USER" >> $FIRSTBOOT_SCRIPT
	echo "psql -U pgsql -c \"ALTER USER $DB_USER WITH PASSWORD '$DB_PASS'\"" >> $FIRSTBOOT_SCRIPT
	echo "createdb --enconding LATIN1 -U $DB_USER $DB_NAME" >> $FIRSTBOOT_SCRIPT
	echo "psql -U $DB_USER $DB_NAME < $DB_INSTALL_SCRIPTS/virtex.sql" >> $FIRSTBOOT_SCRIPT
	echo "psql -U $DB_USER $DB_NAME < $DB_INSTALL_SCRIPTS/cftb_cidades.sql" >> $FIRSTBOOT_SCRIPT
	echo "psql -U $DB_USER $DB_NAME < $DB_INSTALL_SCRIPTS/firstnas.sql" >> $FIRSTBOOT_SCRIPT
	echo "psql -U $DB_USER $DB_NAME -c \"INSERT INTO pftb_preferencia_geral VALUES (1, '$DOMAIN','$NOME_PROVEDOR','127.0.0.1','$HTTPD_SERVER','$HTTPD_SERVER','$HTTPD_SERVER',65534,65534,'$EMAIL_SERVER',65534,65534,'$EMAIL_SERVER','$EMAIL_SERVER','',0,'')\"" >> $FIRSTBOOT_SCRIPT

	#pg_hba
	chroot ${TARGET} echo "host	$DB_NAME	$DB_USER	0.0.0.0/0	password" >> $PG_HBA

	# postgresqlconf
	cp $TPL_CONF/postgresql.conf ${VA_PREFIX}/dados/bd/data
}


va_config_crontab() {
	cp ${TPL_CONF}/crontab.txt ${VA_PREFIX}/install
	chroot ${TARGET} crontab -u root ${VA_PATH}/install/crontab.txt
}


va_config_rc() {
	RC_CONF=${TARGET}/etc/rc.conf

	# Habilitar gateway e inetd
	cat <<EOF > $RC_CONF

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

hostname="$HOSTDOMAIN" 
EOF

	# Interface Externa
	if [ -n "$EXTIF" ]; then
		cat <<EOF >> $RC_CONF
defaultrouter="200.217.241.65"
ifconfig_${EXTIF}="inet ${EXTIP} netmask ${EXTNETMASK}"
EOF
	fi

	# Interfaces Internas
	
	for i in $IFACEINT; do
		ITF=$( echo $i | sed -e 's/:.*$//g' )
		a=$( echo $i | sed -e 's/^[^:]*://g' )
		IP=$( echo $a | sed -e 's/:.*$//g' )
		NETMASK=$( echo $a | sed -e 's/^.*://g' )
		
		echo "ifconfig_${ITF}=\"inet ${IP} netmask ${NETMASK}\"" >> $RC_CONF
	done


	cat <<EOF >> $RC_CONF

named_enable="YES"
named_chrootdir="${VA_PATH}/named/"

# P/ coletar estatísticas locais
snmpd_enable="YES"

# Firewall base
firewall_enable="YES"
firewall_script="${VA_PATH}/app/bin/rc.firewall"

pf_rules="${VA_PATH}/etc/pf.conf" 
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
apache22_enable="YES"	
#apache22ssl_enable="YES"	
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
}

va_config_ppp() {
	PPP_CONF=${TARGET}/etc/ppp/ppp.conf
	if echo "$ATUADORES" | grep -q $A_BLPPPOE_CODE ; then 
		cp $PPP_CONF ${PPP_CONF}.bak
		cat $TPL_CONF/ppp.txt | while read LINE; do eval echo \"$LINE\" >> $PPP_CONF; done
	fi
}

va_config_httpd() {
	HTTPD_CONF=${TARGET}/usr/local/etc/apache22/httpd.conf	
	if echo "$ATUADORES" | grep -q $A_HOSP; then
		cp $HTTPD_CONF ${HTTPD_CONF}.bak
		cp ${TPL_CONF}/httpd.conf $HTTPD_CONF
	fi
}

#
# Configuracao de Rede
#
va_network_config() {
	va_host_config
	va_interface_externa
	va_interfaces_internas
}

#
# Configuracao de servicos
#

va_services_config() { 
	va_config_service_ftp
	va_config_service_mail
	va_config_httpd
	va_config_php
}

va_config() {
	va_install_dirs
	va_config_email
	va_config_hosp
	
	va_network_config
	va_config_pppoe
	va_config_tcpip
	va_config_si

	va_config_domain
	va_config_conn

	(
		echo "XXX"	
		echo 10
		echo "Configurando Database..."
		echo "XXX"
		va_config_db
	
		echo "XXX"
		echo 30
		echo "Configurando servicos..."
		echo "XXX"		
		va_services_config

		echo "XXX"
		echo 50
		echo "Configurando crontab..."
		echo "XXX"
		va_config_crontab
		
		echo "XXX"
		echo 70
		echo "Configurando script de inicializacao..."
		echo "XXX"
		va_config_rc
		
		echo "XXX"
		echo 90		
		echo "Configurando PPP..."
		echo "XXX"
		va_config_ppp
		
		echo "XXX"
		echo 100
		echo "Finalizado"
		echo "XXX"
	)  | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "Configurando Sistema" --gauge ""  8 50 0
}

################################
# Fim do codigo do capota (convertido pra funcao)
##################################################################################################################


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
atuadores
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
#va_instala_pacotes | ${DIALOG} --backtitle "$BACKTITLE" --title "Instalacao dos Pacotes" --gauge "Instalando..." 8 50 0
va_config
########################


#
# DESMONTA O DISCO ALVO
######

desmonta_alvo | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "FINALIZANDO" --gauge "Preparando..."  8 50 0

#
# INSTALACAO FINALIZADA COM SUCESSO
#######

${DIALOG} --clear --backtitle "${BACKTITLE}" --title "CONCLUIDO" --msgbox "Instalacao finalizada com sucesso.\nPrecione ok para reboot" 8 50
#reboot
