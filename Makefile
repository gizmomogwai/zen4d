all: zend

zend: zend.d pc/parser.d util/Callable.d
	dmd -unittest zend.d pc/parser.d util/Callable.d

clean:
	find . -name "*.o" -delete
	rm -rf zend
