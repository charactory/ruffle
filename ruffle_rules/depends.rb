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

module Depends
  
  def Depends.analyze(file_list,package_path,sandbox)
    Depends.fill_libcache
    Depends.get_files(file_list)
    Depends.extract(sandbox,package_path)

    Find.find(sandbox) do |path|
      if File.file?(path)
        Depends.scan_libs(path)
      end
    end

    #Depends.scan_libs(sandbox)
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
    @depends_files.each {|x| puts x}
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
    libcache = {"i686" => [], "x86-64" => []}

    @depends_files.each_pair do |file, libs|
      raw_output = ""

      Open3.popen3("readelf -d #{file}") do |stdin, stdout, stderr|
        raw_output = stdout.read
        raw_error = stderr.read if not stderr.nil?
      end
      
      if not raw_output =~ (/^readelf(.*)/) or not raw_output.nil?
        raw_output.split("\n").each do |line|
        bitstring = line.split(" ")[0]
          if not bitstring.nil?
            libs << (bitstring.length > 10 ? "x86-64" : "i686")
          end
        libs << line.scan(/Shared library: \[(.*)\]/)
        end
      end

      #TODO review this part. The hash is getting messy with differentiating the architectures.

      #print out what libraries were obtained
      @depends_files.each_value do |libs|
        libs.each {|x| puts x}
      end



      # @depends_files now a hash 
      #

    end
  end


  def Depends.fill_libcache
    #ldconfig allows us to find the paths to libraries

    @libcache = {'x86-64' => {}, 'i686' => {}} if not @libcache
    raw_output = ""
    Open3.popen3("ldconfig -p") do |stdin, stdout, stderr|
      raw_output = stdout.read
      raw_error = stderr.read if not stderr.nil?
    end

    raw_output.split("\n").each do |line|
      ld_array = line.scan(/\s*(.*) \((.*)\) => (.*)/)
      if not ld_array[2].nil?
        if ld_array[2].start_with?('libc6,x86-64')
          @libcache['x86-64'][ld_array[1]] = ld_array[3]
        else
          @libcache['i686'][ld_array[1]] = ld_array[3]
        end
      end
    end

  end


  def Depends.find_depends
    pacmandb = '/var/lib/pacman/local'
    pacman_packages = Dir.glob("#{pacmandb}/*")
    pacman_packages.each do |folder|
      if File.exist?("#{pacmandb}/#{folder}/files")
        File.open("#{pacmandb}/#{folder}/files") do |file|
          file.each_line do |line|
            #do stuff
            matches = folder.scan(/(.*)-([^-]*)-([^-]*)/)
          end

        end
      end
    end
  end
            
        



  #TODO: read the part about script.setdefault in depends.py
  # if sick of this, work on a trivial rule

end
