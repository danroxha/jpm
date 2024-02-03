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
LOG_SUFFIX=[JPM]

log() {
  d_format=$(date +"%Y-%m-%d %H:%M:%S")
  echo $d_format $LOG_SUFFIX $1
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
          log "dependency	[loading]  $dependency [$url]"
          wget $url -P $JPM_MODULE -q ?> /dev/null &
        else
          log "dependency [loaded] $dependency"
      fi
    done    
  _await $qtd_dep

  log "path "$JPM_MODULE
}

jpm_load_dependencies() {
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
 
  if [ -d $JPM_MODULE ] && [[ ! -z $(ls $JPM_MODULE) ]]
    then
      cp -r $JPM_MODULE* $BUILD_LIB
      dependencies=$(jpm_load_dependencies)
    else
      log "didn't find any dependencies, you might want to run \`$ jpm resolve\`"
    fi
    
  java_files=$(find $SOURCE -name "*.java")
  log "building $java_files"
  
  if [ ! -z $dependencies ]
    then
      javac -d $BUILD_DIR $java_files -cp $dependencies
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
       log "cannot defined main class [ $main_file ]"
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
    
  dependencies=$(jpm_load_dependencies)
  main_class=$(jpm_find_main_ref)
  
  java -cp $dependencies $main_class
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

_create_directories() {
  _project_dir=$1
  _package_dir=$(echo $2 | sed 's/\./\//g')
  _path=$WORKDIR/$_project_dir/$SOURCE_PATTERN$_package_dir

  mkdir -p $_path
  log "created "$_path
}

_create_main_class_file() {
  _suffix=Application
  _project_dir=$1
  _pkg=$2
  _main_class=$3
  _package_dir=$(echo $_pkg | sed 's/\./\//g')
  _path=$_project_dir/$SOURCE_PATTERN$_package_dir
  _classname=$_main_class$_suffix.java

  log "created  $WORKDIR/$_path/$_classname"

  cat << EOF > $_path/$_classname
package $_pkg;

public class $_main_class$_suffix {
  public static void main(String[] args) {
    System.out.println("Hello JPM");
  }
}
EOF
}

_create_gitignore() {
  _project_dir=$1
  cat << EOF > $_project_dir/.gitignore
# JPM

.jpm/*
target/*

### Java ###
# Compiled class file
*.class

# Log file
*.log

# BlueJ files
*.ctxt

# Mobile Tools for Java (J2ME)
.mtj.tmp/

# Package Files #
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar

# virtual machine crash logs, see http://www.java.com/en/download/help/error_hotspot.xml
hs_err_pid*
replay_pid*

### VisualStudioCode ###
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
!.vscode/*.code-snippets

# Local History for Visual Studio Code
.history/

# Built Visual Studio Code Extensions
*.vsix

### VisualStudioCode Patch ###
# Ignore all local history of files
.history
.ionide

# Created by https://www.toptal.com/developers/gitignore/api/intellij
# Edit at https://www.toptal.com/developers/gitignore?templates=intellij

### Intellij ###
# Covers JetBrains IDEs: IntelliJ, RubyMine, PhpStorm, AppCode, PyCharm, CLion, Android Studio, WebStorm and Rider
# Reference: https://intellij-support.jetbrains.com/hc/en-us/articles/206544839

# User-specific stuff
.idea/**/workspace.xml
.idea/**/tasks.xml
.idea/**/usage.statistics.xml
.idea/**/dictionaries
.idea/**/shelf

# AWS User-specific
.idea/**/aws.xml

# Generated files
.idea/**/contentModel.xml

# Sensitive or high-churn files
.idea/**/dataSources/
.idea/**/dataSources.ids
.idea/**/dataSources.local.xml
.idea/**/sqlDataSources.xml
.idea/**/dynamic.xml
.idea/**/uiDesigner.xml
.idea/**/dbnavigator.xml

# Gradle
.idea/**/gradle.xml
.idea/**/libraries

# Gradle and Maven with auto-import
# When using Gradle or Maven with auto-import, you should exclude module files,
# since they will be recreated, and may cause churn.  Uncomment if using
# auto-import.
# .idea/artifacts
# .idea/compiler.xml
# .idea/jarRepositories.xml
# .idea/modules.xml
# .idea/*.iml
# .idea/modules
# *.iml
# *.ipr

# CMake
cmake-build-*/

# Mongo Explorer plugin
.idea/**/mongoSettings.xml

# File-based project format
*.iws

# IntelliJ
out/

# mpeltonen/sbt-idea plugin
.idea_modules/

# JIRA plugin
atlassian-ide-plugin.xml

# Cursive Clojure plugin
.idea/replstate.xml

# SonarLint plugin
.idea/sonarlint/

# Crashlytics plugin (for Android Studio and IntelliJ)
com_crashlytics_export_strings.xml
crashlytics.properties
crashlytics-build.properties
fabric.properties

# Editor-based Rest Client
.idea/httpRequests

# Android studio 3.1+ serialized cache file
.idea/caches/build_file_checksums.ser

### Intellij Patch ###
# Comment Reason: https://github.com/joeblau/gitignore.io/issues/186#issuecomment-215987721

# *.iml
# modules.xml
# .idea/misc.xml
# *.ipr

# Sonarlint plugin
# https://plugins.jetbrains.com/plugin/7973-sonarlint
.idea/**/sonarlint/

# SonarQube Plugin
# https://plugins.jetbrains.com/plugin/7238-sonarqube-community-plugin
.idea/**/sonarIssues.xml

# Markdown Navigator plugin
# https://plugins.jetbrains.com/plugin/7896-markdown-navigator-enhanced
.idea/**/markdown-navigator.xml
.idea/**/markdown-navigator-enh.xml
.idea/**/markdown-navigator/

# Cache file creation bug
# See https://youtrack.jetbrains.com/issue/JBR-2257
.idea/$CACHE_FILE$

# CodeStream plugin
# https://plugins.jetbrains.com/plugin/12206-codestream
.idea/codestream.xml

# Azure Toolkit for IntelliJ plugin
# https://plugins.jetbrains.com/plugin/8053-azure-toolkit-for-intellij
.idea/**/azureSettings.xml

EOF
}

_create_dependencies_file() {
  _project_dir=$1
  cat << EOF > $_project_dir/$DEPENDENCIES
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
}


_show_welcome() {
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

* jpm new: Criar um novo projeto JPM
* jpm resolve: Instalar os pacotes adicionados em dependencies.txt.
* jpm install: Compilar projeto.
* jpm run: Executar comandos 'resolve', 'install' e identifica automaticamente a class Main e executa a aplicação.
* jpm clean: Remover artefatos de compilação

Exemplo:
$ jpm run

$ New project JPM
$ project name: hello
$ package name: com.github.jpm.hello
$ main class: Hello

$ jpm run

Para mais informações: https://github/danroxha/jpm"
  
}

jpm_new() {
  echo "New project JPM"
  
  echo -ne "$LOG_SUFFIX project name: "
  read project_name
  project_name=$(_lowercase $project_name)
  
  echo -ne "$LOG_SUFFIX package name: "
  read package_name
  package_name=$(_lowercase $package_name)

  echo -ne "$LOG_SUFFIX main class: "
  read main_class

  log "building project $project_name"

  _create_directories $project_name $package_name
  _create_main_class_file $project_name $package_name $main_class
  _create_dependencies_file $project_name
  _create_gitignore $project_name

  wget -q $REMOTE_REPO -P $project_name ?> /dev/null
  log "donwloaded JPM"
  chmod +x $project_name/jpm.sh

  log "path: $WORKDIR/$project_name"
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
