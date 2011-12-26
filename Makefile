SOURCES=submodules/combinators_for_d/pc/parser.d zend.d

all: zend zend_release
	./zend

zend: $(SOURCES)
	dmd -D -unittest -odout_unittest -of$@ $^

zend_release: $(SOURCES)
	dmd -D -odout_release -of$@ $^

docs:
	doxygen

clean:
	find . -name "*.o" -delete
	find . -name "*.html" -delete
	rm -rf zend zend_release
	rm -rf out_release
	rm -rf out_unittest
