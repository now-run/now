dist/now: dist/libnow.a
	ldc2 \
		-od=build -oq \
		cli/source/now/app.d \
		-I=source -I=cli/source \
		-L-Ldist -L-lnow \
		--O2 -of=dist/now

dist/now.debug: dist/libnow.debug.a
	ldc2 --d-debug \
		-od=build -oq \
		cli/source/now/app.d \
		-I=source -I=cli/source \
		-L-Ldist -L-lnow.debug \
		--O1 -of=dist/now.debug

dist/libnow.a:
	ldc2 --lib \
		-oq -od=build \
		source/now/*.d source/now/commands/*.d \
		source/now/nodes/*.d source/now/nodes/*/*.d source/now/nodes/*/*/*.d \
		-I source \
		--O2 -of=dist/libnow.a

dist/libnow.debug.a:
	ldc2 --lib --d-debug \
		-oq -od=build \
		source/now/*.d source/now/commands/*.d \
		source/now/nodes/*.d source/now/nodes/*/*.d source/now/nodes/*/*/*.d \
		-I source \
		--O1 -of=dist/libnow.debug.a

clean:
	-rm -f dist/libnow.*
	-rm -f build/*
