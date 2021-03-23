
. solib.sh

HDLIST=$( hdlist )
MENU_HD=$( menuhd )
IFACELIST=$( iflist )


#
# Informacoes Iniciais
#
BACKTITLE="VirtexAdmin NG Install"
DIALOG=cdialog 
DIALOG_OP="--clear"

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

TARGET_MOUNT=/target

FREEBSD_DIR=/mosman/install/7.0-RELEASE
PKG_DIR=/mosman/packages/All








# --backtitle '${BACKTITLE}'"
#/usr/bin/dialog


abortar() {
   echo "Tchau";
   exit;
}


#
# Escolha do Disco
#
disco() {
   HD=
   while [ "${HD}" = "" ] ; do
     HD=$( ${DIALOG} ${DIALOG_OP} --stdout --backtitle "${BACKTITLE}" --title "ESCOLHA O DESTINO" \
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

     ${DIALOG}  --backtitle "${BACKTITLE}" \
   	     --title "ATENCAO!!!!" --yesno \
"TODOS OS DADOS DO HD '${HD}' SERAO APAGADOS.\n\
\n\
DESEJA CONTINUAR.\n" 7 51
              
     if [ "$?" -ne "0"  ] ; then
       #disco
       HD=""
     fi
   done

}

#
# Escolha do tipo de servidor
#
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

#
# Confirma a instalacao
#
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


#
# Pega o reply do comando diskPart (que particiona e formata) e ecoa informacoes no padrao do dialog
#
_formata_reply() {

  while read REPLY ; do
     local cmd=$(echo $REPLY|sed -E 's/:(.*)//g')
     param=$(echo $REPLY|sed -E 's/([^:]+)://g')

     case $cmd in
        PART)
           echo "PARAM: $param"
        
           num_part=${param}
           pct_part=$(expr 95 / $num_part)
           pct=5
           
           echo "PARTICOES: $num_part";
           echo "PCT_PART: $pct_part";
           echo "PCT: $pct";
           
           ;;
        FMT)
           echo "XXX"
           pct=$(expr $pct_part + $pct)
           echo $pct
           echo "Formatando $PARAM"
           echo "XXX"
           ;;
        
     esac

  done

}

#
# Formata o disco
#
_formata_disco() {
   echo "XXX"
   echo 5 # 5%
   echo "Inicializando o disco"
   echo "XXX"
   diskInit $HD   
   diskPart $HD | _formata_reply
   
}

formata_disco() {
   _formata_disco | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "DISCO ${HD}" --gauge "Preparando..."  8 50 0
}

#
# Monta o alvo
#
_monta_alvo() {
   install -d ${TARGET_MOUNT}
   mount /dev/${HD}s1a ${TARGET_MOUNT}
   install -d ${TARGET_MOUNT}/tmp
   mount /dev/${HD}s1d ${TARGET_MOUNT}/tmp
   
   if [ -e /dev/${HD}s1e ] ; then
      install -d ${TARGET_MOUNT}/usr
      mount /dev/${HD}s1e ${TARGET_MOUNT}/usr
   fi

   if [ -e /dev/${HD}s1f ] ; then
      install -d ${TARGET_MOUNT}/var
      mount /dev/${HD}s1f ${TARGET_MOUNT}/var
   fi

   if [ -e /dev/${HD}s1g ] ; then
      install -d ${TARGET_MOUNT}/mosman
      mount /dev/${HD}s1g ${TARGET_MOUNT}/mosman
   fi

}

monta_alvo() {
   _monta_alvo | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "INICIALIZANDO DISPOSITIVOS" --gauge "Preparando..."  8 50 0
}


_desmonta_alvo() {
   
   if [ -e /dev/${HD}s1g ] ; then
      umount ${TARGET_MOUNT}/mosman
   fi

   if [ -e /dev/${HD}s1f ] ; then
      umount ${TARGET_MOUNT}/var
   fi

   if [ -e /dev/${HD}s1e ] ; then
      umount ${TARGET_MOUNT}/usr
   fi

   umount ${TARGET_MOUNT}/tmp
   umount ${TARGET_MOUNT}

}

desmonta_alvo() {
   _desmonta_alvo | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "FECHANDO DISPOSITIVOS" --gauge "Preparando..."  8 50 0
}







