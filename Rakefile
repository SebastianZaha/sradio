require './tasks.rb'

build = SradioBuild.new('sradio', '0.1.1') do |b|

  b.author = 'Sebastian Zaha'
  b.email  = 'grimdonkey@gmail.com'
  b.summary = 'Simple online radio player.'

  b.files.source = FileList['lib/**/*.rb', 'bin/sradio']
  b.files.data = FileList['share/applications/*.*', 'share/doc/sradio/*', 'share/sradio/**/*.*']
  b.files.icons = FileList['share/icons/**/*.png']

  b.debinstall.staging_dir = 'debian/tmp'
  b.debinstall.staging_dir_src = "debian/src/sradio-#{b.version}"



file 'lib/sradio/config.rb' => ['Rakefile'] do |f|
  build.generate f.name do
    <<EOS
module Cfg
  HOME = ENV['HOME'] + '/.sradio'
  DEBUG = true
  DATA = '#{build.install.prefix}/share/#{build.name}'
end
EOS
  end
end

end


desc "Generate ruby files needed for the installation"
autogenerated_files = ['lib/sradio/config.rb']
task :autogen => autogenerated_files

task :autogen_clobber do |t|
  autogenerated_files.each do |file|
    FileUtils.rm_f(file)
  end
end
task :clobber => [:autogen_clobber]

task :build => [:autogen]
task :default => [:build]

task :pre_install => [:build]

task :update_icon_cache do
  system("gtk-update-icon-cache -f -t /usr/share/icons/hicolor") # HACK
end

task :post_install => [:update_icon_cache]
