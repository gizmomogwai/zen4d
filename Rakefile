SOURCES = ['submodules/combinators_for_d/pc/parser.d', 'zend.d']


task :default => ['build/zend', 'build/zend.test', :docs] do
end

task 'build/zend' => SOURCES do
  sh "dmd -D -odbuild  -ofbuild/zend #{SOURCES.join(' ')}"
end

task 'build/zend.test' => SOURCES do
  sh "dmd -D -unittest -odbuild -ofbuild/zend.test #{SOURCES.join(' ')}"
end

task :docs do
  sh 'doxygen'
end
task :clean do
  sh 'rm -rf build'
end
