load 'classes.rb'
require 'fileutils.rb'
require 'yaml'
require 'optparse'

options = {}
optparse = OptionParser.new do |opts|

  options[:version] = false
  opts.on('-v', '--version', 'Show version information') do

   options[:version] = true

  end

end

optparse.parse!

showVersionInformation (options[:version]) 

#to get the script to search in other the default locations (/settings/..., /files/user/...)
#for user-maintained configuration files, add a 'init.yml' file with the following key-value:
#config_files_root: <path-root>.
#the script will search in <path-root>/settings/... and <path-root>/files/user/... 
#for the files.
begin

  hInit = YAML.load_file 'init.yml'
	$CONFIG_FILES_ROOT = hInit["config_files_root"]

rescue Errno::ENOENT
  
	#there is no 'init.yml', so search in the default locations.
	$CONFIG_FILES_ROOT = ""

end



#get the settings file from the command line; if none was specified, use 'hpp.yml'
settings_file_root = (ARGV[0].nil? ? "hpp" : ARGV[0])

$hSettings = YAML.load_file $CONFIG_FILES_ROOT + "settings/" + settings_file_root + '.yml'


#check the language and filespec keys in the ini file.
#if everything's OK the array will contain all the languages we're processing.
aLangs = checkLanguage()

#GAProcessor needs to be global because it's also accessed in classes.rb
#in fact all these vars should probably be global
$GA = GAProcessor.new
ff = FeedbackFormProcessor.new
sm = ShowmeProcessor.new
ab = AboutboxProcessor.new
ti = TableIconProcessor.new

