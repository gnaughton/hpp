require 'optparse'
require 'rexml/document'
include REXML

def get_options()

  begin
	
	  require 'optparse'
		
		options = {}
    optparse = OptionParser.new do |opts|
     
      options[:version] = false
			
			opts.on('-v', '--version', 'Show version information') do
        options[:version] = true
      end # opts.on
			
    end # do |opts|

	  optparse.parse!
		return options
		
	end
	
end # get_options()

def writeFile(file_in_webhelp, its_html)

  begin
    f = File.open(file_in_webhelp, 'w')
    f.write(its_html)
    f.close
  rescue Errno::ENOENT
   $CM.add_error("Couldn't write file: " + file_in_webhelp, false)
  end

end


def openFile(fileInWebHelp)

    return File.read(fileInWebHelp)
   
end

def split_path_and_file (path_and_file)

    #split a dir + file string into dir and file and return them

    #get the file name from the end of the string, by:
    #putting the string into an array,
    a = path_and_file.split("/")
  
    #then getting the last element (i.e. the file name).
    file = a[a.length-1]
  
    #now get rid of the last element (the file name) from the array,
    a.delete_at(a.length-1)
  
    #then build a string from what's left to give the path
    path = a.join("/")
  
    return path, file
  
end

def get_file (path_and_file) 

    #get the file from a path + file

    path, file = split_path_and_file(path_and_file)
		
		return file
		
end


def removeFileExtension (strFile)

    return File.basename(strFile, '.*')

end

def checkLanguage()

  $CM.add_error("No language specified", true) if $hSettings["language"].nil?
  
  langs = $hSettings["language"].split(",")

  $CM.add_error("No <LANG> in WebHelp path but multiple languages specified.", true) if langs.length > 1 and !($hSettings["webhelp"].include? "<LANG>")
  
  return langs
  
end

def buildHashFromKeyValueList (list)

    s = Array.new() 
    list.split(",").each {|kv| s << kv.split("=")}
    
    return Hash[*s.flatten]


end

def copy_go_button(webhelp_path)
    
    begin

      FileUtils.cp "files/system/misc/Gray_Go.gif", webhelp_path + "/Gray_Go.gif" 
      
    rescue Errno::ENOENT

     $CM.add_error("Couldn't copy Go button", false)

    end  

  end #copyGoButton


def process_topic_files(elements, lang)

  #walk through the TOC files stored in the /whxdata folder as whtdata.0xml, whtdata1.xml...
	#only whtdata0.xml might be present. If there are more, they are referenced in 'chunk' elements.

   elements.each { |e|  
	 
	  $CM.update_progress_display()
	 
	   if e.attributes['ref']
		 #it's a 'chunk' element, with a url to a sub-toc file in the 'ref' attribute
		   
			 #read the sub-toc file and pass the elements of its root node recursively to this function.
			 tocdoc = Document.new(File.new($TOCFILES_FOLDER + e.attributes['ref']))
			 process_topic_files(tocdoc.root.elements, lang)
		 
		 else
		 #it's a 'book' or 'item' element.
     #if it has a 'url' attribute that references a topic file, we need to process that file.		 
			  
		   process_topic_file(e.attributes['url'], lang) if e.attributes['url']
			
			 #recursively call the function on the child elements of the current element.
			 process_topic_files(e.elements, lang)
		 
		 end
		 
	} #end each

end

def process_topic_file(file_in_toc, lang)

         #process a file in the TOC.

         #read in the file's HTML.  
				 topic_file = $WEBHELP_PATH + "/" + file_in_toc
				
				 begin
				   topic_html = File.read(topic_file)
				 rescue Errno::ENOENT 
				   $CM.add_error("Couldn't open topic: " + file_in_toc, false)
					 return
				 end
				 
				 #add the Google Analytics tracking code.
				 $GA.addTrackingCode(topic_html, "Content") if $hSettings["do_analytics"]
				 
				 #add the feedback form.
				 $FF.addFeedbackForm(file_in_toc, topic_file, topic_html) if $hSettings["do_feedbackforms"]
				 
				 #fix the table icons.
				 $TI.addIcons(topic_html) if $hSettings["do_tableicons"]
				 
				 #add the showme links.
				 if $hSettings["do_showmes"]
				   topic_file_without_path = get_file(file_in_toc)
				   $SM.addShowmeLinks(topic_file_without_path, topic_html, lang) 
				 end
				 
				 #do the close pop-ups fix.
			   topic_html.gsub!("<body", "<body onLoad=\"self.focus()\"") if $hSettings["apply_close_popups_fix"]
				 
				 #save the modified file.
				 writeFile(topic_file, topic_html)
				 
end

def process_nontoc_topic_files(settings_file_root, lang)

=begin
	  if the help system has topics not in the toc, they are stored in a file in files/user/nontoc/
		the file has the name of the settings file used to process the help system + '.txt', 
		so balance.txt for balance.yml. 
		
		the user can be more specific and use a language-specific file, so balance_ENG.txt, balance_JPN.
		
		this function looks for the language-specific file first, then the general file.
		if it doesn't find either, it carries on - in most cases these files won't exist.
		
		the file has one topic file per line, so:
		Not_in_TOC1.htm
		Not_in_TOC2.htm
		
		files are specified relative to the root folder of the help system, so:
		C:/BalanceHelp/Balance/Not_in_TOC.htm --> Balance/Not_in_TOC.htm
		C:/RaveHelp/Not_in_TOC.htm            --> Not_in_TOC.htm
		
=end

  #used to stop processing of two files in error. see comment below.
  found_file_to_open = false
  
  #look for a file with a language extension first, then one without.
  files_to_open = ["files/user/nontoc/" + settings_file_root + "_" + lang + ".txt", "files/user/nontoc/" + settings_file_root + ".txt"]
  files_to_open.each do |file_to_open|
	
	  #if for some reason there are foo.txt and foo_<LANG>.txt files, don't process foo.txt.
	  next if found_file_to_open
	
	  begin	
		
		  open(file_to_open).each do |nontoc_file| 
			
			  #add the GA, feedback forms etc. to the topic.
	      process_topic_file(nontoc_file.chomp!, lang)
			
			end #open(file_to_open).each do
			
			found_file_to_open = true
		
		rescue 
      #no problem if there isn't a nontoc topics file.
    end #begin rescue block    
			
	end #files_to_open.each do
		
end #def process_nontoc...	


def build_scaffolding_hash

  scaffolding_string = String.new($hSettings["tracked_scaffolding_files"])
  
  #are we tracking the root file? check 'track_root_file' in the settings file to see.
  scaffolding_string += ($hSettings["track_root_file"] ? "," + $WEBHELP_FILE + "=Root" : "" )
  
  #build the scaffolding hash.
  $hScaffolding = buildHashFromKeyValueList(scaffolding_string)
	
	return $hScaffolding

end

def load_settings_file(settings_file_root)

  begin
    $hSettings = YAML.load_file "settings/" + settings_file_root + '.yml'
  rescue Errno::ENOENT 
    $CM.add_error("Couldn't open settings file: " + settings_file_root + '.yml', true)
  end

end