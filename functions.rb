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

def add_to_file_list(file_in_webhelp, its_html)

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

def get_path (path_and_file)

  #get the path from a path + file
  path, file = split_path_and_file(path_and_file)
  
	return path

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


def process_topic_files(lang, missing_mandatory)

  #get the list of topics from the RoboHelp.hhp file.
	hhp = String.new($hSettings["robohelp_hhp_file"]).gsub("<LANG>",lang)
	
	#read in the .hhp file.
	begin
	  rh = File.read(hhp)
	rescue Errno::ENOENT
	  $CM.add_error("Couldn't read hhp file: " + hhp, true)
	end
	
	#extract the topic list from it.
	topics = rh.match(/\[FILES\]\n(.*?)\n\n/m).to_s.chomp
	
	#loop through the topics.
	topics.each_line do |topic|
	
	  #couldn't figure out a regexp that ignores the initial [FILES], so ignore it here.
	  next if topic.chomp == "[FILES]"
		
		#add the feedback form, etc.
		process_topic_file(topic, lang, missing_mandatory)
	
	end #each_line do 
	
end #process_topic_files

def process_topic_file(topic, lang, missing_mandatory)
         
				 
				 #change the direction of the separators - Ruby likes "/", not "\" 
				 #replace spaces with underscores; the RoboHelp project has spaces, the WebHelp system has underscores.
	       t = topic.chomp.gsub("\\","\/").gsub(" ","_")

				 #remove the topic from the global array that stores mandatory files.
				 missing_mandatory.delete(t)
				
				 #get the fully-qualified topic file.
 				 topic_file =  $WEBHELP_PATH + "\/" + t
				 
         #read in its HTML
				 begin
				   topic_html = File.read(topic_file)
				 rescue Errno::ENOENT 
				   $CM.add_error("Couldn't open topic: " + topic_file, false)
					 return
				 end
				 
				 #add the Google Analytics tracking code.
				 $GA.addTrackingCode(topic_html, "Content") if $hSettings["do_analytics"]
				 
				 #add the feedback form.
				 $FF.addFeedbackForm(topic, topic_file, topic_html) if $hSettings["do_feedbackforms"]
				 
				 #fix the table icons.
				 $TI.addIcons(topic_html) if $hSettings["do_tableicons"]
				 
				 #add the showme links.
				 if $hSettings["do_showmes"]
				   topic_file_without_path = get_file(t)
				   $SM.addShowmeLinks(topic_file_without_path, topic_html, lang) 
				 end
				 
				 #do the close pop-ups fix.
			   topic_html.gsub!("<body", "<body onLoad=\"self.focus()\"") if $hSettings["apply_close_popups_fix"]
				 
				 #save the modified file.
				 add_to_file_list(topic_file, topic_html)
				 
end


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

def get_mandatory_files(settings_file_root)

  #if there is a mandatory topics file, use it to populate the mandatory topics array.
  file_to_open = "files/user/mandatory/" + settings_file_root + ".txt"
  mandatory = []
	begin
	  open(file_to_open).each { |m| mandatory << m.chomp} 
	rescue
	  #no need to worry if there isn't a mandatory topics file.
	end
	
	return mandatory

end

def add_ga_to_scaffolding_files()

  if $hSettings["do_analytics"]
	
	  #build the scaffolding hash and loop around it.
    $hScaffolding = build_scaffolding_hash()
	  $hScaffolding.each_key do |key| 
	
	    #read in the file, add the GA code, add the file to the list
			#of files to be written.
	    scaffolding_file =  $WEBHELP_PATH + "/" + key
		  scaffolding_html = File.read(scaffolding_file)
		  $GA.addTrackingCode(scaffolding_html, $hScaffolding[key]) 
			add_to_file_list(scaffolding_file, scaffolding_html)
	
	  end #each_key do
		
	end # if $hSettings
		
end # add_ga...

def add_to_file_list(file, html)

  $files_to_write[file] = html

end

def write_files

  $CM.display_start_write_message()
  $files_to_write.each_key do |file|
		  
    html = $files_to_write[file]
		begin
	    
			f = File.open(file, 'w')
      f.write(html)
      f.close
		rescue Errno::ENOENT
      $CM.add_error("Couldn't write "  + file + " to disk.", true)
    end  #rescue
		
		$CM.update_filewrite_progress_display()
   
	end  #each_key
	
	$CM.display_end_write_message()
		
end  #write_files