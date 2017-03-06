task :default => [:test, :build]

desc 'test'
task :test do
  sh "dub test"
end

desc 'build'
task :build do
  sh "dub build"
end
