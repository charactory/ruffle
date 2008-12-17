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
require 'find'
require 'pathname'
require 'time'
require 'pp'

module Depends
  
  def Depends.analyze(file_list, package_path, sandbox, pkginfo)
    @libcache = {'x86-64' => {}, 'i686' => {}}
    @depends_files = {}  #files that the package needs
    @other_depends_files = {} #files that the package needs, arranged according to what packages owns them in pacman db
    @pkginfo_depends = {} #files that the dependencies of the package needs

    Depends.fill_libcache
    Depends.get_files(file_list)
    Depends.extract(sandbox,package_path)
    Depends.scan_libs(sandbox)
    Depends.find_depends
    Depends.find_pkginfo_depends(pkginfo)

  end

  private

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
    puts "Hash length: #{@depends_files.keys.length}"
  end

  def Depends.extract(sandbox,package_path)
    #puts "tar -C #{sandbox} -xf #{package_path} #{@depends_files.keys.join(" ")}"
    Open3.popen3("tar -C #{sandbox} -xf #{package_path} #{@depends_files.keys.join(" ")}") do |stdin, stdout, stderr|
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

  def Depends.scan_libs(sandbox)
    puts "Calling scan libs"
    @depends_files.each_pair do |file, libs|
      @raw_output = ""
      #puts libs
      puts file

      Open3.popen3("readelf -d #{File.join(sandbox,file)}") do |stdin, stdout, stderr|
        @raw_output = stdout.read
        @raw_error = stderr.read if not stderr.nil?
      end
      
      #puts @raw_error
      #puts "readelf -d #{File.join(sandbox,file)}"
      #if not @raw_output.start_with?("readelf") or not @raw_output.nil?
      #if not @raw_output.start_with?("readelf") and @raw_error.nil?
      if not @raw_error.start_with?("readelf")
        @raw_output.split("\n").each do |line|
          bitstring = line.split(" ")[0]
          if line =~ /Shared library: \[(.*)\]/
            if not bitstring.nil? and bitstring.length > 7 
              #libs << (bitstring.length > 10 ? "x86-64" : "i686")
              if bitstring.length > 10
                libs << @libcache['x86-64'][line.scan(/Shared library: \[(.*)\]/)]
                puts @libcache['x86-64'][line.scan(/Shared library: \[(.*)\]/)].class
              else
                #puts @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)[0]]
                #if not @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)].nil?
                  key = line.scan(/Shared library: \[(.*)\]/)[0].to_s
                  #puts @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)[0]]
                  libs << @libcache['i686'][key]
                  #puts @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)[0]]
                  #puts @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)]
                  #puts line.scan(/Shared library: \[(.*)\]/)
                #end
              end
            end
          end
        end

      else

        #this is where we test for scripts
        #puts "Not a shared library"
        File.open(File.join(sandbox,file)) do |file|
          file.each do |line|

            if line =~ /#!.*ruby/
            #  puts "Is a Ruby script"
              break true
            elsif line =~ /#!.*python/
              puts "Is a Python script"
              break true
            end

          end

        end
      end
    end

    #print out what libraries were obtained
    @depends_files.each_pair do |f,libs|
      pp "#{f}: #{libs.join(" ")}"
      #libs.each {|x| puts "#{libs}: #{x}" if not x.nil?}
    end

    #@libcache['i686'].each_key do |key|
    #  puts "key:#{key}"
    #  puts "value:#{@libcache['i686'][key]}"
    #end

  end


  def Depends.fill_libcache
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
          @libcache['x86-64'][ld_array[0][1]] = ld_array[0][3]
        else
          @libcache['i686'][ld_array[0][0]] = ld_array[0][2]
          #puts @libcache['i686'][ld_array[0][0]]
        end
      end
    end

  end

  def Depends.find_depends   #this is inhumanely slow!
    pacmandb = '/var/lib/pacman/local'
    pacman_packages = Dir.glob("#{pacmandb}/*")
    pacman_packages.each do |folder|
      #if File.basename(folder).start_with?("glibc")
      files_path = File.expand_path(File.join(folder, "files"))
      puts "ahah" if not File.exist?(files_path)
      if File.exist?(files_path)
        files_contents = []

        File.open(files_path) do |file|
          #puts "opened file"
          file.each_line {|line| files_contents << line.chomp!}
        end
        
        #add a forward slash to each file in 'files'
        files_contents.map! {|line| "/" + line}

        #files_contents.each {|line| pp "fc #{line}"}
        #files_contents.each {|line| line.split(" ").each {|x| sleep 0.1;pp x}}
        #files_contents.each {|line| pp line}
        @depends_files.each_pair do |actualdep, libarray|
        #  libarray.each {|line| sleep 0.4; pp "libarray: #{line}"}
          # a very magical line
          depends_array = files_contents & libarray
          #puts "fc: #{files_contents.join(" ")}"
          #puts "lb #{libarray.join(" ")}"
          dependency_name = File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0]
          if not depends_array.empty? 
            if not @other_depends_files.key?([dependency_name, actualdep])
              @other_depends_files[[dependency_name, actualdep]] = []
            end
            #puts "Adding to dict: #{depends_array.join(" ")}"
            # dependency_name is the name of the folder/package which contains the shared dependency
            # actualdep is the file belonging to the ruffled package which requires that shared library
            @other_depends_files[[dependency_name, actualdep]] << depends_array
          end
        end
      end
    end

    #this block prints out 'installed package: shared library dependencies'
    puts @other_depends_files.size
    @other_depends_files.each_pair do |dep, files|
      pp "#{dep[1]} requires #{dep[0]}: #{files.join(" ")}"
    end
  end

  def Depends.find_pkginfo_depends(pkginfo)

    files_contents = {}
    pacmandb = '/var/lib/pacman/local'
    pacman_packages = Dir.glob("#{pacmandb}/*")
    
    #fills listed_depends_array with names of dependencies from .PKGINFO
    pkginfo.each_pair do |key,value|
      if key == :depend
        #need to strip the <= >= signs
        #Note to self: no idea why it's [0][0] and not [0]
        value.map! {|x| x.to_s.scan(/([^<>=]*)[><=]*(.*)/)[0][0]}
        value.each {|x| @pkginfo_depends[x] = [] }
      end
    end


    pacman_packages.each do |folder|
      @pkginfo_depends.each_key do |dep|
        #puts "#{File.basename(folder)}: #{dep}"
        if File.basename(folder).start_with?(dep)
        #if folder =~ (/#{dep}[><=]*(.*)/) #this regexp needs to be changed! ><= not used
        #if folder =~ (/#{dep}[.\d-]+/) #this regexp needs to be changed! ><= not used
          #puts folder
          files_path = File.expand_path(File.join(folder, "files"))
          if File.exist?(files_path)

            File.open(files_path) do |file|
              #gets all files belonging to the dependency
              #file.each_line {|line| files_contents << line.chomp!}
              file.each_line {|line| @pkginfo_depends[dep] << "/" + line.chomp!}
              #puts @pkginfo_depends[dep].join(" ")
            end
          end
        end
       #something... 
      end
    end
    
    #this block prints out the files owned by the dependencies stated in .PKGINFO
    @pkginfo_depends.each_pair do |depname, deps|
      puts deps.length
      puts "#{depname}: #{deps.join(" ")}"
    end
    
  end

  def Depends.getcovered
  end
 
  def Depends.open_filesdb
    pacmandb = '/var/lib/pacman/local'
    pacman_packages = Dir.glob("#{pacmandb}/*")
    pacman_packages.each do |folder|
      #if File.basename(folder).start_with?("glibc")
      files_path = File.expand_path(File.join(folder, "files"))
      puts "ahah" if not File.exist?(files_path)
      if File.exist?(files_path)
        files_contents = []

        File.open(files_path) do |file|
          #puts "opened file"
          file.each_line {|line| files_contents << line.chomp!}
        end
      end
    end
  end

  def Depends.depends_loader
    @other_depends_files.each do |dep, files|

    end

  end


end
