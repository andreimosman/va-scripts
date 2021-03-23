
#
# DMESG
#
_dmesg() {
   if [ -f /var/run/dmesg.boot ] ; then
      cat /var/run/dmesg.boot
   else
      dmesg
   fi
}

#
# Retorna a lista dos HDs encontrados.
#
hdlist() {
  _dmesg | grep -E '([as]d|da|amrd)[0-9]+:'|sed -E 's/://g' |sed -E 's/ /|/'|sed -E 's/ /|/'|sed -E 's/( at ).*//g'|sed -E 's/[\<\>]//g'|sed -E 's/ /_/g'|grep 'MB|'|sort 
}

#
# Retorna os itens do menu de escolha do HD para poder ser utilizado pelo dialog
#
menuhd() {
  local hd=""   # HD
  local tm=""   # TAMANHO
  local ds=""   # DESCRICAO
  local MENU_HD=""
  local LISTA=""
  LISTA=$( hdlist |sed -E 's/\|/ /g' )
  #`echo ${HDLIST}|sed -E 's/\|/ /g'`
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
  
  echo ${MENU_HD}

}

#
# Retorna a lista dos CDs encontrados.
#
cdlist() {
  _dmesg |grep -E '[as]?cd[0-9]+:'|sed -E 's/://g' |sed -E 's/ /|/'|sed -E 's/ /|/'|sed -E 's/( at ).*//g'|sed -E 's/[\<\>]//g'|sed -E 's/ /_/g'|grep -v "FAILURE"|sort
}



#
# Retorna a lista das interfaces de rede encontradas.
#
iflist() {
  /sbin/ifconfig -l|sed -E 's/(plip|lo|sl|ppp|tun|pty|md|faith|pflog)[0-9]+//g'|sort
}

#
# Verifica se um elemento esta dentro de um array
#
in_array() {
	local v=$1
	shift
	for i in "$@"; do
		if test "$i" = "$v"; then
			return 0
		fi
	done
	return 1
}


diskLabelRead() {
   local _disk=$1

   if [ -z "${_disk}" ] ; then
      return 255
   fi
   
   /sbin/disklabel -r ${_disk}s1
}

#
# Inicializa e zera o disco
# 
diskInit() {
   local _disk=$1
   
   if [ -z "${_disk}" ] ; then
      return 255
   fi
   
   # Formata o disco
   /bin/dd if=/dev/zero of=/dev/${_disk} count=128 2> /dev/null > /dev/null
   
   # Usar todo o disco para o sistema
   /sbin/fdisk -I ${_disk} 2> /dev/null > /dev/null
   
   # Inicializacao do disklabel
   /sbin/disklabel -rw ${_disk}s1 auto 2> /dev/null > /dev/null
   
   sleep 1
   
}

