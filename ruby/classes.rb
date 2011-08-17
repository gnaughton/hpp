
class WebHelp

  def splitPathAndFile (strWebHelp)

    #split a dir + file string into dir and file and return them

    #get the file name from the end of the string, by:
    #putting the string into an array,
    aWebHelp = strWebHelp.split("/")
  
    #then getting the last element (i.e. the file name).
    strFile = aWebHelp[aWebHelp.length-1]
  
    #now get rid of the last element (the file name) from the array,
    aWebHelp.delete_at(aWebHelp.length-1)
  
    #then build a string from what's left (to give the path)
    strPath = aWebHelp.join("/")
  
    return strPath, strFile
  
  end
  
  
  def removeFileExtension (strFile)

    return File.basename(strFile)

  end
 
end

class LogFile

  def initialize (strWebHelp)
  
    puts "LogFile constructor! For " + strWebHelp
	
  end

end