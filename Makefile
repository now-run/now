CC = ldc2
DIR = source/now
BASE_CODE = ${DIR}/*.d ${DIR}/system_command/*.d ${DIR}/task/*.d ${DIR}/nodes/*.d ${DIR}/nodes/*/*.d
SOURCE_CODE = ${BASE_CODE} ${DIR}/commands/*.d cli/now/*.d

dist/now: ${SOURCE_CODE}
	${CC} $^ \
		--checkaction=halt \
		-od=build --oq \
		-O2 -of dist/now

release: dist/now
	strip $^
	ls -lh dist/

dist/now.debug: ${SOURCE_CODE}
	${CC} --d-debug $^ \
		-O1 -of dist/now.debug

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
	-rm -f dist/now*

alpine:
	podman run --rm -v $$PWD:/opt/now -it alpine sh -c 'apk add make gcc-gdc git && cd /opt/now && make musl-standalone'

ubuntu:
	podman run --rm -v $$PWD:/opt/now -it ubuntu:24.04 bash -c 'apt-get update && apt-get upgrade -y && apt-get install -y gdc make git && cd /opt/now && make gnu-standalone'
