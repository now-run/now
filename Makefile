CC = ldc
DIR = source/now
BASE_CODE = ${DIR}/*.d ${DIR}/system_command/*.d ${DIR}/nodes/*.d ${DIR}/nodes/*/*.d
SOURCE_CODE = ${BASE_CODE} ${DIR}/commands/*.d

dist/now: ${SOURCE_CODE}
	${CC} \
		$^ \
		-Isource \
		-O2 -o dist/now

release: dist/now
	strip $^
	ls -lh dist/

dist/now.debug: ${SOURCE_CODE}
	${CC} -fdebug \
		$^ \
		-Isource \
		-O1 -o dist/now.debug

clean:
	-rm -f dist/libnow.* dist/now*
	-rm -f build/*
