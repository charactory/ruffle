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
  
  def Depends.analyze(file_list,package_path,sandbox)
    @libcache = {'x86-64' => {}, 'i686' => {}}
    Depends.fill_libcache
    Depends.get_files(file_list)
    Depends.extract(sandbox,package_path)
    Depends.scan_libs(sandbox)
    #@depends_files.each_value {|x| x.map {|y| puts y}}
    Depends.find_depends

  end

  private

  def Depends.get_files(file_list)
    @depends_files = {}
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
      #@raw_output.each {|x| puts x}
      #puts "readelf -d #{File.join(sandbox,file)}"
      #if not @raw_output.start_with?("readelf") or not @raw_output.nil?
      #if not @raw_output.start_with?("readelf") and @raw_error.nil?
      if not @raw_error.start_with?("readelf")
        #puts "succeeded readelf"
        @raw_output.split("\n").each do |line|
        #puts line
          bitstring = line.split(" ")[0]
          if line =~ /Shared library: \[(.*)\]/
            if not bitstring.nil? and bitstring.length > 7 
              #libs << (bitstring.length > 10 ? "x86-64" : "i686")
              if bitstring.length > 10
                libs << @libcache['x86-64'][line.scan(/Shared library: \[(.*)\]/)]
                #puts bitstring.length
                puts @libcache['x86-64'][line.scan(/Shared library: \[(.*)\]/)].class
              else
                #puts line.scan(/Shared library: \[(.*)\]/)[0]
                #puts line
                #puts file
                #puts @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)[0]]
                #if not @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)].nil?
                  #libs[line.scan(/Shared library: \[(.*)\]/)[0]] = File.expand_path
                  #puts line.scan(/Shared library: \[(.*)\]/)[0].to_s
                  key = line.scan(/Shared library: \[(.*)\]/)[0].to_s
                  #puts @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)[0]]
                  libs << @libcache['i686'][key]
                  #puts "haha"
                  #puts @libcache['i686'][line.scan(/Shared library: \[(.*)\]/)[0]]
                  #puts bitstring.length
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
    other_depends_files = {}
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

        files_contents.map! {|line| "/" + line}

        #files_contents.each {|line| pp "fc #{line}"}
        #files_contents.each {|line| line.split(" ").each {|x| sleep 0.1;pp x}}
        #files_contents.each {|line| pp line}
        @depends_files.each_value do |libarray|
        #  libarray.each {|line| sleep 0.4; pp "libarray: #{line}"}
          #libarray.each {|line| puts line.length}
          #libarray.map! {|line| line if not line.nil?}

          depends_array = files_contents & libarray
          #puts "fc: #{files_contents.join(" ")}"
          #puts "lb #{libarray.join(" ")}"
          dependency_name = File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0]
          if not depends_array.empty? 
          if not other_depends_files.key?(dependency_name)
            other_depends_files[dependency_name] = []
          end
          #puts "Adding to dict: #{depends_array.join(" ")}"
          other_depends_files[dependency_name] << depends_array
          end

            #libarray.each do |lib|
                #puts lib
                #lib_realpath = Pathname.new(lib)
            #  files_contents.map do |line|
            #    lined = "/" + line
                #if lined == lib or lined.start_with?(lib) #did not match end bit. Will do later.
            #    if lined == lib  #did not match end bit. Will do later.
            #      dependency_name = File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0]
            #      if not other_depends_files.key?(dependency_name)
            #        other_depends_files[dependency_name] = []
            #      end
            #      puts "Adding to dict: #{lined}"
            #      other_depends_files[dependency_name] << line
                  #have to build another array and add lib in here to make a list of libraries from app with shared deps
            #    elsif lined.start_with?(lib)
            #      puts "#{lined}: #{lib}"
            #    end
            #end
          #end
        #end

        end
      end
    end

    puts other_depends_files.size
    other_depends_files.each_pair do |dep, files|
      pp "#{dep}: #{files.join(" ")}"
    end
  end



  #TODO: read the part about script.setdefault in depends.py
  # if sick of this, work on a trivial rule

end
