module Permissions

  def Permissions.check(files)
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
