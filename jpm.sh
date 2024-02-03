#!/usr/bin/env bash

WORKDIR=$(pwd)
BUILD_DIR=$WORKDIR/target
DEPENDENCIES=dependencies.txt
BUILD_LIB=$BUILD_DIR/lib
JPM_MODULE=$WORKDIR/.jpm/
DEPENDENCIES_FILE=$WORKDIR/$DEPENDENCIES
SOURCE_PATTERN=src/main/java/
SOURCE=$WORKDIR/$SOURCE_PATTERN
REMOTE_REPO=https://raw.githubusercontent.com/danroxha/jpm/main/jpm.sh

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
  libs=$BUILD_DIR/
  for _jar in $(ls $BUILD_LIB) 
    do
      _abs=$BUILD_LIB/$_jar
      libs=$libs:$_abs
    done	
  echo $libs
}

jpm_install() {
  mkdir -p $BUILD_DIR $BUILD_LIB
  cp -r $JPM_MODULE* $BUILD_LIB

  if [[ ! -z $(ls $JPM_MODULE) ]]
    then
      dependecies=$(jpm_load_dependecies)
    fi
    
  java_files=$(find $SOURCE -name "*.java")
  log "building $java_files"
  
  if [ ! -z $dependecies ]
    then
      javac -d $BUILD_DIR $java_files -cp $dependecies
    else
      javac -d $BUILD_DIR $java_files
    fi
}

jpm_find_main_file() {
  java_files=$(find $SOURCE -name "*.java")
  _qtd=0
  main_file=""
  for _file in $java_files
    do
      cat $_file | grep "public static void main" > /dev/null
      if [ $? -eq 0 ]
        then
          main_file="$main_file $_file"
          _qtd=$((_qtd + 1))
        fi
    done
   if [ $_qtd -gt 1 ]
     then
       log "Cannot defined main class [ $main_file ]"
       exit 1
     fi
   echo $main_file	
}

jpm_find_main_ref() {
  main_file=$(jpm_find_main_file)
  main_file=$(echo $main_file | sed "s|$SOURCE||")
  main_file=$(echo $main_file | sed 's/\.java//g')
  _pkg=$(echo $main_file | sed 's/\//\./g')
  echo $_pkg
}

jpm_find_main_class() {
  main_file=$(jpm_find_main_file)
  main_file=$(echo $main_file | sed "s|$SOURCE||")
  main_file=$(echo $main_file | sed 's/\.java/\.class/g')
  echo $main_file
}

jpm_run() {
  jpm_resolve
  jpm_install
    
  dependecies=$(jpm_load_dependecies)
  main_class=$(jpm_find_main_ref)
  
  java -cp $dependecies $main_class
}

jpm_package() {
  jpm_clean_force
  jpm_resolve
  jpm_install

  main_class=$(jpm_find_main_class)
  main_file=$(jpm_find_main_file)
  main_ref=$(jpm_find_main_ref)
 
  rm -rf $BUILD_DIR/build
  _classes=$(find $BUILD_DIR -name "*.class")
  _pkgs=""

  for _class in $_classes
    do
     _class=$(echo $_class | sed "s|$BUILD_DIR\/||")
     if [ $main_class = $_class ] ; then continue ; fi
     _pkgs="$_pkgs $_class"
    done
  cd $BUILD_DIR ; jar cf basic.jar $main_class $_pkgs
}

_lowercase() {
  echo $1 | tr '[:upper:]' '[:lower:]'
}

_capitalize() {
  _cap=$(_lowercase $1)
  _cap=$(echo $_cap | awk '{
      for ( i=1; i <= NF; i++) {
        sub(".", substr(toupper($i), 1,1) , $i);
        print $i;
        # or
        # print substr(toupper($i), 1,1) substr($i, 2);
      }
  }')

  echo $_cap
}

jpm_new() {
  suffix=Application
  echo "New project JPM"
  
  echo -ne "project name: "
  read project_name
  project_name=$(_lowercase $project_name)
  
  echo -ne "package name: "
  read package_name
  package_name=$(_lowercase $package_name)

  echo -ne "main class: "
  read main_class

  _pkg=$package_name
  package_name=$(echo $package_name | sed 's/\./\//g')

  mkdir -p $project_name/$SOURCE_PATTERN/$package_name

  cat << EOF > $project_name/$SOURCE_PATTERN/$package_name/$main_class$suffix.java
package $_pkg;

public class $main_class$suffix {
  public static void main(String[] args) {
    System.out.println("Hello JPM");
  }
}
EOF

  log "Donwloading JPM"

  wget $REMOTE_REPO -P $project_name -q ?> /dev/null
  chmod +x $project_name/jpm.sh

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
  
  cat << EOF > $project_name/$DEPENDENCIES
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

  echo "local "$WORKDIR/$project_name
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
