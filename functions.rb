require 'optparse'
require 'rexml/document'
include REXML

def get_config_files_root()

=begin
to get the script to search in other than the default locations (/settings/..., /files/user/...)
for user-maintained configuration files, add a 'init.yml' file in the same folder as hpp.rb with 
the following key-value:

  config_files_root: <path-root>.
  [e.g: config_files_root = C:/foo]
	
which sets the value of $CONFIG_FILES_ROOT
	
the script searches in '<path-root>/settings/...' and '<path-root>/files/user/...' for the files.
=end

  begin

    hInit = YAML.load_file 'init.yml'
	  $CONFIG_FILES_ROOT = hInit["config_files_root"]

  rescue Errno::ENOENT
  
	  #there is no 'init.yml', so search in the default locations.
	  $CONFIG_FILES_ROOT = ""

  end
	
end

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

def show_version ()

  puts " "
  puts "**********************"
  puts "Help processing script"
  puts "Version:      2012.2.0"
  puts "**********************"
  puts " "

end  # show_version()


def writeFile(file_in_webhelp, its_html)

  begin
    f = File.open(file_in_webhelp, 'w')
    f.write(its_html)
    f.close
  rescue Exception
    puts ("Problem reading/writing " + file_in_webhelp) if $hSettings["show_onscreen_progress"]
  end

end


def openFile(fileInWebHelp)

  begin
    return File.read(fileInWebHelp)
  rescue
    puts "Couldn't open " + fileInWebHelp if $hSettings["show_onscreen_progress"]
  end

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

  if $hSettings["language"].nil?
    puts "No language specified."
    abort
  end
  
  langs = $hSettings["language"].split(",")

  if langs.length > 1 and !($hSettings["webhelp"].include? "<LANG>")
    puts "No <LANG> in WebHelp path but multiple languages specified."
    abort
  end
  
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
      
    rescue Exception => e

      puts e.to_s 

    end  

  end #copyGoButton


def process_topic_files(elements, lang)

   elements.each { |e|  
	 
	   print '.' if $hSettings["show_onscreen_progress"]
	 
	   if e.attributes['ref']
		 #it's a 'chunk' element, with a url to a sub-toc file in the 'ref' attribute
		   
			 #read the sub-toc file and pass the elements of its root node recursively to this function.
			 tocdoc = Document.new(File.new($TOCFILES_FOLDER + e.attributes['ref']))
			 process_topic_files(tocdoc.root.elements, lang)
		 
		 else
		 #it's a 'book' or 'item' element.
     #if it has a 'url' attribute that references a topic file, we need to process that file.		 
			  
		   if e.attributes['url']
			   
			   #there is a referenced topic file, so read in its html.
				 topic_file = $WEBHELP_PATH + "/" + e.attributes['url']
				 
				 begin
				   topic_html = File.read(topic_file)
				 rescue 
				   puts "\r\nCouldn't open following TOC item: " + e.attributes['url']
					 next
				 end
				 
				 #add the Google Analytics tracking code.
				 $GA.addTrackingCode(topic_html, "Content") if $hSettings["do_analytics"]
				 
				 #add the feedback form.
				 $FF.addFeedbackForm(e.attributes['url'], topic_file, topic_html) if $hSettings["do_feedbackforms"]
				 
				 #fix the table icons.
				 $TI.addIcons(topic_html) if $hSettings["do_tableicons"]
				 
				 #add the showme links.
				 if $hSettings["do_showmes"]
				   topic_file_without_path = get_file(e.attributes['url'])
				   $SM.addShowmeLinks(topic_file_without_path, topic_html, lang) 
				 end
				 
				 #do the close pop-ups fix.
			   topic_html.gsub!("<body", "<body onLoad=\"self.focus()\"") if $hSettings["apply_close_popups_fix"]
				 
				 #save the modified file.
				 writeFile(topic_file, topic_html)
				 
			 
			 end
			
			#recursively call the function on the child elements of the current element.
			process_topic_files(e.elements, lang)
		 
		 end
		 
	} #end each

end

def process_nontoc_topic_files(settings_file_root)

  begin

    open('files/user/nontoc/' + settings_file_root + '.txt').each do |nontoc_file| 
	    p nontoc_file.chomp
		end
  
	rescue => e
    #no problem if there isn't a nontoc topics file.
  end
	
end	


def build_scaffolding_hash

  scaffolding_string = String.new($hSettings["tracked_scaffolding_files"])
  
  #are we tracking the root file? check 'track_root_file' in the settings file to see.
  scaffolding_string += ($hSettings["track_root_file"] ? "," + $WEBHELP_FILE + "=Root" : "" )
  
  #build the scaffolding hash.
  $hScaffolding = buildHashFromKeyValueList(scaffolding_string)
	
	return $hScaffolding

end

def do_something?

  return false

end