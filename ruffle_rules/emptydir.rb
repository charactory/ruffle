
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

module Emptydir

  def Emptydir.analyze(files, package_path, sandbox, pkginfo)
    listed_dirs = {}
    dir_group = {}
    file_group = {}

    files.each do |file| 
      if file[5].end_with?('/')
        #dir_group[file] = 1
        listed_dirs[file[5]] = 1
        #puts file[5]
      else
        file_group[file[5]] = 1
      end
    end
require 'time'

    file_group.each_key do |file|
      updir = nil
      loop do
        if not dir_group.has_key?(updir) and updir != '.' and updir != nil
          dir_group[updir + '/'] = 1
        end
        if updir.nil?
          updir = File.dirname(file)
        else
          updir = File.dirname(updir)
        end
        #puts updir
        #puts file

        break if updir == '/' or updir == '.'
      end
    end

    require 'pp'
    #dir_group.each_key {|x| dir_group[x + '/']}
    #pp listed_dirs
    #pp dir_group    
    empty_dirs = []

    listed_dirs.each_key do |dir|
      if not dir_group.has_key?(dir)
        empty_dirs << dir
      end
    end

    if not empty_dirs.empty?
      puts "Directories (#{empty_dirs.join(" ")}) are empty."
    end

  end

end
