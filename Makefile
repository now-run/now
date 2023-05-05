DIR = source/now
BASE_CODE = ${DIR}/*.d ${DIR}/system_command/*.d ${DIR}/nodes/*.d ${DIR}/nodes/*/*.d
SOURCE_CODE = ${BASE_CODE} ${DIR}/commands/*.d

dist/now: ${SOURCE_CODE}
	gdc \
		-static-libphobos -static-libgcc \
		$^ \
		-Isource \
		-O2 -o dist/now

release: dist/now
	strip $^
	ls -l dist/

dist/now.debug: ${SOURCE_CODE}
	gdc -fdebug \
		-static-libphobos -static-libgcc \
		$^ \
		-Isource \
		-O1 -o dist/now.debug


examples/packages/now/hello.now.so: ${BASE_CODE}
	gdc -fPIC -shared \
		-static-libphobos -static-libgcc \
		examples/packages/now_hello.d \
		$^ \
		-Isource \
		-O2 -o examples/packages/now/hello.now.so

clean:
	-rm -f dist/libnow.* dist/now*
	-rm -f build/*
