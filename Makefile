dist/now:
	gdc \
		-static-libphobos -static-libgcc \
		cli/source/now/app.d \
		source/now/*.d source/now/commands/*.d source/now/system_command/* \
		source/now/nodes/*.d source/now/nodes/*/*.d source/now/nodes/*/*/*.d \
		-Isource -Icli/source \
		-O3 -o dist/now

release: dist/now
	strip dist/now

dist/now.debug:
	gdc -fdebug \
		-static-libphobos -static-libgcc \
		cli/source/now/app.d \
		source/now/*.d source/now/commands/*.d source/now/system_command/* \
		source/now/nodes/*.d source/now/nodes/*/*.d source/now/nodes/*/*/*.d \
		-Isource -Icli/source \
		-O1 -o dist/now


clean:
	-rm -f dist/libnow.* dist/now*
	-rm -f build/*
