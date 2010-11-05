all: zend

zend: zend.d pc/parser.d
	dmd -unittest zend.d pc/parser.d

clean:
	find . -name "*.o" -delete
	rm -rf zend
