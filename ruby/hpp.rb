load 'classes.rb'
require 'fileutils.rb'

hSettings = Hash[*File.read("hpp.ini").scan(/^(.*)=(.*)$/).flatten]

aLangs = hSettings["language"].split(",")

if aLangs.length > 1 and !(hSettings["webhelp"].include? "<LANG>")

  puts "Multiple languages specified but no <LANG> in WebHelp path."
  abort

end


wh = WebHelp.new

begin
  
  strTrackingScript = File.read("files/ga_tracking_script.txt")
  
rescue
  puts "Couldn't open  GA tracking file."
end

aLangs.each do |lang|

  strFeedbackFile = "files/" + lang.downcase + "_help_feedback_form.txt"
  strFeedbackForm = File.read(strFeedbackFile)
  #update the product name.
  strFeedbackForm["<medidata-product-name>"] = hSettings["product"]
  
  if hSettings["webhelp"].include? "<LANG>"
    strWebHelp = String.new(hSettings["webhelp"])
    strWebHelp["<LANG>"] = lang
  end	
  
 
  
  strPath, strFile = wh.splitPathAndFile(strWebHelp)
  strWebHelpContentsFolder = strPath + "/" + File.basename(strFile, '.htm') + "/"
  strWebHelpImagesFolder = strPath + "/Images/"
  
  #copy the star graphic to the WebHelp systems
  FileUtils.cp "files/star.png", strWebHelpImagesFolder + "star.png"

  aFiles = Dir[strPath + "/**/*.htm"]
  puts "File: " + strWebHelp
  print "Working"
  aFiles.each do |element|

    #are we in the contents directory tree? if so, tag everything with the GA code,
    #and add the help feedback form.
    if element.include? strWebHelpContentsFolder
     
      begin
        element["?"] = "\'"
      rescue
      #the script shouldn't fail because the replace didn't find anything, but we don't need to do anything.
      end

      begin
        strHTMLFile = File.read(element)
      rescue
        #puts "Couldn't open " + element + ". Reason: bad file name."
      end

      begin
        print "."
        #puts "Added GA tracking code and feedback form to " + element
        strHTMLFile['</head>'] = strTrackingScript
	    strHTMLFile['</body>'] = strFeedbackForm
        fTaggedFile = File.open(element, 'w')
        fTaggedFile.write (strHTMLFile)
        fTaggedFile.close
      rescue
  
      end
  
    else  #we're not in the contents folder, so tag the scaffolding files with GA code.
  
      begin
        strHTMLFile = File.read(element)
      rescue
        #puts "Couldn't open " + element + ". Reason: bad file name."
      end
  
      aScaffoldingFiles = hSettings["tracked_scaffolding_files"].split(",")
      #loop through the scaffolding files
	  aScaffoldingFiles.each do |sf|
      
	    if element.include? sf
	  
	      begin
            strHTMLFile = File.read(element)
          rescue
            #puts "Couldn't open " + element + ". Reason: bad file name."
          end
	  
	      begin
	        print "."
	        #puts "Added GA tracking code to " + element
            strHTMLFile['</head>'] = strTrackingScript
	        fTaggedFile = File.open(element, 'w')
            fTaggedFile.write (strHTMLFile)
            fTaggedFile.close
          rescue
  
          end 
	 
        end #is the current file a scaffolding file?
    
	  end #scaffolding files do loop
 
  
    end  #contents folder/scaffolding files folder if check
	
  end #outer do loop
  
  print "Done!\r\n"

end #language loop



