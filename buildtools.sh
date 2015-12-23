#!/bin/bash
cd `dirname $0`
if [ -z "$UTILITIES" ]; then
	UTILITIES=`pwd`
fi
git clean -x -d -f $UTILITIES
echo -n Building development tools...
GOBIN="$UTILITIES/bin" GOPATH="$UTILITIES/third_party:$UTILITIES" go get -d jehanne/cmd/...
GOBIN="$UTILITIES/bin" GOPATH="$UTILITIES/third_party:$UTILITIES" go install jehanne/cmd/...
GOBIN="$UTILITIES/bin" GOPATH="$UTILITIES/third_party:$UTILITIES" go install github.com/lionkov/ninep/srv/examples/ufs

echo " DONE."
