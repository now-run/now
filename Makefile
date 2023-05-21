CC = ldc2
DIR = source/now
BASE_CODE = ${DIR}/*.d ${DIR}/system_command/*.d ${DIR}/nodes/*.d ${DIR}/nodes/*/*.d
SOURCE_CODE = ${BASE_CODE} ${DIR}/commands/*.d cli/now/cli.d

dist/now: ${SOURCE_CODE}
	${CC} \
		$^ \
		-Isource \
		-O2 -of=dist/now

release: dist/now
	strip $^
	ls -lh dist/

dist/now.debug: ${SOURCE_CODE}
	${CC} -d-debug \
		$^ \
		-Isource \
		-O1 -of=dist/now.debug

clean:
	-rm -f dist/now*
	-rm -f build/*
