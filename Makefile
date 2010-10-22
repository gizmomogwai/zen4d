all: zend

%.o: %.d
	dmd -unittest -c $<

zend: zend.o
	dmd $^

clean:
	rm -rf *.o main