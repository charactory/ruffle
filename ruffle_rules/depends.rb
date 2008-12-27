# 
# ruffle - a rubyfied Pacman package analyzer
# Copyright (C) 2008 Colin Gan <laxatives@gmail.com>
# 
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
#require 'find'
#require 'pathname'
require 'pp'
require '/home/colin/projects/ruffle/ruffle_rules/pacman'

module Depends
  
  def Depends.analyze(file_list, package_path, pkginfo)
    @libcache = {'x86-64' => {}, 'i686' => {}}
    @depends_files = {}  #files that the package needs
    @other_depends_files = {} #files that the package needs, arranged according to what packages owns them in pacman db
    @pkginfo_depends = {} #files that the dependencies of the package needs

    @script_depends = {'ruby' => [], 'perl' => [], 'tk' => [], 'wish' => [], 'expect' => [], 'python' => [], 'bash' => []}

    @smart_depends = []
    @smart_provides = []

    @pacman_db = '/var/lib/pacman/local'

    Depends.fill_libcache
    Depends.get_files(file_list)
    Depends.extract(package_path)
    Depends.scan_libs
    Depends.find_depends
    #Depends.find_pkginfo_depends(pkginfo)
    covered_depends = []
    pkg_covered = []
    #odf = []
    #include covered deps and optdeps from pkginfo
    #this dependlist does not format its lines
    dependlist = []
    dependlist = pkginfo[:depend].map {|x| x.split('<')[0].split('>')[0].split('=')[0].to_s} if not pkginfo[:depend].nil?
    dependlist.delete(pkginfo[:pkgname].join)
    
    Depends.getcovered(dependlist, pkg_covered) if not dependlist.empty?

    optdependlist = []
    optdependlist = pkginfo[:optdepend].map {|x| x.split('<')[0].split('>')[0].split('=')[0].to_s} if not pkginfo[:optdepend].nil?
    Depends.getcovered(optdependlist, pkg_covered) if not optdependlist.empty?

    #include dependencies from depends list in pkginfo
    #
    #@other_depends_files.each_key {|x| odf << x}
    Depends.getcovered(@other_depends_files.keys, covered_depends)

    #TODO: fix script dependencies
    #pass found script dependencies through covered_depends
    found_scripts = []
    @script_depends.each_key do |script|
      if not @script_depends[script].size
        found_scripts << script
      end
    end

    Depends.getcovered(found_scripts, covered_depends)


    #pp @other_depends_files 
    puts pkginfo[:pkgname]
    @other_depends_files.delete(pkginfo[:pkgname].join)
    #Depends.getcovered(@depends_files.keys, covered_depends)
    #@smart_depends = odf - covered_depends
    @other_depends_files.keys.each do |x|
    if not covered_depends.include?(x)
      (@smart_depends << x)
    end
    end

    @other_depends_files.each_pair do |key, value|
      d = value.keys.flatten
      puts "File #{d.inspect} link-level dependence with #{key}"
    end
    covered_depends.uniq! 
    covered_depends.sort.each {|x| puts "I: Dependency covered by dependencies from link dependence (#{x})"}
    puts 'covereddep'
    pp covered_depends

    smart_provides = []
    Depends.getprovides(@other_depends_files.keys, smart_provides)

    @smart_depends.delete(pkginfo[:pkgname].join)
   
    all_depends = (dependlist + optdependlist).uniq
    pp @smart_depends
    @smart_depends.each do |x|
      if not all_depends.include?(x)
        #pp pkginfo[:pkgname]
        #pp x
        puts "W: Dependency detected and not included: #{x} from files #{@other_depends_files[x].values.flatten.inspect}"
        true
      end
    end

    dependlist.each do |x|
      if covered_depends.include?(x) and @other_depends_files.keys.include?(x)
        puts "W: Dependency included but already satisfied: (#{x})"
      elsif not @smart_depends.include?(x) and not @smart_provides.include?(x)
        puts "W: Dependency included and not needed: (#{x})"
      end
    end

    puts "I: Depends as ruffle sees them: depends=(#{@smart_depends})"

  end

  def Depends.get_files(file_list)
    file_list.each do |file|
      if file[0].start_with?("-") # is this a file?
        if file[0][3..3] == "x" or file[5] =~ /(\.so?\.?)+/ # is this an executable/shared library?
          #I am now putting file[5] in a hash as a key with an array as a value
          @depends_files[file[5]] = []
        end
      end
    end
    #@depends_files.each {|x| puts x}
    #puts "Hash length: #{@depends_files.keys.length}"
  end

  def Depends.extract(package_path)
    Open3.popen3("tar -C #{SANDBOX} -xf #{package_path} #{@depends_files.keys.join(" ")}") do |stdin, stdout, stderr|
      error = stderr.gets
      if not error.nil?

        if error =~ /tar: (.*): Cannot open: No such file or directory/
          puts "File does not exist"
        elsif error =~ /tar: (.*): Not found in archive/
          puts "Package does not have a .PKGINFO file!"
        else
          puts error
        end

      else
        puts "Depends placeholder"
      end
    end
  end

  def Depends.scan_libs(depends_files=@depends_files, script_depends=@script_depends, libcache=@libcache)
    #puts "Calling scan libs"
    depends_files.each_pair do |file, libs| #libs array is initially empty
      raw_output = ""
      raw_error = ""

      Open3.popen3("readelf -d #{File.join(SANDBOX,file)}") do |stdin, stdout, stderr|
        raw_output = stdout.read
        raw_error = stderr.read if not stderr.nil?
      end
      
      #puts @raw_error
      if not raw_error.start_with?("readelf")
        raw_output.split("\n").each do |line|
          bitstring = line.split(" ")[0]
          if line =~ /Shared library: \[(.*)\]/
            if not bitstring.nil? and bitstring.length > 7 
              if bitstring.length > 10
                libs << libcache['x86-64'][line.scan(/Shared library: \[(.*)\]/)[0].to_s]
              else
                key = line.scan(/Shared library: \[(.*)\]/)[0].to_s
                libs << libcache['i686'][key]
              end
            end
          end
        end

      else

        #this is where we test for scripts
        File.open(File.join(SANDBOX,file)).each_line do |line|

          script_depends.each_key do |lang|
            if line =~ /#!.*#{lang}/
              #puts "Is a Ruby script"
              puts "Is a #{lang} script"
              script_depends[lang] << file
              break true
            end
          end

        end

      end
    end

    #print out what libraries were obtained
    #depends_files.each_pair do |f,libs|
    #  pp "#{f}: #{libs.join(" ")}"
    #end

  end


  def Depends.fill_libcache(libcache=@libcache)
    #ldconfig allows us to find the paths to libraries

    raw_output = ""
    Open3.popen3("ldconfig -p") do |stdin, stdout, stderr|
      raw_output = stdout.read
      raw_error = stderr.read if not stderr.nil?
    end

    #hours of debugging went into this
    raw_output.split("\n").each do |line|
      ld_array = line.scan(/\s*(.*) \((.*)\) => (.*)/)
      if not ld_array[0].nil?
        if ld_array[0][1].start_with?('libc6,x86-64')
          libcache['x86-64'][ld_array[0][1]] = ld_array[0][3]
        else
          libcache['i686'][ld_array[0][0]] = ld_array[0][2]
        end
      end
    end

  end

  def Depends.find_depends
    Dir['/var/lib/pacman/local/*'].each do |folder|

      files_path = File.join(folder, "files")
      files_contents = []

      File.open(files_path).each_line do |line|
        files_contents << '/' + line.chomp! #forward slash added to front
      end

      @depends_files.each_pair do |actualdep, libarray|
        # a very magical line
        depends_array = files_contents & libarray
        dependency_name = File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0]
        if not depends_array.empty? 
          if not @other_depends_files.key?(dependency_name)
            @other_depends_files[dependency_name] = {}
          end

          # dependency_name is the name of the folder/package which contains the shared dependency
          # actualdep is the file belonging to the ruffled package which requires that shared library
          
          @other_depends_files[dependency_name][actualdep] = depends_array
        end
      end
    end

  end

  def Depends.find_pkginfo_depends(pkginfo)

    files_contents = {}
    pacman_packages = Dir.glob("#{@pacman_db}/*") 
    #fills @pkginfo_depends with names of dependencies from .PKGINFO
    pkginfo.each_pair do |key,value|
      if key == :depend
        #need to strip the <= >= signs
        #value.map! {|x| x.to_s.scan(/([^<>=]*)[><=]*(.*)/)[0].to_s}
        #value.each {|x| @pkginfo_depends[x] = [] }
        value.each {|x| @pkginfo_depends[x.to_s.scan(/([^<>=]*)[><=]*(.*)/)[0].to_s] = [] }
      end
    end

    pacman_packages.each do |folder|
      @pkginfo_depends.each_key do |dep|
        #puts "#{File.basename(folder)}: #{dep}"
        #if File.basename(folder).start_with?(dep) (/(#{dep})-([^-]*)-([^-]*)/) 
        if File.basename(folder) =~ /(#{dep})-([^-]*)-([^-]*)/
        #if folder =~ (/#{dep}[.\d-]+/) #this regexp needs to be changed! ><= not used
          files_path = File.expand_path(File.join(folder, "files"))
          #if File.exist?(files_path)
            File.open(files_path) do |file|
              #gets all files belonging to the dependency
              file.each_line {|line| @pkginfo_depends[dep] << "/" + line.chomp!}
              #might want to delete %FILES% somewhere here
            #end
          end
        end
       #something... 
      end
    end
    
    #this block prints out the files owned by the dependencies stated in .PKGINFO
    #@pkginfo_depends.each_pair do |depname, deps|
      #puts deps.length
    #  puts "#{depname}: #{deps.join(" ")}"
    #end
    
  end

  def Depends.getcovered(deplist, covered_deps, *current)
    #accepts two arrays as arguments, one of deps to check and the other is an array to fill with covered dependencies found by this method
    full_package_names = []
=begin
    #for each dependency listed that isn't already covered...
    deplist.each do |pkgname|
      Dir.glob("#{@pacman_db}/*").each do |folder|
        #if File.basename(folder).start_with?(pkgname)  #problematic because 'sh' matches a lot of things
        #if the folder name matches the pkgname
        if File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0] == pkgname
          full_package_names << folder #contains full path
        end
      end
    end