#
# Instala a base do sistema operacional
#
_instala_base() {
   echo XXX
   echo 6
   echo Instalando a base do FREEBSD 7.0
   echo XXX
   
   # INSTALA A BASE
   cat ${FREEBSD_DIR}/base/base.?? | tar --unlink -xpzf - -C ${TARGET_MOUNT} 2>&1 >/dev/null
   install -d ${TARGET_MOUNT}/cdrom
   
   echo XXX
   echo 72
   echo Instalando o kernel
   echo XXX
   
   # COPIA O KERNEL
   install -d ${TARGET_MOUNT}/boot
   cat ${FREEBSD_DIR}/kernels/generic.?? | tar --unlink -xpzf - -C ${TARGET_MOUNT}/boot 2>&1 >/dev/null
   
   echo XXX
   echo 85
   echo Instalando Virtex
   echo XXX
   
   # INSTALA O VIRTEX
   
   sleep 2
   
   echo XXX
   echo 100
   echo Finalizado
   echo XXX
   
}

instala_base() {
   _instala_base | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "INSTALACAO DO FREEBSD" --gauge "Preparando..."  8 50 0
}

#
# Instala as configuracoes adicionais
#
_instala_configs() {
   sleep 1
}

instala_configs() {
   _instala_configs | ${DIALOG} --clear --backtitle "$BACKTITLE" --title "CONFIGURACOES INICIAIS" --gauge "Preparando..."  8 50 0
}

#
# Instala Pacotes
#
_instala_pacotes() {
   # CRIA UMA COPIA NO DESTINO
   install -d ${TARGET_MOUNT}/${PKG_DIR}
   cp -R ${PKG_DIR}/* ${TARGET_MOUNT}/${PKG_DIR}
   
   pacotes=$(ls $PKG_DIR)
   num_pacotes=$(ls $PKG_DIR |wc -l |sed -E 's/ //g' )
   pct_pack=$(expr 1000 / $num_pacotes)
   
   #echo "NUM: $num_pacotes"
   #echo "PCT: $pct_pack"
   
   #echo $pct_pack | sed -E 's/^(.*)([0-9])/0\1.\2/g'
   
   pct=0
   for pkg in $(ls $PKG_DIR) ; do
      local pkg_name=$(echo $pkg | sed -E 's/(.tbz)//g')
      #echo $pkg $pkg_name
      
      pct=$(expr "$pct_pack" + "$pct")
      #pct_display=$(echo $pct | sed -E 's/^(.*)([0-9])/0\1.\2/g');
      pct_display=$(echo $pct | sed -E 's/^(.*)([0-9])/0\1/g');
      
      echo "XXX"
      echo $pct_display
      echo "$pkg_name"
      echo "XXX"
      
       

      if chroot ${TARGET_MOUNT} pkg_info ${pkg_nanme} > /dev/null 2>&1 ; then
         echo "" | chroot ${TARGET_MOUNT} pkg_add ${PKG_DIR}/${pkg} > /dev/null 2>&1
      fi
      
      
   done
   
   echo "XXX"
   echo "100"
   echo "CONCLUIDO"
   echo "XXX"


}

instala_pacotes() {
   _instala_pacotes | ${DIALOG} --clear --backtitle "$BACKTITLE" --title " INSTALANDO PACOTES " --gauge "Preparando..."  8 50 0
}




#
# Instala os pacotes do VA
#
_va_instala_pacotes() {
   sleep 1
}

va_instala_pacotes() {
   _instala_pacotes | ${DIALOG} --backtitle "$BACKTITLE" --title "Instalacao dos Pacotes" --gauge "Instalando..." 8 50 0
}

#
# Configura o squid
#
_config_squid() {
	#install -o squid -g squid -d /mosman/proxy/cache
	#install -o squid -g squid -d /mosman/proxy/logs
}

#
# Configura o ProFTPd
#
_config_proftpd() {

}

#
# Configura o DNS
#
_config_dns() {

}

#
# Configura o email
#
_config_email() {

}

#
# Configura o PostgreSQL
#
_config_postgresql() {

}

#
# Configura o antivirus
#
_config_clamav() {

}




#
# Configura a senha do root
#
config_senha() {

}

#
# Configuracoes do VA
####################################################

#
# Configuracoes da interface externa
#
# TODO: Salvar arquivo de configuracoes
#
_va_interface_externa() {
  ${DIALOG} --stdout --title "Network"  --yesno "Voce deseja configurar a interface externa ?" 7 55
  if [ $? -ne 0 ]; then
    return
  fi

  options=""
  num=0
	
  for iface in ${IFACELIST} ; do
    options="${options} $iface Rede"
    num=`expr ${num} \+ 1`
  done

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
    fi
  done

}

#
# Configuracoes de acesso banda larga
#
_va_config_bandalarga() {
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

#
# Configuracao TCP/IP
#
_va_config_tcpip() {
  # Verifica se a configuracao do TCPIP foi setada na tela de selecao de Atuadores
  if ! echo "$ATUADORES" | grep -q "$A_BLTCP_CODE" ; then 
    return
  fi

  if [ -n "${IFACELIST_INTERNAS}" ] ; then

    if [ "${CONF_CLIENTES_BL}" = "sim" ] ; then

      INTTCPIP=""
      while [ -z "${INTTCPIP}" ] ; do
        cancel=0
        INTTCPIP=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
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
      TCPIP_NAS_ID=1
    fi
  fi
}

#
# Configuracao PPPOE
#
_va_config_pppoe() {
  # Verifica se a configuracao do TCPIP foi setada na tela de selecao de Atuadores
  if ! echo "$ATUADORES" | grep -q "$A_BLPPPOE_CODE" ; then 
    return
  fi

  if [ -n "${IFACELIST_INTERNAS}" ] ; then

    if [ "${CONF_CLIENTES_BL}" = "sim" ] ; then

      INTPPPOE=""
      while [ -z "${INTTCPIP}" ] ; do
        cancel=0
        INTPPPOE=$( ${DIALOG} --stdout --backtitle "$BACKTITLE" \
          --title "BANDA LARGA PPPoE" \
          --menu "Selecione a interface (placa) utilizada para clientes PPPoE:" 12 40 $num \
          $options )

        if [ $? -ne 0 ] ; then
          # Confirmar se o cara deseja cancelar a instalacao
          if ${DIALOG} --stdout --clear --backtitle "${BACKTITLE}" --yesno "Deseja abandonar a configuracao do atuador PPPoE???" 8 50 ; then
            cancel=1
            break;
          fi
        fi
      done
      PPPOE_NAS_ID=2
    fi
  fi
}

#
# Salva as configuracoes de rede
#
_va_network_saveconfig() {
   #
   # TODO: SALVAR AS CONFIGURACOES
   #

}


#
# Configuracao de Rede do VA
#
_va_network_config() {
   _va_interface_externa
   _va_config_bandalarga
   _va_config_tcpip
   _va_config_pppoe
   
   # Salva as configuracoes
   _va_network_saveconfig

}

#
# Configuracoes do Banco de dados
#
_va_db_config() {
   if [ "$SERVER_TYPE" -eq $ST_MASTER_CODE ] ; then
     # MASTER - Gerar automaticamente
     DB_IP=127.0.0.1
     DB_USER=virtex
     DB_PASS=$( head -c 10 /dev/random | b64encode /dev/null |sed -E 's/^begin.*//g' | sed -E 's/=//g' | sed -E 's/[^A-Za-z0-9]/x/g' | grep -v -E '^$' )
   else
     # SLAVE - Perguntar informacoes do servidor master
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
   fi

   #
   # TODO: Salvar as configuracoes do banco de dados
   #


}

