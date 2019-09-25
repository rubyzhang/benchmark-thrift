#!/bin/bash

if [ -f /etc/profile ]; then
    . /etc/profile
fi

if [ -f ~/.bash_profile ]; then
    . ~/.bash_profile
fi

function get_versions(){
  for element in `ls thrift`
  do
    if [[ -d thrift/$element ]]; then
      versions=$element","$versions
    fi
  done
  versions=${versions%,*}
}

function start(){
  BASE_DIR=$(cd $(dirname $0); pwd)
  CLASSPATH=$BASE_DIR/conf:$BASE_DIR/lib/*:$BASE_DIR/thrift/$version/*
  BIN_DIR=$(cd $(dirname $0); pwd)
  JAVA_OPTS="-server -Xmx16G -Xms16G -XX:MaxMetaspaceSize=512M -XX:MetaspaceSize=512M -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled -XX:ErrorFile=$BIN_DIR/hs_err_pid%p.log -Xloggc:$BIN_DIR/gc.log -XX:HeapDumpPath=$BIN_DIR -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+HeapDumpOnOutOfMemoryError"
  PID_FILE="$BIN_DIR/pid"
  if [ ! -s "$PID_FILE" ] || [[ "" == $(cat $PID_FILE) ]] || [ -z "$(ps -eo pid | grep -w $(cat $PID_FILE))" ]; then
    java $JAVA_OPTS -cp $CLASSPATH com.didiglobal.pressir.thrift.Main $* 2>&1
    echo $! > $PID_FILE
  else
    echo "error: application can not start duplicate! running pid=$(cat $PID_FILE)"
    exit 1
  fi
}

function validate(){
  # 获取工具支持的所有thrift version
  get_versions

  # 指定版本是否合规
  . $protocol >/dev/null 2>&1
  if [[ $versions != *$version* ]]; then
    echo error: thrift版本信息必须为"$versions"中的一个!;
    exit 1
  fi

  # 是否指定jar包
  if [[ $classpath == "" || $classpath != *.jar ]]; then
    echo "error: jar file must be prepared!"
    exit 1
  fi
}

function print_usage(){
  file="../resources/usage.txt";
  if [[ ! -f ${file} ]]; then
    file="conf/usage.txt";
  fi
  if [[ ! -f ${file} ]]; then
    echo "hello"
    return;
  fi

  while IFS= read -r line || [[ -n ${line} ]]; do
    printf '%s\n' "$line"
  done < "$file"
}

function print_tool_version(){
  file="../resources/thrift-benchmark.properties"

  while IFS='=' read -r key value|| [[ -n ${key} ]]; do
    key=$(echo $key | tr '.' '_')
    eval ${key}=\${value}
  done < "$file"
  echo "This is ${project_name}, version ${project_version}"
}

# 设置默认值
name="bt"
params=""
types=0
while getopts ":n:c:D:q:p:d:hv:" opt
do
  case "$opt" in
    c)
      concurrency="$OPTARG"
      types=$[types+1]
      params="-c $concurrency $params "
      ;;
    D)
      duration="$OPTARG"
      params="-D $duration $params "
      ;;
    q)
      throughput="$OPTARG"
      types=$[types+1]
      params="-q $throughput $params "
      ;;
    p)
      protocol="$OPTARG"
      params="-p $protocol $params "
      validate
      ;;
    d)
      param="$OPTARG"
      params="-d $param $params "
      ;;
    h)
      print_usage
      exit 1
      ;;
    v)
      print_tool_version
      exit 1
      ;;
    *)
      echo "${name}: illegal option ${OPTARG}"
      print_usage
      exit 1
      ;;
    esac
done
if [[ ${types} == 2 ]];  then
  echo "${name}: only one of -c or -q could be specified"
  print_usage
  exit 1
fi
if [[ $protocol == "" ]]; then
  echo "${name}: please use -p to specify thrift conf file"
  print_usage
  exit 1
fi
if [[ ${duration} == "" ]]; then
  params="$params -D 60s"
fi
if [ $types == 0 ]; then
  params="$params -c 1"
fi

shift $(($OPTIND - 1))
if [[ $1 == "" ]];  then
  echo "${name}: please enter thrift url"
  print_usage
  exit 1
fi
params="$params -u $1"

start $params

