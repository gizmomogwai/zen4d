all: zend

zend: zend.d pc/parser.d util/Callable.d
	dmd -D -unittest zend.d pc/parser.d util/Callable.d

clean:
	find . -name "*.o" -delete
	find . -name "*.html" -delete
	rm -rf zend
