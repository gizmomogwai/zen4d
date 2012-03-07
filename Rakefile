SOURCES = ['submodules/combinators_for_d/pc/parser.d', 'zend.d']

desc 'builds all'
task :default => [:binaries, :docs] do
end

desc 'builds test and release executables'
task :binaries => ['build/zend', 'build/zend.test']

desc 'release-executable'
file 'build/zend' => SOURCES do
  sh "dmd -odbuild  -ofbuild/zend #{SOURCES.join(' ')}"
end

desc 'test-executable'
file 'build/zend.test' => SOURCES do
  sh "dmd -unittest -odbuild -ofbuild/zend.test #{SOURCES.join(' ')}"
end

task :test => 'build/zend.test' do |t|
  sh t.prerequisites.first
end

task :docs do
  sh 'doxygen'
end
task :clean do
  sh 'rm -rf build'
end
