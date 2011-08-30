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
  webhelp = String.new($hSettings["webhelp"])
  webhelp_path, webhelp_file, webhelp_contents_folder, webhelp_images_folder = parseWebHelpFile(webhelp, lang)
  
  #tell the feedback form processor to build the text of the form.
  ff.setFeedbackForm (lang) if $hSettings["do_feedbackforms"]
  
  #copy the star graphic to the WebHelp systems
  ff.copyFormGraphics (webhelp_images_folder) if $hSettings["do_feedbackforms"]
  
  #find all the HTML files in all the folders and subfolders. 
  aFiles = Dir[webhelp_path + "/**/*.htm"]
  puts "File: " + webhelp
  print "Working"
  
  #loop around them.
  aFiles.each do |file_in_webhelp|
  
    #are we in the contents directory tree? if so:
	# - tag everything with the GA code,
    # - add the help feedback form, 
	# - add the showme links
	# - write the modified file to disc.
	if file_in_webhelp.include? webhelp_contents_folder
     
      its_html = openFile(file_in_webhelp)
	  
	  begin
        print "."
        ga.addTrackingCode (its_html) if $hSettings["do_analytics"]
		ff.addFeedbackForm (its_html) if $hSettings["do_feedbackforms"]
		sm.addShowmeLinks(file_in_webhelp, its_html, lang) if $hSettings["do_showmes"]
		writeFile(file_in_webhelp, its_html)
      rescue
  
      end
  
    else  #we're not in the contents folder, so tag the scaffolding files with GA code.
  
      its_html = openFile(file_in_webhelp)
	  
      aScaffoldingFiles = $hSettings["tracked_scaffolding_files"].split(",")
      #loop through the scaffolding files
	  aScaffoldingFiles.each do |sf|
      
	    if file_in_webhelp.include? sf
	  
	      its_html = openFile(file_in_webhelp) 
	      
	      begin
	        print "."
	        ga.addTrackingCode (its_html) if $hSettings["do_analytics"]
			writeFile(file_in_webhelp, its_html)
	        
          rescue
  
          end 
	 
        end #is the current file a scaffolding file?
    
	  end #scaffolding files do loop
 
  
    end  #contents folder/scaffolding files folder if check
	
  end #outer do loop
  
  print "Done!\r\n"

end #language loop