#
# Particiona o disco (layout padrao mosman consultoria)
#
diskPart() {

   local _disk=$1
   
   if [ -z "${_disk}" ] ; then
      return 255
   fi

   local tamanho=$(diskSize ${_disk})
   local setores=$(diskLabelSectors ${_disk})

   #tamanho=91234;
   #tamanho=19000
   #setores=$(expr $tamanho \* 1024 \* 2)
   
   #echo "TAMANHO: ${tamanho}"
   
   
   # Tamanho das particoes expresso em MB
   #     0 indica que a particao nao sera criada
   #    -1 indica que a particao utilizara o resto do HD
   
   
   local particoes=5
   
   if [ ${tamanho} -lt 20000 ] ; then
      raiz=-1
      swap=1024
      tmp=512
      usr=0
      var=0
      mosman=0
      local particoes=2
   elif [ ${tamanho} -lt 40000 ] ; then
      raiz=2048
      swap=1024
      tmp=1024
      usr=5120
      var=5120
      mosman=-1
   elif [ ${tamanho} -lt 120000 ] ; then
      raiz=9216
      swap=2048
      tmp=2048
      usr=$(expr ${tamanho} \* 10 / 100) # 10%
      var=$(expr ${tamanho} \* 10 / 100) # 10%
      mosman=-1
   else
      raiz=9216
      swap=2048
      tmp=2048
      usr=$(expr ${tamanho} \* 8 / 100) # 8%
      var=$(expr ${tamanho} \* 8 / 100) # 8%
      mosman=-1
   fi

   echo "PART: ${particoes}"

   
   #
   # Numero de blocos
   #
   b_swap=$(expr $swap \* 1024 \* 2)
   b_tmp=$(expr $tmp \* 1024 \* 2)
   b_usr=$(expr $usr \* 1024 \* 2)
   b_var=$(expr $var \* 1024 \* 2)
   
   if [ $raiz -eq -1 ] ; then
      #echo "RAIZ RESTO";
      b_raiz=$(expr $setores \- $b_swap \- $b_tmp \- $b_usr \- $b_var);
      raiz=$(expr $b_raiz / 2 / 1024)
   else
      b_raiz=$(expr $raiz \* 1024 \* 2)
   fi

   if [ $mosman -eq -1 ] ; then
      b_mosman=$(expr $setores \- $b_raiz \- $b_swap \- $b_tmp \- $b_usr \- $b_var);
      mosman=$(expr $b_mosman / 2 / 1024)
   else
      b_mosman=$(expr $mosman \* 1024 \* 2)
   fi
   
   #
   # Offset
   #
   
   local off_raiz=0
   local off_swap=$(expr $off_raiz + $b_raiz)
   local off_tmp=$(expr $off_swap + $b_swap)
   local off_usr=$(expr $off_tmp + $b_tmp)
   local off_var=$(expr $off_usr + $b_usr)
   local off_mosman=$(expr $off_var + $b_var)
   
   #
   # Modelo do disklabel e fstab
   #
   local modelo=/tmp/label.modelo
   
   cat /dev/null > $modelo
   echo "a: $b_raiz $off_raiz 4.2BSD 0 0 0" >> $modelo
   echo "b: $b_swap $off_swap swap" >> $modelo
   echo "d: $b_tmp $off_tmp 4.2BSD 0 0 0" >> $modelo
   if [ $usr -gt 0 ] ; then
      echo "e: $b_usr $off_usr 4.2BSD 0 0 0" >> $modelo
   fi
   if [ $var -gt 0 ] ; then
      echo "f: $b_var $off_var 4.2BSD 0 0 0" >> $modelo
   fi
   if [ $mosman -gt 0 ] ; then
      echo "g: $b_mosman $off_mosman 4.2BSD 0 0 0" >> $modelo
   fi
   
   #
   # Disklabel (cria a particao e marca como bootavel
   #
   
   /sbin/disklabel -R -B ${HD}s1 $modelo 2>&1 > /dev/null
   
   #
   # Formata as particoes
   #
   
   # raiz
   echo "FMT:/"
   /sbin/newfs /dev/${_disk}s1a 2>&1 > /dev/null

   # tmp
   echo "FMT:/tmp"
   /sbin/newfs /dev/${_disk}s1d 2>&1 > /dev/null

   # usr
   if [ $usr -gt 0 ] ; then
      echo "FMT:/usr"
      /sbin/newfs /dev/${_disk}s1e 2>&1 > /dev/null
   fi
   
   # var
   if [ $var -gt 0 ] ; then
      echo "FMT:/var"
      /sbin/newfs /dev/${_disk}s1f 2>&1 > /dev/null
   fi
   
   # mosman
   if [ $mosman -gt 0 ] ; then
      echo "FMT:/mosman"
      /sbin/newfs /dev/${_disk}s1g 2>&1 > /dev/null
   fi
   
   #cat $modelo
   #echo "RAIZ...: $raiz $off_raiz $b_raiz";
   #echo "SWAP...: $swap $off_swap $b_swap";
   #echo "TMP....: $tmp $off_tmp $b_tmp";
   #echo "USR....: $usr $off_usr $b_usr";
   #echo "VAR....: $var $off_var $b_var";
   #echo "MOSMAN.: $mosman $off_mosman $b_mosman";
   
}





#
# Retorna o numero de setores do disco
#
diskLabelSectors() {
   local _disk=$1

   if [ -z "${_disk}" ] ; then
      return 255
   fi

   diskLabelRead ${_disk} | /usr/bin/tr -s ' ' | /usr/bin/sed 's/^ //g' | /usr/bin/grep '^c: ' | /usr/bin/cut -f2 -d' '

}

#
# Retorna o tamanho do disco (em MB)
#
diskSize() {
   local _disk=$1

   if [ -z "${_disk}" ] ; then
      return 255
   fi
   
   hdlist|grep ${_disk}|cut -f 2 -d'|'|sed -E 's/MB//g'
   
}
   

#hdlist
#cdlist
#iflist

#diskLabelSectors ad4
#hdlist
#diskSize ad4
#diskPart ad4


