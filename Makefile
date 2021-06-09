libtil_exec.so:
	dub build --compiler=ldc2

run: libtil_exec.so
	dub run til:run -b release --compiler=ldc2 -- test.til

debug: libtil_exec.so
	dub run til:run -b debug --compiler=ldc2 -- test.til
