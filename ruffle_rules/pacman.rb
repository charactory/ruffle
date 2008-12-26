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
    attr_reader :depends, :optdepends, :provides, :conflicts

    def initialize(package)
      @package = package

      @depends = []
      @optdepends = []
      @provides = []
      @conflicts = []
      attrs = [@depends, @optdepends, @provides, @conflicts]
      #attrs.each {|x| puts x.class}
    end

    def load
      #current_attr = String.new
      lines = File.open(@package).readlines.join
      vars = lines.scan(/^%(.*)%\n([^%]*)/)
      vars.each do |array|
        attr_name = array[0].downcase
        #careful: newline may be a problem
        if attr_name == 'depends'
          store_name(array,@depends)
          break
        elsif attr_name == 'optdepends'
          store_name(array,@optdepends)
          break
        elsif attr_name == 'provides'
          store_name(array,@provides)
          break
        elsif attr_name == 'conflicts'
          store_name(array,@conflicts)
          break
        end
      end

    end

    def store_name(array, attr)
      #remove <>=: signs
      array[1].strip.to_a.each {|x| attr << x.split('>')[0].split('<')[0].split('=')[0].split(':')[0].to_s.chomp}
    end
    
  end


#require 'pp'
#p = Pacman.new('/var/lib/pacman/local/libtiff-3.8.2-4/depends')
#pac = Pacman.new('/var/lib/pacman/local/gtk2-2.14.6-1/depends')
#pac.load
#puts pac.depends
#puts pac.methods
#arr = []
#p.get_attr('depends') {|x| arr << x }
