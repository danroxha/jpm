#!/usr/bin/env bash

WORKDIR=$(pwd)
BUILD_DIR=$WORKDIR/target
DEPENDENCIES=dependencies.txt
BUILD_LIB=$BUILD_DIR/lib
JPM_MODULE=$WORKDIR/.jpm/
DEPENDENCIES_FILE=$WORKDIR/$DEPENDENCIES
SOURCE_PATTERN=src/main/java/
SOURCE=$WORKDIR/$SOURCE_PATTERN

log() {
	d_format=$(date +"%Y-%m-%d %H:%M:%S")
	echo $d_format $1
}

jpm_clean() {
  log "removing $BUILD_DIR"
  $(rm -rfv $BUILD_DIR ?> /dev/null) 2> /dev/null
  log "removing $JPM_MODULE"
  $(rm -rfv $JPM_MODULE 1> /dev/null) 2> /dev/null
}

_await() {
  n=$1
  n_jobs=$(($(wc -l < <(jobs)) + 0)) 
  while [ $n_jobs -gt 1 ]
    do    
      d_format=$(date +"%Y-%m-%d %H:%M:%S")
      n_jobs=$(($(wc -l < <(jobs)) + 0))
      resolved=$((n - n_jobs + 1 ))
      echo -ne "\r$d_format waiting $resolved of $n"
      sleep 0.5
    done
    echo ""
}

