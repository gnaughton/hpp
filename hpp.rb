load 'classes.rb'
load 'functions.rb'
require 'fileutils.rb'
require 'yaml'

$CM = ConsoleMessages.new
$GA = GAProcessor.new
$FF = FeedbackFormProcessor.new
$SM = ShowmeProcessor.new
ab = AboutboxProcessor.new
$TI = TableIconProcessor.new


#parse the command line options.
options = get_options()

#show the script version. 
#this function will stop the script if the user gave the '-v' or '--version' option on the command line.
$CM.show_version(options[:version]) 

#get the settings file from the command line; if none was specified, use 'hpp.yml'
settings_file_root = (ARGV[0].nil? ? "hpp" : ARGV[0])

#load it.
load_settings_file(settings_file_root)
 
#check the language and filespec keys in the ini file.
#if everything's OK the array will contain all the languages we're processing.
langs = checkLanguage()


#this array starts with the list of mandatory files.
#each time a topic is processed, it is subtracted from the array.
#the remaining topics in the array are the missing mandatory files.
missing_mandatory = get_mandatory_files(settings_file_root)

langs.each do |lang|

  #get the WebHelp path/file and the contents folder if specified. 
  webhelp = String.new($hSettings["webhelp"])
	
  #get the WebHelp path and file.
  $WEBHELP_PATH, $WEBHELP_FILE = split_path_and_file(webhelp)
  $WEBHELP_PATH.gsub!("<LANG>", lang) 
	
	#show the message that we've started processing a webhelp system.
	$CM.start_file_message()
	
	#copy the Japanese 'Go' button to the help system.
	copy_go_button($WEBHELP_PATH) if lang == "JPN"
  
  #build the scaffolding files array.
  #first, get the string from the settings file.
  scaffolding_string = String.new($hSettings["tracked_scaffolding_files"])
  
  #are we tracking the root file? check 'track_root_file' in the settings file to see.
  scaffolding_string += ($hSettings["track_root_file"] ? "," + $WEBHELP_FILE + "=Root" : "" )
  
  #update the About box.
  ab.update_about_box($WEBHELP_PATH, lang) if $hSettings["do_aboutbox"]
  
  #copy the table icons to the WebHelp system.
  $TI.copy_icons($WEBHELP_PATH) if $hSettings["do_tableicons"]
	
  #tell the feedback form processor to build the text of the form.
  $FF.setFeedbackForm(lang) if $hSettings["do_feedbackforms"]
  
	#load the showme files.
	$SM.loadFiles(lang, settings_file_root) if $hSettings["do_showmes"]
  
	#copy the showme icon.
	$SM.copyContextualIcon($WEBHELP_PATH) if $hSettings["do_showmes"]
	
	
	#build an XML document from the base TOC file.
	$TOCFILES_FOLDER = $WEBHELP_PATH + "/whxdata/"
	tocdoc = Document.new(File.new($TOCFILES_FOLDER + "whtdata0.xml"))
	
	#process the topic files (add feedback forms, GA code...)
	process_topic_files(tocdoc.root.elements, lang, missing_mandatory)
	
	#process any additional files not in the TOC.
	process_nontoc_topic_files(settings_file_root, lang)
	
	#add Google Analytics to the scaffolding files.
	if $hSettings["do_analytics"]
	
	  #build the scaffolding hash and loop around it.
    $hScaffolding = build_scaffolding_hash()
	  $hScaffolding.each_key { |key| 
	
	    #read in the file, add the GA code, write the file.
	    scaffolding_file =  $WEBHELP_PATH + "/" + key
		  scaffolding_html = File.read(scaffolding_file)
		  $GA.addTrackingCode(scaffolding_html, $hScaffolding[key]) 
			writeFile(scaffolding_file, scaffolding_html)
	
	  } #end each key
		
	end
		
	#Add GA code to the showme wrappers.
	if $hSettings["showme_wrappers_folder"]
		
		showme_wrappers_folder = String.new($hSettings["showme_wrappers_folder"])
		showme_wrappers_folder.gsub!("<LANG>", lang)
		
		wrappers = Dir[showme_wrappers_folder + "/*.htm"]
	  wrappers.each { |wrapper_file| 
			
		 wrapper_html = File.read(wrapper_file)
		 $GA.addTrackingCode(wrapper_html, "ShowMe") 
		 writeFile(wrapper_file, wrapper_html)
			
		} # end each wrapper_file
			
	end # if showme_wrappers_folder
  
	#add the list of missing topics to the list of errors.
	$CM.add_missing_mandatory_messages(missing_mandatory)
  
	#display the wrapup text for the help system.
	$CM.done()
	
	
	
end #language loop

