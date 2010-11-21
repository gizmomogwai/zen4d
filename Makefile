SOURCES=zend.d pc/parser.d util/Callable.d

all: zend zend_release

zend: $(SOURCES)
	dmd -D -unittest -odout_unittest -of$@ $^

zend_release: $(SOURCES)
	dmd -D -odout_release -of$@ $^

clean:
	find . -name "*.o" -delete
	find . -name "*.html" -delete
	rm -rf zend
