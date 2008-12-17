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

module Permissions

  def Permissions.analyze(files, package_path, sandbox, pkginfo)
    files.each do |file| 
      #puts file[5] if file[0].start_with?('dr') #view directories
      #puts file[5] #view directories
      #puts file[0]
      #puts file[0].scan(/.?/).each {|x| puts x}
      case 
      when file[0].start_with?("d")
        #puts "Is a directory"
        #puts "Is executable" if file[0].end_with?("x")
        puts "Is not executable" if not file[0].end_with?("x")
      when file[0].start_with?("-")
        #puts "Is a file"
        #puts file[0]
        #the following are inverted to aid testing
        #puts "Is not world writable" if not file[0][-2..-2] == "w"
        #puts "Is world readable" if file[0][-3..-3] == "r"
        puts "Is world writable" if file[0][-2..-2] == "w"
        puts "Is not world readable" if not file[0][-3..-3] == "r"
      when file[0].start_with?("l")
        #puts "Is a link"
      end
    end
  end

end