#
# Configuracao do servidor de comunicacoes
#
_va_comm_config() {
  # Criacao das chaves locais
  COMM_CHAVE=$( head -c 10 /dev/random | b64encode /dev/null |sed -E 's/^begin.*//g' | sed -E 's/=//g' | sed -E 's/[^A-Za-z0-9]/x/g' | grep -v -E '^$' )
  COMM_USER="virtex"
  COMM_PASS=$( head -c 10 /dev/random | b64encode /dev/null |sed -E 's/^begin.*//g' | sed -E 's/=//g' | sed -E 's/[^A-Za-z0-9]/x/g' | grep -v -E '^$' )
  
  #
  # TODO: Gravar
  #
  #echo "COMM_CHAVE: $COMM_CHAVE"
  #echo "COMM_USER.: $COMM_USER"
  #echo "COMM_PASS.: $COMM_PASS" 

}


#
# Configuracao do VA
#
va_config() {
   #_va_network_config   # Configuracoes de Rede
   _va_db_config        # Configuracao do banco de dados
   _va_comm_config      # Configuracao do servidor de comunicacoes
   

   #echo "DBH: $DB_IP"
   #echo "DBU: $DB_USER"
   #echo "DBP: $DB_PASS"

}

##################################################
# Rotina principal do instalador
#########

main() {
  #
  # Escolhas iniciais
  #
  #disco
  #tipo_servidor
  #confirma_instalacao
  
  #
  # Instalacao
  #
  HD=ad6
  
  #formata_disco
  #monta_alvo
  #instala_base
  #instala_pacotes
  #instala_configs
  #va_instala_pacotes
  
  #
  # Configuracoes
  #
  #config_senha
  #va_config
  

  #desmonta_alvo



}


main

