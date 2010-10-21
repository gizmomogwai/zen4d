all: zend

%.o: %.d
	dmd -c $<

zend: zend.o
	dmd $^

clean:
	rm -rf *.o main