=end
    full_package_names = Pacman.load_db(deplist)
    
    pp full_package_names
    #open the depends file and get all dependencies it specifies and sticks it in covered_deps
    full_package_names.each do |folder|
      package = Pacman.new(File.join(folder, 'depends'))
      package.load
      package.depends.each do |dep|
        if not covered_deps.include?(dep) and not package.depends.empty? #watch upcase
          puts "Currently examined dep: #{dep}"
          puts package.depends.inspect
          #puts "Covered depedencies: #{(dep.to_a + covered_deps).join(" ")}"
          covered_deps << dep 
          Depends.getcovered([dep], covered_deps)  #apply this function to the dep too!
        end
      end
    end

  end


  def Depends.getprovides(deplist, smart_provides)
    #get all the provides of all dependencies listed
    full_package_names = []

    deplist.each do |pkgname|
      Dir.glob("#{@pacman_db}/*").each do |folder|
        #if File.basename(folder).start_with?(pkgname)  #problematic because 'sh' matches a lot of things
        #if the folder name matches the pkgname
        if File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0] == pkgname
          full_package_names << folder #contains full path
        end
      end
    end
    
    full_package_names.each do |folder|
      package = Pacman.new(File.join(folder, 'depends'))
      package.load
      package.provides.each do |prov|
        if not covered_deps.include?(dep) and not package.provides.empty?
          smart_provides << prov
        end
      end
    end

  end



end
