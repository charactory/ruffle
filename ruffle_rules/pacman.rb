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
##module

  class Pacman

    def initialize(package)
      @package = package
      @attrs = {'depends' => [], 'optdepends' => [], 'provides' => [], 'conflicts' => []} 
    end

    def load
      current_attr = String.new
      #attr_reader :depends, :optdepends, :provides
      File.open(@package).each do |line|
        if line =~ /%DEPENDS%/
          #puts line
          current_attr = 'depends'
          #next
        elsif line =~ /%OPTDEPENDS%/
          current_attr = 'optdepends'
          #next
        elsif line =~ /%PROVIDES%/
          current_attr = 'provides'
          #next
        elsif line =~ /%CONFLICTS%/
          current_attr = 'conflicts'
          #next
        else
          if line.strip != "" and not line.start_with?('%')
            #puts line
            a = line.split('>')[0].split('<')[0].split('=')[0].to_s.chomp
            @attrs[current_attr] << a
          end
        end

      end
    end

    def get_attr(attribute)
      if not @attrs.empty?
        @attrs[attribute].each {|x| yield x}
      end     
    end
    
  end


#require 'pp'
#p = Pacman.new('/var/lib/pacman/local/libtiff-3.8.2-4/depends')
#p.load
#arr = []
#p.get_attr('depends') {|x| arr << x  }
#pp arr
