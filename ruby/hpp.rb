load 'classes.rb'
require 'fileutils.rb'

$hSettings = Hash[*File.read("hpp.ini").scan(/^(.*)=(.*)$/).flatten]

if $hSettings["language"].nil?

  puts "No language specified."
  abort
  
end
  
aLangs = $hSettings["language"].split(",")

if aLangs.length > 1 and !($hSettings["webhelp"].include? "<LANG>")

  puts "No <LANG> in WebHelp path but multiple languages specified."
  abort

end


wh = WebHelp.new
ga = GAProcessor.new
ff = FeedbackFormProcessor.new

aLangs.each do |lang|

  #build the WebHelp path/file and extract all the various bits from it.
  
  strWebHelp = String.new($hSettings["webhelp"])
  if $hSettings["webhelp"].include? "<LANG>"
    strWebHelp["<LANG>"] = lang
  end	
  
  strPath, strFile = wh.splitPathAndFile(strWebHelp)
  strWebHelpContentsFolder = strPath + "/" + File.basename(strFile, '.htm') + "/"
  strWebHelpImagesFolder = strPath + "/Images/"
  
  #tell the feedback form processor to build the text of the form.
  ff.setFeedbackForm (lang)
  
  #copy the star graphic to the WebHelp systems
  ff.copyFormGraphics (strWebHelpImagesFolder)
 
  aFiles = Dir[strPath + "/**/*.htm"]
  puts "File: " + strWebHelp
  print "Working"
  aFiles.each do |fileInWebHelp|

    #are we in the contents directory tree? if so, tag everything with the GA code,
    #add the help feedback form, and write the modified file to disc.
    if fileInWebHelp.include? strWebHelpContentsFolder
     
      strHTMLFile = openFile(fileInWebHelp)
	  
	  begin
        print "."
        ga.addTrackingCode (strHTMLFile)
		ff.addFeedbackForm (strHTMLFile)
        writeFile(fileInWebHelp, strHTMLFile)
      rescue
  
      end
  
    else  #we're not in the contents folder, so tag the scaffolding files with GA code.
  
      
	  strHTMLFile = openFile(fileInWebHelp)
	  
      aScaffoldingFiles = $hSettings["tracked_scaffolding_files"].split(",")
      #loop through the scaffolding files
	  aScaffoldingFiles.each do |sf|
      
	    if fileInWebHelp.include? sf
	  
	      strHTMLFile = openFile(fileInWebHelp) 
	      
	      begin
	        print "."
	        ga.addTrackingCode (strHTMLFile)
			writeFile(fileInWebHelp, strHTMLFile)
	        
          rescue
  
          end 
	 
        end #is the current file a scaffolding file?
    
	  end #scaffolding files do loop
 
  
    end  #contents folder/scaffolding files folder if check
	
  end #outer do loop
  
  print "Done!\r\n"

end #language loop



