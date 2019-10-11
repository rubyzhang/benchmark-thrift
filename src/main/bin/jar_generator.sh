#!/bin/bash

function gen_classpath(){
    for element in `ls $LIB_DIR`
    do
        jarfile=$LIB_DIR/$element:$jarfile
    done
    jarfile=${jarfile%:*}
}

function getdir(){
    for element in `ls $1`
    do
        dir_or_file=$1"/"$element
        if [ -d $dir_or_file ]
        then
            getdir $dir_or_file
        else
            JAVA_FILES="$dir_or_file $JAVA_FILES"
        fi
    done
}

declare -r HOME_DIR=$(cd $(dirname $0); cd ..; pwd)
declare -r LIB_DIR="${HOME_DIR}/lib/thrift/$1"
declare JAVA_FILES=""

if [[ $3 == "" || $3 != *.jar ]]; then
    echo "输入正确的jar路径，确保以.jar结尾"
    exit 1
fi

if [[ -d classdir ]]; then
    rm -rf classdir
fi
mkdir classdir

gen_classpath $1
getdir $2

echo "version   -> $1"
echo "java path -> $2"
echo "jar path  -> $3"
echo "classpath -> $jarfile"

javac -classpath $jarfile -d classdir $JAVA_FILES > /dev/null

jar -cvf $3 classdir/* > /dev/null
rm -rf classdir