aLangs.each do |lang|

  #get the WebHelp path/file and the contents folder if specified.
  webhelp = String.new($hSettings["webhelp"])

  #extract all the various bits we need from the WebHelp path/file.
  webhelp_path, webhelp_file, webhelp_content_folder, is_legacy_webhelp = parseWebHelpFile(webhelp, lang)
	
	#copy the Japanese 'Go' button to the help system.
	copyGoButton(webhelp_path) if lang == "JPN"
  
  #build the scaffolding files array.
  #first, get the string from the settings file.
  scaffolding_string = String.new($hSettings["tracked_scaffolding_files"])
  
  #are we tracking the root file? check 'track_root_file' in the settings file to see.
  scaffolding_string += ($hSettings["track_root_file"] ? "," + webhelp_file + "=Root" : "" )
  
  #build the scaffolding hash.
  $hScaffolding = buildHashFromKeyValueList(scaffolding_string)
  
  #update the About box.
  ab.UpdateAboutBox(webhelp_path, lang) if $hSettings["do_aboutbox"]
  
  #copy the table icons to the WebHelp system.
  ti.copyIcons(webhelp_path) if $hSettings["do_tableicons"]
	
	#tell the feedback form processor to build the text of the form.
  ff.setFeedbackForm(lang) if $hSettings["do_feedbackforms"]
  
  #load the files for the showme links.
  sm.loadFiles(lang, settings_file_root) if $hSettings["do_showmes"]
  
  #copy the icon for the contextual links.
  sm.copyContextualIcon(webhelp_path) if $hSettings["do_showmes"]
  
  #find all the HTML files in all the folders and subfolders. 
  #if this is a legacy help system we're only interested in the current folder.
  search = ($hSettings["webhelp_content_folder"] == "legacy" ? "/*.htm" : "/**/*.htm")
  aFiles = Dir[webhelp_path + search]

  puts "File: " + webhelp if $hSettings["show_onscreen_progress"]
  print "Working" if $hSettings["show_onscreen_progress"]
  
  #loop around them.
  aFiles.each do |file_in_webhelp|

    #the list of ignored files in the contents folder will be relevant only if we're dealing with a legacy system.
    add_to_ignored_files = removeFileExtension(webhelp_file) + "_csh.htm," + removeFileExtension(webhelp_file) + "_rhc.htm"
    add_to_ignored_files += ("," + webhelp_file) if !$hSettings["track_root_file"]
    ignored_files = (is_legacy_webhelp ? String.new($hSettings["ignored_files"] + add_to_ignored_files) : "")
    
    #are we in the contents directory tree? if so:
    # - tag everything with the GA code,
    # - add the help feedback form, 
    # - add the showme links,
    # - add the icons to the Note, Warning and Tip tables,
    # - write the modified file to disk.

    if (file_in_webhelp.include? webhelp_content_folder) 
 
      #this rule will only fire for legacy systems:
      next if ignored_files.include? getFile(file_in_webhelp)

      webhelp_file_type = "Content"
    
      its_html = openFile(file_in_webhelp)
      next if its_html.nil?
    
      its_original_html = String.new(its_html)
  
      print "."  if $hSettings["show_onscreen_progress"]

      if $hSettings["do_analytics"]

        #if we're dealing with a legacy system, the scaffolding files are in the 'contents' folder, so we need to
        #check for them and tag them according to the type of scaffolding file.
        if is_legacy_webhelp
          webhelp_file_type = getScaffoldingFileType(getFile(file_in_webhelp)) if scaffolding_string.include? getFile(file_in_webhelp)
          puts (getFile(file_in_webhelp) + " " + webhelp_file_type) if $hSettings["debug_legacy_tagging"]
        end

        #to tag a group of showme wrappers, we can put them in a folder and move them into the 'contents' folder tree.
        #if we identify this folder using the 'showme_wrappers_folder' key in the settings file, the script attaches the
        #value 'ShowMe' to the 'Help System Page Type' custom GA variable.
        #
        #otherwise, this variable has the value 'Content'.
        #
        #you would probably only use this feature once, to mass-tag a bunch of showme wrapper files when you first set up 
        #your showmes. For individual showmes added later, it's just as easy to copy the GA code in manually.

        #set the wrappers folder to 'path_that_will_never_exist' if it isn't specified in the settings file.
        showme_wrappers_folder = String.new(($hSettings["showme_wrappers_folder"].nil?) ? "path_that_will_never_exist" : $hSettings["showme_wrappers_folder"])
        showme_wrappers_folder.gsub!("<LANG>", lang)
        webhelp_file_type = (file_in_webhelp.include? showme_wrappers_folder) ? "ShowMe" : webhelp_file_type
        $GA.addTrackingCode(file_in_webhelp, its_html, webhelp_file_type)
      
      end

      if !(scaffolding_string.include? getFile(file_in_webhelp))
      
        ff.addFeedbackForm(file_in_webhelp, its_html) if $hSettings["do_feedbackforms"] and !(file_in_webhelp.include? showme_wrappers_folder)
        sm.addShowmeLinks(getFile(file_in_webhelp), its_html, lang) if $hSettings["do_showmes"]
        ti.addIcons(its_html) if $hSettings["do_tableicons"]

      end
			
			#do the close pop-ups fix.
			its_html.gsub!("<body", "<body onLoad=\"self.focus()\"") if $hSettings["apply_close_popups_fix"]
      
      writeFile(file_in_webhelp, its_html) if its_html != its_original_html

    else  

      #we're not in the contents folder, so tag the scaffolding files with GA code.
      its_html = openFile(file_in_webhelp)

      #loop through the scaffolding files
      $hScaffolding.each do |sf, sf_type|
        
        #is the current file a scaffolding file?
        if file_in_webhelp.include? sf
       
          #yes, so tag it with the GA code.
          its_html = openFile(file_in_webhelp) 
      
          begin
        
            print "."  if $hSettings["show_onscreen_progress"]
            $GA.addTrackingCode(file_in_webhelp, its_html, sf_type) if $hSettings["do_analytics"]
            writeFile(file_in_webhelp, its_html)
        
          rescue
  
          end 
	 
        end #is the current file a scaffolding file?
    
      end #scaffolding files do loop
 
    end  #contents folder/scaffolding files folder if check
	
  end #loop around WebHelp files
  
  print "Done!\r\n" if $hSettings["show_onscreen_progress"]

end #language loop
