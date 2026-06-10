CC = ldc2
DIR = source/now
BASE_CODE = ${DIR}/system_command/*.d ${DIR}/task/*.d ${DIR}/nodes/*/*.d ${DIR}/nodes/*.d ${DIR}/*.d
SOURCE_CODE = ${BASE_CODE} ${DIR}/commands/*.d
TARGET = release
IMPORTS = -Isource -d-version=${TARGET}

dist/${TARGET}/lang.o: ${SOURCE_CODE}
	${CC} -c $^ \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/cli.o: dist/${TARGET}/lang.o source/now/cli/package.d
	${CC} -c $^ \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/main.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.cmd: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/cmd.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.dump: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/dump.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.stdin: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/stdin.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.repl: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/repl.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.lp: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/lp.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.watch: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/watch.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.http: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/http_server.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.jsonrpc: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/jsonrpc_server.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

dist/${TARGET}/now.mcp: dist/${TARGET}/cli.o dist/${TARGET}/lang.o
	${CC} $^ source/now/cli/mcp_server.d \
	${IMPORTS} \
	--checkaction=halt \
	-od=build --oq \
	-O2 -of $@

release: _all
	strip dist/${TARGET}/now*
	ls -lh dist/${TARGET}

_all: dist/${TARGET}/now dist/${TARGET}/now.cmd dist/${TARGET}/now.repl dist/${TARGET}/now.dump dist/${TARGET}/now.lp dist/${TARGET}/now.watch

all: _all
	ls -lh dist/${TARGET}

gnu-standalone: ${SOURCE_CODE}
	gdc $^ \
		-frelease -O3 \
		-static-libphobos \
		-o dist/now-$$( \
			git describe --tags $$( \
				git rev-list --tags --max-count=1 \
			))-$$(uname -m)-glibc-linux
	strip dist/now-*

musl-standalone: ${SOURCE_CODE}
	gdc $^ \
		-frelease -O3 \
		-static-libphobos \
		-o dist/now-$$( \
			git describe --tags $$( \
				git rev-list --tags --max-count=1 \
			))-$$(uname -m)-musl-linux
	strip dist/now-*

macos-standalone: ${SOURCE_CODE}
	${CC} $^ \
		--checkaction=halt \
		-od=build --oq \
		-O3 -of dist/now-$$( \
			git describe --tags $$( \
				git rev-list --tags --max-count=1 \
			))-$$(uname -m)-$$(uname -o | sed 's:/:-:g' | tr A-Z a-z)
	strip dist/now-*

clean:
	-rm -f dist/release/*
	-rm -f dist/debug/*

alpine:
	podman run --rm -v $$PWD:/opt/now -it alpine sh -c 'apk add make gcc-gdc git && cd /opt/now && make musl-standalone'

ubuntu:
	podman run --rm -v $$PWD:/opt/now -it ubuntu:24.04 bash -c 'apt-get update && apt-get upgrade -y && apt-get install -y gdc make git && cd /opt/now && make gnu-standalone'
