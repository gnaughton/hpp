load 'classes.rb'
require 'fileutils.rb'

$hSettings = Hash[*File.read("hpp.ini").scan(/^(.*)=(.*)$/).flatten]

#check the language and filespec keys in the ini file.
#if everything's OK the array will contain all the languages we're processing.
aLangs = checkLanguage()

ga = GAProcessor.new
ff = FeedbackFormProcessor.new
sm = ShowmeProcessor.new

aLangs.each do |lang|

  #get the WebHelp path/file and extract all the various bits from it.
  strWebHelp = String.new($hSettings["webhelp"])
  strPath, strFile, strWebHelpContentsFolder, strWebHelpImagesFolder = parseWebHelpFile(strWebHelp, lang)
  
  #tell the feedback form processor to build the text of the form.
  ff.setFeedbackForm (lang) if $hSettings["do_feedbackforms"]
  
  #copy the star graphic to the WebHelp systems
  ff.copyFormGraphics (strWebHelpImagesFolder) if $hSettings["do_feedbackforms"]
  
  #find all the HTML files in all the folders and subfolders. 
  aFiles = Dir[strPath + "/**/*.htm"]
  puts "File: " + strWebHelp
  print "Working"
  
  #loop around them.
  aFiles.each do |fileInWebHelp|

    #are we in the contents directory tree? if so:
	# - tag everything with the GA code,
    # - add the help feedback form, 
	# - add the showme links
	# - write the modified file to disc.
	if fileInWebHelp.include? strWebHelpContentsFolder
     
      strHTMLFile = openFile(fileInWebHelp)
	  
	  begin
        print "."
        ga.addTrackingCode (strHTMLFile) if $hSettings["do_analytics"]
		ff.addFeedbackForm (strHTMLFile) if $hSettings["do_feedbackforms"]
		sm.addShowmeLinks(fileInWebHelp, strHTMLFile, lang) if $hSettings["do_showmes"]
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
	        ga.addTrackingCode (strHTMLFile) if $hSettings["do_analytics"]
			writeFile(fileInWebHelp, strHTMLFile)
	        
          rescue
  
          end 
	 
        end #is the current file a scaffolding file?
    
	  end #scaffolding files do loop
 
  
    end  #contents folder/scaffolding files folder if check
	
  end #outer do loop
  
  print "Done!\r\n"

end #language loop



