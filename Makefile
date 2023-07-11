# gdc -static-libphobos source/now/**/*.d cli/now/cli.d -O2 -o dist/now
CC = gdc
DIR = source/now
BASE_CODE = ${DIR}/*.d ${DIR}/system_command/*.d ${DIR}/nodes/*.d ${DIR}/nodes/*/*.d
SOURCE_CODE = ${BASE_CODE} ${DIR}/commands/*.d cli/now/cli.d

dist/now: ${SOURCE_CODE}
	${CC} -static-libphobos $^ \
		-O2 -o dist/now

release: dist/now
	strip $^
	ls -lh dist/

dist/now.debug: ${SOURCE_CODE}
	${CC} -d-debug $^ \
		-L-L\${PWD}/dist -L-lnow \
		-O1 -of dist/now.debug

clean:
	-rm -f dist/now*
	-rm -f build/*