_parse_dependencies() {
  repo=""
  while read line; do
  	if [[ $line =~ ^# ]] || [[ $line =~ ^// ]]  
  	  then 
  	    continue 
  	  fi
  	
    origin=https://repo1.maven.org/maven2
    dependency=$(echo $line | sed "s/'//ig")
	group=$(echo $dependency | cut -d':' -f1)
	group=$(echo $group | cut -d' ' -f2)
    group=$(echo $group | sed "s/[.]/\//g")
	artif=$(echo $dependency | cut -d':' -f2)
	version=$(echo $dependency | cut -d':' -f3)

    if [[ -z $group ]] || [[ -z $version ]] || [[ -z $artif ]] 
      then 
        continue
      fi
    
    repo="$repo $origin/$group/$artif/$version/$artif-$version.jar"
  done < $DEPENDENCIES_FILE
 
  echo $repo
}

jpm_resolve() {
  mkdir $JPM_MODULE 2> /dev/null

  if [ ! -e $DEPENDENCIES_FILE ] ; then return 0 ; fi
  
  qtd_dep=0
  repo=$(_parse_dependencies)

  for url in $repo
    do
      dependency=$(basename $url)
      if [ ! -e $JPM_MODULE/$dependency ]
        then
          qtd_dep=$(( qtd_dep + 1 ))
          log "dependency's resolving	 $dependency [$url]"
          wget $url -P $JPM_MODULE -q ?> /dev/null &
        else
		  log "dependency resolved $dependency"
      fi
    done    
	_await $qtd_dep

	log "local .jpm "$JPM_MODULE
}

jpm_load_dependecies() {
  LIBRIES=$BUILD_DIR/
  for _JAR in $(ls $BUILD_LIB) 
    do
      ABS=$BUILD_LIB/$_JAR
      LIBRIES=$LIBRIES:$ABS
	done	
  echo $LIBRIES
}

jpm_install() {
	mkdir -p $BUILD_DIR $BUILD_LIB
    cp -r $JPM_MODULE* $BUILD_LIB

	if [[ ! -z $(ls $JPM_MODULE) ]]
	  then
        DEPENDECIES=$(jpm_load_dependecies)
	  fi
	  
	JAVA_FILES=$(find $SOURCE -name "*.java")
	log "building $JAVA_FILES"
	
	if [ ! -z $DEPENDECIES ]
	  then
	    javac -d $BUILD_DIR $JAVA_FILES -cp $DEPENDECIES
	  else
	    javac -d $BUILD_DIR $JAVA_FILES
	  fi
}

jpm_find_main_file() {
  JAVA_FILES=$(find $SOURCE -name "*.java")
  QTD=0
  MAIN_FILE=""
  for FILE in $JAVA_FILES
    do
      cat $FILE | grep "public static void main" > /dev/null
      if [ $? -eq 0 ]
        then
          MAIN_FILE="$MAIN_FILE $FILE"
          QTD=$((QTD + 1))
        fi
    done
   if [ $QTD -gt 1 ]
     then
       log "Cannot defined main class [ $MAIN_FILES ]"
       exit 1
     fi
   echo $MAIN_FILE	
}

jpm_find_main_ref() {
  MAIN_FILE=$(jpm_find_main_file)
  MAIN_FILE=$(echo $MAIN_FILE | sed "s|$SOURCE||")
  MAIN_FILE=$(echo $MAIN_FILE | sed 's/\.java//g')
  PKG=$(echo $MAIN_FILE | sed 's/\//\./g')
  echo $PKG
}

jpm_find_main_class() {
  MAIN_FILE=$(jpm_find_main_file)
  MAIN_FILE=$(echo $MAIN_FILE | sed "s|$SOURCE||")
  MAIN_FILE=$(echo $MAIN_FILE | sed 's/\.java/\.class/g')
  echo $MAIN_FILE
}


jpm_run() {
    jpm_resolve
    jpm_install
    
    DEPENDECIES=$(jpm_load_dependecies)
	MAIN_CLASS=$(jpm_find_main_ref)
	
	java -cp $DEPENDECIES $MAIN_CLASS
}

jpm_package() {
  jpm_clean_force
  jpm_resolve
  jpm_install

  MAIN_CLASS=$(jpm_find_main_class)
  MAIN_FILE=$(jpm_find_main_file)
  MAIN_REF=$(jpm_find_main_ref)
 
  rm -rf $BUILD_DIR/build
  CLASSES=$(find $BUILD_DIR -name "*.class")
  PGKS=""

  for CLASS in $CLASSES
    do
     CLASS=$(echo $CLASS | sed "s|$BUILD_DIR\/||")
     if [ $MAIN_CLASS = $CLASS ] ; then continue ; fi
     PKGS="$PKGS $CLASS"
    done
  cd $BUILD_DIR ; jar cf basic.jar $MAIN_CLASS $PGKS
}

_lowercase() {
	echo $1 | tr '[:upper:]' '[:lower:]'
}

_capitalize() {
	CAP=$(_lowercase $1)
	CAP=$(echo $CAP | awk '{
	     for ( i=1; i <= NF; i++) {
	         sub(".", substr(toupper($i), 1,1) , $i);
	         print $i;
	         # or
	         # print substr(toupper($i), 1,1) substr($i, 2);
	     }
	}')

	echo $CAP
}

jpm_new() {
	SUFFIX=Application
	echo "New project JPM"
	
	echo -ne "project name: "
	read PROJECT_NAME
	PROJECT_NAME=$(_lowercase $PROJECT_NAME)
	
	echo -ne "package name: "
	read PACKAGE_NAME
	PACKAGE_NAME=$(_lowercase $PACKAGE_NAME)

	echo -ne "main class: "
	read MAIN_CLASS

	PKG=$PACKAGE_NAME
	PACKAGE_NAME=$(echo $PACKAGE_NAME | sed 's/\./\//g')

	mkdir -p $PROJECT_NAME/$SOURCE_PATTERN/$PACKAGE_NAME

	cat << EOF > $PROJECT_NAME/$SOURCE_PATTERN/$PACKAGE_NAME/$MAIN_CLASS$SUFFIX.java
package $PKG;

public class $MAIN_CLASS$SUFFIX {
	public static void main(String[] args) {
		System.out.println("Hello JPM");
	}
}
EOF

  cp jpm.sh $PROJECT_NAME/

  echo "
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░   ░░        ░░░   ░░░░░░░   ░
▒▒▒▒▒▒   ▒▒   ▒▒▒▒   ▒  ▒   ▒▒▒    ░
▒▒▒▒▒▒   ▒▒   ▒▒▒▒   ▒   ▒   ▒ ▒   ░
▓▓▓▓▓▓   ▓▓        ▓▓▓   ▓▓   ▓▓   ░
▓▓▓▓▓▓   ▓▓   ▓▓▓▓▓▓▓▓   ▓▓▓  ▓▓   ░
▓  ▓▓▓   ▓▓   ▓▓▓▓▓▓▓▓   ▓▓▓▓▓▓▓   ░
██     ████   ████████   ███████   ░
███████████████████████████████████░
#----------------------------------#
# JPM: Simples Build System        #
#--------------------------------- #

Comandos:

* jpm new: Cria um novo projeto JPM
* jpm resolve: Instalar os pacotes adicionados em dependencies.txt.
* jpm list: Lista os pacotes Java instalados.
* jpm run: Executa os comandos 'resolve', 'compile' e identifica automaticamente a class Main e executa a aplicação.
* jpm clean: Remove o target [ compilação ]

Exemplo:
$ jpm run

$ New project JPM
$ project name: hello
$ package name: com.github.danroxha.hello
$ main class: Hello

$ jpm run

Para mais informações: https://github/danroxha/jpm"
	
  cat << EOF > $PROJECT_NAME/$DEPENDENCIES
# Support to Gradle (Short). Only Central Repository
# implementation 'aws.sdk.kotlin:aws-core-jvm:1.0.48'
# 
# // https://mvnrepository.com/artifact/org.keycloak/keycloak-core
# implementation 'org.keycloak:keycloak-core:23.0.5'

// https://mvnrepository.com/artifact/org.xerial/sqlite-jdbc
implementation 'org.xerial:sqlite-jdbc:3.45.1.0'

// https://mvnrepository.com/artifact/org.slf4j/slf4j-api
implementation 'org.slf4j:slf4j-api:1.7.36'

EOF

  echo "local "$WORKDIR/$PROJECT_NAME

}

for arg in $* 
  do
    case $arg in
      "clean" ) jpm_clean ;;
      *) ;;
    esac
  done

for arg in $* 
  do
	case $arg in
	  "resolve" ) jpm_resolve ;;
	  "install" ) jpm_install ;;
	  "package" ) jpm_package ;;
	  "run" ) jpm_run ;;
	  "new" ) jpm_new ;;
	  *) ;;
	esac
  done
