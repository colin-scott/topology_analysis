
LIBTOOL = @ /bin/sh ../artsclasses/libtool

readoutfile: readoutfile_no_ntoa.cc readoutfile_no_ntoa.o readoutfile.cc readoutfile.o
	g++ -o readoutfile -g readoutfile.o
	g++ -o readoutfile_no_ntoa -g readoutfile_no_ntoa.o

clean:
		rm -f readoutfile readoutfile_no_ntoa *.o
