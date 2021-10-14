#!/bin/bash


THIS_DIR=$(pwd)
mkdir -p $HOME/io_uring-logs/logs
touch $HOME/io_uring-logs/results.csv
OUT_DIR=$HOME/io_uring-logs
LOGS_DIR=$OUT_DIR/logs
BEGIN_WITH=64
MAX_WIDTH=16384
STEP=2

echo "Starting tests"

echo "version;width;size;orig_avg;orig_std" > $OUT_DIR/results.csv

# set libtiff-original
git checkout 1e45791e6b5c4f646a89ca9145f19bb8c45c9422
./autogen.sh > /dev/null
./configure > /dev/null
make > /dev/null
sudo make install > /dev/null

# compile generator and compactador
git clone https://github.com/simsab-ufcg/TiffUtils/ $HOME/TiffUtils
cd $HOME/TiffUtils/functions

g++ tifGenerator.cpp -l:libtiff.a -lz -luring -o generator > /dev/null
for ((i=$BEGIN_WITH;i<=$MAX_WIDTH;i*=$STEP)); do
	for ((b=1;b<=25;b+=1)); do
		echo "test $i/$MAX_WIDTH ($b/25) (original)"
		sudo perf stat -r 1 -d -o "$LOGS_DIR/${i}px-original.log" ./generator $i $HOME/io_uring-logs/random1024.tiff -R
		IMG_SIZE=$(ls -sh $HOME/io_uring-logs/random1024.tiff | cut -d' ' -f1)
		AVG=$(cat "$LOGS_DIR/${i}px-original.log" | awk 'NR == 22 { print $1 }')
		STD=$(cat "$LOGS_DIR/${i}px-original.log" | awk 'NR == 22 { print $3 }')
		echo "original;$i;$IMG_SIZE;$AVG;$STD" >> $OUT_DIR/results.csv
	done
done

echo "tests with sync version done"

cd $THIS_DIR
git checkout master
./autogen.sh > /dev/null
./configure > /dev/null
make > /dev/null
sudo make install > /dev/null
cd $HOME_DIR/TiffUtils/functions


g++ tifGenerator.cpp -l:libtiff.a -lz -luring -o generator > /dev/null
for ((i=$BEGIN_WITH;i<=$MAX_WIDTH;i*=$STEP)); do
	for ((b=1;b<=25;b+=1)); do
		echo "test $i/$MAX_WIDTH ($b/25) (modified)"
		sudo perf stat -r 1 -d -o "$LOGS_DIR/${i}px-async.log" ./generator $i $HOME/io_uring-logs/random1024.tiff -R
		IMG_SIZE=$(ls -sh $HOME/io_uring-logs/random1024.tiff | cut -d' ' -f1)
		AVG=$(cat "$LOGS_DIR/${i}px-async.log" | awk 'NR == 22 { print $1 }')
		STD=$(cat "$LOGS_DIR/${i}px-async.log" | awk 'NR == 22 { print $3 }')
		echo "modified;$i;$IMG_SIZE;$AVG;$STD" >> $OUT_DIR/results.csv
	done
done

echo "tests with io_uring version finished"

sed -i 's/\,/\./g' $OUT_DIR/results.csv
sed -i 's/\;/\,/g' $OUT_DIR/results.csv
echo "FINISHED!"
