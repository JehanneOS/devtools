#!/bin/bash
cd `dirname $0`
if [ -z "$UTILITIES" ]; then
	UTILITIES=`pwd`
fi
git clean -x -d -f $UTILITIES
echo -n Building development tools...
(
	GOBIN="$UTILITIES/bin" GOPATH="$UTILITIES/third_party:$UTILITIES" go get -d jehanne/cmd/... &&
	GOBIN="$UTILITIES/bin" GOPATH="$UTILITIES/third_party:$UTILITIES" go install jehanne/cmd/... &&
	GOBIN="$UTILITIES/bin" GOPATH="$UTILITIES/third_party:$UTILITIES" go install github.com/lionkov/ninep/srv/examples/ufs
)
STATUS="$?"
if [ ! $STATUS -eq "0" ]
then
        echo "FAIL"
	exit $STATUS
fi

# Drawterm
(
	cd $UTILITIES/third_party/src/github.com/0intro/drawterm/ && 
	git clean -xdf > ../drawterm.build.log 2>&1 &&
	CONF=unix make >> ../drawterm.build.log 2>&1 &&
	mv drawterm $UTILITIES/bin
)
STATUS="$?"
if [ $STATUS -eq "0" ]
then
	rm $UTILITIES/third_party/src/github.com/0intro/drawterm.build.log
else
	echo "FAIL"
	cat $UTILITIES/third_party/src/github.com/0intro/drawterm.build.log
	exit $STATUS
fi

# Plan9 compilers
(
        cd $UTILITIES/third_party/src/github.com/JehanneOS/devtools-kencc && 
	./configure > ../kencc.build.log 2>&1 &&
	. ./env &&
	export >> ../kencc.build.log 2>&1 &&
	mk >> ../kencc.build.log 2>&1 &&
	mk install 2>&1 >> ../kencc.build.log
)
STATUS="$?"
if [ $STATUS -eq "0" ]
then
        rm $UTILITIES/third_party/src/github.com/JehanneOS/kencc.build.log
        echo "DONE"
else
        echo "FAIL"
        cat $UTILITIES/third_party/src/github.com/JehanneOS/kencc.build.log
fi

exit $STATUS
