#!/bin/bash

BUILD_GO_TOOLS=true
BUILD_DRAWTERM=true

while test $# -gt 0
do
    case "$1" in
        --help) echo "$0 [ --no-tools | --no-drawterm | --help ]"
		exit 0
            ;;
        --no-tools) BUILD_GO_TOOLS=false
            ;;
        --no-drawterm) BUILD_DRAWTERM=false
            ;;
        --*) echo "bad option $1" && exit 1
            ;;
        *) echo "unexpected argument $1" && exit 1
            ;;
    esac
    shift
done

cd `dirname $0`
if [ -z "$UTILITIES" ]; then
	UTILITIES=`pwd`
fi
if [ "$BUILD_GO_TOOLS$BUILD_DRAWTERM" = "truetrue" ]; then
	git clean -x -d -f $UTILITIES/bin
fi
if [ "$BUILD_GO_TOOLS" = "true" ]; then
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
	else
		echo "done."
	fi
fi

if [ "$BUILD_DRAWTERM" = "true" ]; then
	echo -n Building drawterm...
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
		echo "done."
	else
		echo "FAIL"
		cat $UTILITIES/third_party/src/github.com/0intro/drawterm.build.log
		exit $STATUS
	fi
fi
exit $STATUS
