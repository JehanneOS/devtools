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

(
	cd $UTILITIES/third_party/src/github.com/0intro/drawterm/ && 
	git clean -xdf > ../drawterm.build.log 2>&1 &&
	CONF=unix make > ../drawterm.build.log 2>&1 &&
	mv drawterm $UTILITIES/bin
)
STATUS="$?"
if [ $STATUS -eq "0" ]
then
	rm $UTILITIES/third_party/src/github.com/0intro/drawterm.build.log
	echo "DONE"
else
	echo "FAIL"
	cat $UTILITIES/third_party/src/github.com/0intro/drawterm.build.log
fi

exit $STATUS
