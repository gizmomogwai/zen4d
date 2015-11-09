SOURCES = Dir.glob('submodules/combinators_for_d/pc/*.d') + ['zend.d']

desc 'builds all'
task :default => [:binaries] do
end

desc 'builds test and release executables'
task :binaries => ['out/zend', 'out/zend.test']

desc 'release-executable'
file 'out/zend' => SOURCES do
  sh "dmd -odout  -ofout/zend #{SOURCES.join(' ')}"
end

desc 'test-executable'
file 'out/zend.test' => SOURCES do
  sh "dmd -D -Ddout/docs/ddoc -unittest -odout -ofout/zend.test #{SOURCES.join(' ')}"
end

task :test => 'out/zend.test' do |t|
  sh t.prerequisites.first
end

task :clean do
  sh 'rm -rf out'
end
