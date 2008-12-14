module Depends
  
  def Depends.analyze(file_list)
    Depends.get_files(file_list)
  end

  private

  def Depends.get_files(file_list)
    files_to_extract = []

    file_list.each do |file|
      if file[0].start_with?("-") # is this a file?
        if file[0][3..3] == "x" or file[5] =~ /(\.so?\.?)+/ # is this an executable/shared library?
          files_to_extract << file[5]
        end
      end
    end
    files_to_extract.each {|x| puts x}
  end
  #TODO: read the part about script.setdefault in depends.py
  # if sick of this, work on a trivial rule

end
