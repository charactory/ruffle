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
      #@attrs = {'depends' => [], 'optdepends' => [], 'provides' => [], 'conflicts' => []} 
      @depends = []
      @optdepends = []
      @provides = []
      @conflicts = []
    end

    def load
      #current_attr = String.new
      line = File.open(@package).readlines.join
      #pp line
      #pp line[(/^%(.*)%\n(.*)/), 0]
      vars = line.scan(/^%(.*)%\n([^%]*)/)
      vars.each do |array|
        attr_name = array[0].downcase
        #puts array[0].downcase
          #array[1].strip.to_a.each {|x| pp x.split('>')[0].split('<')[0].split('=')[0].split(':')[0].to_s.chomp}
        #careful: newline may be a problem
        if attr_name == 'depends'
          array[1].strip.to_a.each {|x| @depends << x.split('>')[0].split('<')[0].split('=')[0].split(':')[0].to_s.chomp}
          break
        elsif attr_name == 'optdepends'
          array[1].strip.to_a.each {|x| @optdepends << x.split('>')[0].split('<')[0].split('=')[0].split(':')[0].to_s.chomp}
          break
        elsif attr_name == 'provides'
          array[1].strip.to_a.each {|x| @provides << x.split('>')[0].split('<')[0].split('=')[0].split(':')[0].to_s.chomp}
          break
        elsif attr_name == 'conflicts'
          array[1].strip.to_a.each {|x| @conflicts << x.split('>')[0].split('<')[0].split('=')[0].split(':')[0].to_s.chomp}
          break
        end
      end

    end
        #puts vars[0]
        #puts vars[1]
        #@attrs[vars[0]] = vars[1].split('\n') if not vars.nil?

=begin
        if line =~ /%DEPENDS%/
          current_attr = 'depends'
          #next
        elsif line =~ /%OPTDEPENDS%/
          current_attr = 'optdepends'
          #next
        elsif line =~ /%PROVIDES%/
          #line.delete("%").downcase
          current_attr = 'provides'
          #next
        elsif line =~ /%CONFLICTS%/
          current_attr = 'conflicts'
          #next
        else
          if line.strip != "" and not line.start_with?('%')
            a = line.split('>')[0].split('<')[0].split('=')[0].to_s.chomp
            @attrs[current_attr] << a
          end
        end
=end
#      end
  #  end

    def get_attr(attribute)
      if not @attrs.empty?
        @attrs[attribute].each {|x| yield x}
      end     
    end
    
  end


#require 'pp'
#p = Pacman.new('/var/lib/pacman/local/libtiff-3.8.2-4/depends')
pac = Pacman.new('/var/lib/pacman/local/gtk2-2.14.6-1/depends')
pac.load
puts pac.depends
#arr = []
#p.get_attr('depends') {|x| arr << x }
