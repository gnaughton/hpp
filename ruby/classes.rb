class GAProcessor

  def initialize
  
    @TRACKING_SCRIPT = File.read("files/ga/ga_tracking_script.txt")
  rescue
    puts "Couldn't open  GA tracking file."
	abort
  end
  
  def addTrackingCode (htmlFile)
  
    htmlFile['</head>'] = @TRACKING_SCRIPT
	#puts "Added tracking code to: " + @TRACKING_SCRIPT
  
  end


end

class FeedbackFormProcessor

  def setFeedbackForm (lang)
  
    @FEEDBACK_FORM = File.read("files/ff/" + lang.downcase + "_help_feedback_form.htm")
    #update the product name.
    @FEEDBACK_FORM["<medidata-product-name>"] = $hSettings["product"]
  
  end
  
  def copyFormGraphics (strWebHelpImagesFolder)
  
    FileUtils.cp "files/ff/star_on.jpg", strWebHelpImagesFolder + "star_on.jpg"
    FileUtils.cp "files/ff/star_on_almost.jpg", strWebHelpImagesFolder + "star_on_almost.jpg"
    FileUtils.cp "files/ff/star_off.jpg", strWebHelpImagesFolder + "star_off.jpg"
    FileUtils.cp "files/ff/star_hover.jpg", strWebHelpImagesFolder + "star_hover.jpg"
    FileUtils.cp "files/ff/star_hover_almost.jpg", strWebHelpImagesFolder + "star_hover_almost.jpg"
  
  end
  
  def addFeedbackForm (strHTMLFile)
  
    strHTMLFile['</body>'] = @FEEDBACK_FORM
  
  end

end

class ShowmeProcessor

  def initialize
  
    @LIST_TEMPLATE = File.read("files/sm/list_link_template.txt")
	@CONTEXT_TEMPLATE = File.read("files/sm/context_link_template.txt")
	@SHOWMES = IO.readlines("files/sm/showmes.txt")
	
  end

  
  def addShowmeLinks (webhelp_file_in_contents_folder, html_of_webhelp_file_in_contents_folder, lang)
  
    s3_bucket = String.new($hSettings["s3_bucket"])
	s3_bucket["<LANG>"] = lang
    
	puts "\r\n"
	puts puts s3_bucket, webhelp_file_in_contents_folder
	
	@SHOWMES.each do |row_in_showmes_file|
	 
	  row_in_showmes_file.chomp!
	  
	  text_where_link_goes, wrapper_file_for_showme, page_where_link_goes = row_in_showmes_file.split("\t")
	  
	  #skip to the next line in the list of showmes if the current line doesn't match the webhelp file we're looking at.
	  next if !(webhelp_file_in_contents_folder == page_where_link_goes)
	  
	  puts "**"
	  puts text_where_link_goes, wrapper_file_for_showme, page_where_link_goes
	  
	  url_in_link = s3_bucket + wrapper_file_for_showme
	  
	  #check whether the file we're looking at is the file that contains the list of showmes, or a file
	  #that will contain a contextual link from within its text.
	  #the text we use to build the link is different in these cases.
	  if webhelp_file_in_contents_folder == $hSettings["showme_list"]
	    
		#it's the file that contains the list of showmes;
		#we wrap the link around the text_where_link_goes
		
		link_text_to_add = String.new(@LIST_TEMPLATE)
		link_text_to_add["<LINK_TEXT>"] = text_where_link_goes
		puts "This is the list file!"
		
	  else
	    
		#it's a file that contains contextual links;
	    #the link comes immediately after the text_where_link_goes
	    
		link_text_to_add = String.new(@CONTEXT_TEMPLATE)
		link_text_to_add = text_where_link_goes + link_text_to_add
		puts "This is a contextual file."
	  
	  end  # is it the showme list or a contextual file?
	  
	 
	  link_text_to_add["<URL>"] = url_in_link
	  puts link_text_to_add
	  
	  html_of_webhelp_file_in_contents_folder[text_where_link_goes] = link_text_to_add
	  puts html_of_webhelp_file_in_contents_folder
	  
	  
	  
	end  #@SHOWMES.each
  
  end  #addShowmeLinks
  
  
  def OldaddShowmeLinks(webhelp_file_in_contents_folder, its_html, lang)
    
    bucket=String.new($hSettings["s3_bucket"])
	bucket["<LANG>"] = lang
	
	
	puts webhelp_file_in_contents_folder
	
 	@SHOWMES.each do |this_showme|
 
     
      	
	  #get rid of the newline character that IO.readlines adds to each line.
	  this_showme.chomp!
	   
	  #jump to the next line in the showmes file if the current line is a comment.
	  #next if this_showme[0]=="#" 
	  
	  link_text, wrapper_file, webhelp_file_that_needs_showmes = this_showme.split("\t")
	  
	  puts webhelp_file_that_needs_showmes, webhelp_file_in_contents_folder
	  puts "MATCH " if webhelp_file_in_contents_folder == webhelp_file_that_needs_showmes
	  #jump to the next line if the file doesn't need to have links added.
	  next if !webhelp_file_in_contents_folder == webhelp_file_that_needs_showmes   
	  
	  #if we're here, the file needs to have showme links added,
	  #so find out whether it's the file containing the list of showmes (and set up the link text accordingly),
	  if webhelp_file_in_contents_folder == $hSettings["showme_list"]
		puts "SHOWME_LIST!"
		link_to_add = String.new(@LIST_TEMPLATE)
		link_to_add["<LINK_TEXT>"] = link_text
		
	  #or a file that needs contextual links in the flow of its text.
	  else
		
		link_to_add = String.new(@CONTEXT_TEMPLATE)
 		link_to_add = (link_text + link_template) 
		
      end #list v contextual
	
      #finish preparing the link text,	
	  url = bucket + wrapper_file
	  link_to_add["<URL>"] = url
	  
	  #then add it to the html of the webhelp file.
	  its_html[link_text] = link_to_add
	 
	end #@SHOWMES.each
	
  end #addShowmeLinks
  
