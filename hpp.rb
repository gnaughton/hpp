load 'classes.rb'
load 'functions.rb'
require 'fileutils.rb'
require 'yaml'


#parse the command line options.
options = get_options()

#show the script version.
show_version() 

#stop if the user gave the '-v' or '--version' option and the command line.
abort if options[:version]

#set the value of $CONFIG_FILES_ROOT (see function for explanation).
get_config_files_root()

#get the settings file from the command line; if none was specified, use 'hpp.yml'
settings_file_root = (ARGV[0].nil? ? "hpp" : ARGV[0])

$hSettings = YAML.load_file $CONFIG_FILES_ROOT + "settings/" + settings_file_root + '.yml'

$GA = GAProcessor.new
$FF = FeedbackFormProcessor.new
$SM = ShowmeProcessor.new
ab = AboutboxProcessor.new
$TI = TableIconProcessor.new

#check the language and filespec keys in the ini file.
#if everything's OK the array will contain all the languages we're processing.
langs = checkLanguage()

langs.each do |lang|

  #get the WebHelp path/file and the contents folder if specified. 
  webhelp = String.new($hSettings["webhelp"])
	
  #get the WebHelp path and file.
  $WEBHELP_PATH, $WEBHELP_FILE = split_path_and_file(webhelp)
 
	$WEBHELP_PATH.gsub!("<LANG>", lang) 
	
	if $hSettings["show_onscreen_progress"]
	
	  puts ''
	  puts "File: " + $WEBHELP_PATH + "/" + $WEBHELP_FILE if $hSettings["show_onscreen_progress"]
    print "Working" if $hSettings["show_onscreen_progress"]
		
  end		

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
	
	#prepare for adding feedback forms.
	if $hSettings["do_feedbackforms"]
	  
		#copy stars.
		stars = ["star_on.jpg", "star_off.jpg", "star_hover.jpg", "star_on_almost.jpg", "star_hover_almost.jpg"] 
	  stars.each { |star| FileUtils.cp "files/system/feedbackform/" + star, $WEBHELP_PATH + '/' + star }
	
    #tell the feedback form processor to build the text of the form.
    $FF.setFeedbackForm(lang) if $hSettings["do_feedbackforms"]
		
  end
  
	#prepare showmes.
	if $hSettings["do_showmes"]
	
    #load the files.
		$SM.loadFiles(lang, settings_file_root) if $hSettings["do_showmes"]
    #copy the icon.
		$SM.copyContextualIcon($WEBHELP_PATH) if $hSettings["do_showmes"]
	
	end
	
	#build an XML document from the base TOC file.
	$TOCFILES_FOLDER = $WEBHELP_PATH + "/whxdata/"
	tocdoc = Document.new(File.new($TOCFILES_FOLDER + "whtdata0.xml"))
	
	#process the topic files (add feedback forms, GA code...)
	process_topic_files(tocdoc.root.elements, lang)
	
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
	
end #language loop

print "Done!\r\n" if $hSettings["show_onscreen_progress"] 