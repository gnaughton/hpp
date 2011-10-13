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


$hSettings = YAML.load_file 'hpp.yml'

#check the language and filespec keys in the ini file.
#if everything's OK the array will contain all the languages we're processing.
aLangs = checkLanguage()

ga = GAProcessor.new
ff = FeedbackFormProcessor.new
sm = ShowmeProcessor.new
ab = AboutboxProcessor.new
ti = TableIconProcessor.new

aLangs.each do |lang|

  #get the WebHelp path/file and the contents folder if specified.
  webhelp = String.new($hSettings["webhelp"])

  #extract all the various bits we need from the WebHelp path/file.
  webhelp_path, webhelp_file, webhelp_content_folder = parseWebHelpFile(webhelp, lang)

  #build the scaffolding files array.
  #first, get the string from the settings file.
  scaffolding_string = String.new($hSettings["tracked_scaffolding_files"])
  #are we tracking the root file? check 'track_root_file' in the settings file to see.
  scaffolding_string += ($hSettings["track_root_file"] ? "," + webhelp_file + "=Root" : "" )
  #build the array.
  hScaffolding = getScaffoldingFiles(scaffolding_string)

  #update the About box.
  ab.UpdateAboutBox(webhelp_path, lang) if $hSettings["do_aboutbox"]

  #copy the table icons to the WebHelp system.
  ti.copyIcons(webhelp_path) if $hSettings["do_tableicons"]
  
  #tell the feedback form processor to build the text of the form.
  ff.setFeedbackForm(lang) if $hSettings["do_feedbackforms"]
  
  #load the files for the showme links.
  sm.loadFiles(lang) if $hSettings["do_showmes"]
  
  #copy the icon for the contextual links.
  sm.copyContextualIcon(webhelp_path) if $hSettings["do_showmes"]
  
  #find all the HTML files in all the folders and subfolders. 
  aFiles = Dir[webhelp_path + "/**/*.htm"]
  puts "File: " + webhelp if $hSettings["show_onscreen_progress"]
  print "Working" if $hSettings["show_onscreen_progress"]
  
  #loop around them.
  aFiles.each do |file_in_webhelp|

    #are we in the contents directory tree? if so:
    # - tag everything with the GA code,
    # - add the help feedback form, 
    # - add the showme links,
    # - add the icons to the Note, Warning and Tip tables,
    # - write the modified file to disk.
    if file_in_webhelp.include? webhelp_content_folder
    
      its_html = openFile(file_in_webhelp)
      next if its_html.nil?
    
      its_original_html = String.new(its_html)
  
      print "."  if $hSettings["show_onscreen_progress"]

      if $hSettings["do_analytics"]

        #to tag a group of showme wrappers, we can put them in a folder and move them into the 'contents' folder tree.
        #if we identify this folder using the 'showme_wrappers_folder' key in the settings file, the script attaches the
        #value 'ShowMe' to the 'Help System Page Type' custom GA variable.
        #
        #otherwise, this variable has the value 'Content'.
        #
        #you would probably only use this feature once, to mass-tag a bunch of showme wrapper files when you first set up 
        #your showmes. For individual showmes added later, it's just as easy to copy the GA code in manually.

        #showme_wrappers_folder = String.new($hSettings["showme_wrappers_folder"])
        
        #set the wrappers folder to 'path_that_will_never_exist' if it isn't specified in the settings file.
        showme_wrappers_folder = String.new(($hSettings["showme_wrappers_folder"].nil?) ? "path_that_will_never_exist" : $hSettings["showme_wrappers_folder"])
        webhelp_file_type = (file_in_webhelp.include? showme_wrappers_folder.gsub("<LANG>", lang)) ? "ShowMe" : "Content"
        ga.addTrackingCode(file_in_webhelp, its_html, webhelp_file_type)
      
      end

      ff.addFeedbackForm(file_in_webhelp, its_html) if $hSettings["do_feedbackforms"]
      sm.addShowmeLinks(getFile(file_in_webhelp), its_html, lang) if $hSettings["do_showmes"]
      ti.addIcons(its_html) if $hSettings["do_tableicons"]
      writeFile(file_in_webhelp, its_html) if its_html != its_original_html

    else  

      #we're not in the contents folder, so tag the scaffolding files with GA code.
      its_html = openFile(file_in_webhelp)

      #loop through the scaffolding files
      hScaffolding.each do |sf, sf_type|
        
        #is the current file a scaffolding file?
        if file_in_webhelp.include? sf
       
          #yes, so tag it with the GA code.
          its_html = openFile(file_in_webhelp) 
      
          begin
        
            print "."  if $hSettings["show_onscreen_progress"]
            ga.addTrackingCode(file_in_webhelp, its_html, sf_type) if $hSettings["do_analytics"]
            writeFile(file_in_webhelp, its_html)
        
          rescue
  
          end 
	 
        end #is the current file a scaffolding file?
    
      end #scaffolding files do loop
 
    end  #contents folder/scaffolding files folder if check
	
  end #loop around WebHelp files
  
  print "Done!\r\n" if $hSettings["show_onscreen_progress"]

end #language loop
