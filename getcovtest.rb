  def gtcovered(deplist, covered_deps)
    #accepts two arguments: a package and an array.
    full_package_names = []
    deplist_next = [] #next list to use in recursion
    pacmandb = '/var/lib/pacman/local'
    temp_array = []

    (deplist - covered_deps).each do |pkgname|
      Dir.glob("#{pacmandb}/*").each do |folder|
        if File.basename(folder).start_with?(pkgname)
          full_package_names << folder #contains full path
          deplist << pkgname

          File.open(File.join(folder, 'depends')).each do |dep|
            if not dep.start_with?('%')
              d = dep.scan(/([^<>=]*)[><=]*(.*)/)[0][0].chomp!
              covered_deps << d
              gtcovered([d], covered_deps)
            end
          end
        end
      end
    end
  end
 
  class Pacman
    def Pacman.load_depends(depends, attribute)
      attrs = []
      File.open(depends).each do |line|
        if line.start_with?('%')
          attrs << [line.gsub!('%', '').strip!]
        elsif not attrs.include?(line) and line.strip != ""
          #a = line.scan(/([^<>=]*)[><=]*(.*)/)[0][0].chomp!
          a = line.split('>')[0].split('<')[0].split('=')[0].to_s.chomp
          (attrs.last << a) if not a.nil?
        end
      end
      if not attrs.empty?
      attrs.assoc(attribute).each {|x| yield x}
      end
    end
  end


  def getcovered(deplist, covered_deps)
    #accepts two arguments: a package and an array.
    full_package_names = []
    pacmandb = '/var/lib/pacman/local'
    temp_array = []
    #for each dependency listed that isn't already covered...
    deplist.each do |pkgname|
      Dir.glob("#{pacmandb}/*").each do |folder|
        #if File.basename(folder).start_with?(pkgname)  #problematic because 'sh' matches a lot of things
        if File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0] == pkgname
        #if File.basename(folder).scan(/(.+)[><=]*(.*)*/)[0][0] == pkgname
          full_package_names << folder #contains full path
          #puts File.join(folder, 'depends')
        end
    end

    full_package_names.each do |folder|
          Pacman.load_depends(File.join(folder, 'depends'), 'DEPENDS') do |dep|
            #if dep != 'DEPENDS' and not dep.nil? and dep != 'sh'
            if dep != 'DEPENDS' and not dep.nil?
              if not covered_deps.include?(dep)
                puts "Currently examined dep: #{dep}"
                puts "Covered depedencies: #{(dep.to_a + covered_deps).join(" ")}"
                covered_deps << dep 
                getcovered([dep], covered_deps)
              end
            end
          end
        end
      end
  end

  def covered(deplist, covered_deps)
    #accepts two arguments: a package and an array.
    full_package_names = []
    pacmandb = '/var/lib/pacman/local'
    temp_array = []
    #for each dependency listed that isn't already covered...
    folders = []

      Dir.glob("#{pacmandb}/*").each do |folder|
        folders << File.basename(folder).scan(/(.*)-([^-]*)-([^-]*)/)[0][0]
      end
          
          #puts File.join(folder, 'depends')

    deplist.each do |pkgname|
          Pacman.load_depends(File.join(folder, 'depends'), 'DEPENDS') do |dep|
            if dep != 'DEPENDS'
              if not covered_deps.include?(dep)
                covered_deps << dep 
                gcovered([dep], covered_deps)
              end
            end
          end
        end
      end

cd = []
dd = []

#gcovered(["poppler"],cd)
getcovered(["sakura", "ruby"],cd)
#gcovered(gcovered(["pcmanfm"],dd),dd)
require 'pp'
pp cd.compact.uniq
#pp dd.compact.uniq
#gtcovered(["gtk2"],cd)
