require 'rake/clean'
require 'rake/rdoctask'
require 'rake/packagetask'

task :default => :doc do
  sh 'rake package'
  sh 'rake web'
end

task :web do
  sh 'rsync', '--rsh=ssh', '-av', '--delete', *(FileList['pkg/*'] << "#{ENV['UC']}:web/pub/wmii")
end

Rake::RDocTask.new(:doc) do |t|
  t.rdoc_files.include('wmii*', '*.rb')
  t.rdoc_dir = 'doc'
  t.main = 'Wmii'
end

Rake::PackageTask.new('snk_wmiirc', :noversion) do |p|
  p.need_tar_gz = true
  p.package_files.include('COPYING', 'wmii*', '*.rb', 'ruby-ixp/**/*', 'doc/**/*')
end