end #ShowmeProcessor

def writeFile(fileInWebHelp, strHTMLFile)

    fTaggedFile = File.open(fileInWebHelp, 'w')
    fTaggedFile.write (strHTMLFile)
    fTaggedFile.close

end

def openFile(fileInWebHelp)

  begin
    return File.read(fileInWebHelp)
  rescue
    puts "Couldn't open " + fileInWebHelp if $hSettings["show_onscreen_progress"]
  end

end

def parseWebHelpFile (strWebHelp, lang)

  if $hSettings["webhelp"].include? "<LANG>"
    strWebHelp["<LANG>"] = lang
  end
  
  strPath, strFile = splitPathAndFile (strWebHelp)
  strWebHelpContentsFolder = strPath + "/" + File.basename(strFile, '.htm') + "/"
  strWebHelpImagesFolder = strPath + "/Images/"
  
  return strPath, strFile, strWebHelpContentsFolder, strWebHelpImagesFolder

end  

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

def getFile (strWebHelp)

    #get the file name from the end of the string, by:
    #putting the string into an array,
    aWebHelp = strWebHelp.split("/")
  
    #then getting the last element (i.e. the file name).
    strFile = aWebHelp[aWebHelp.length-1]
  
    return strFile
  
end

def removeFileExtension (strFile)

    return File.basename(strFile)

end

def checkLanguage()

  if $hSettings["language"].nil?
    puts "No language specified."
    abort
  end
  
  aLangs = $hSettings["language"].split(",")

  if aLangs.length > 1 and !($hSettings["webhelp"].include? "<LANG>")
    puts "No <LANG> in WebHelp path but multiple languages specified."
    abort
  end
  
  return aLangs
  
end