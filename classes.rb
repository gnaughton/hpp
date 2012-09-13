class GAProcessor

  def initialize
  
    @TRACKING_SCRIPT = File.read("files/system/googleanalytics/ga_tracking_script.txt")
    rescue
      puts "Couldn't open  GA tracking file."
      abort
    end
  
  def addTrackingCode (its_html, webhelp_file_type)
  
    begin
    
      tracking_script = String.new(@TRACKING_SCRIPT)
     
      web_property_id = $hSettings["web_property_id_" + $hSettings["help_system_status"]]
      tracking_script.gsub!("HELP_SYSTEM_NAME", $hSettings["product"])
      tracking_script.gsub!("WEB_PROPERTY_ID", web_property_id)
      tracking_script.gsub!("HELP_SYSTEM_PAGE_TYPE", webhelp_file_type) 
			
			#track the pageview only if it's the root file or a content file.
			#we don't track the pageviews of scaffolding files, just the event.
			pageview = (webhelp_file_type == "Content" || webhelp_file_type == "Root" ? "_gaq.push(['_trackPageview']);" : "")
			tracking_script.gsub!("HELP_SYSTEM_PAGEVIEW", pageview) 
			
      its_html.gsub!(/<\/head>/i, tracking_script) 

    rescue Exception => e

      puts "Couldn't add GA script." 
      puts "Exception: " + e.to_s
 
    end  

  end #addTrackingCode

end  #GAProcessor

class FeedbackFormProcessor

  def setFeedbackForm (lang)
  
    #@FEEDBACK_FORM = File.read("files/system/feedbackform/" + lang.downcase + "_help_feedback_form.htm").encode('UTF-8')
    @FEEDBACK_FORM = openFile("files/system/feedbackform/" + lang.downcase + "_help_feedback_form.htm")
		
		#update the product name.
    @FEEDBACK_FORM["<medidata-product-name>"] = $hSettings["product"]
		
		#point the feedback form at the Live or Test spreadsheet.
		feedback_form_key_key = "feedback_form_key_" + $hSettings["help_system_status"]
		
    #use the Live key as the default for backward compatibility.	
		feedback_form_key_value = $hSettings[feedback_form_key_key].nil? ? "dDNocW9OVE1fTERlamY2aTFuYzBuV1E6MQ&amp;ifq" : $hSettings[feedback_form_key_key]
		
		#update the boilerplate form.
		@FEEDBACK_FORM["<feedback-form-key>"] = feedback_form_key_value
		
		@FEEDBACK_LINK = openFile("files/system/feedbackform/" + lang.downcase + "_feedback_link.txt")	

		
  end
  
  
  def addFeedbackForm (url_in_toc_file, file_in_webhelp, its_html)
	
	    portal_page_name = ($hSettings["portal_page_name"].nil? ? "kpp.htm" : get_file($hSettings["portal_page_name"])) 
	    return if portal_page_name == get_file(file_in_webhelp)
			#next if (get_file (e.attributes['url']) == $hSettings["Sportal_page_name"])
			   
			#add the 'Rate this topic' link before the first closing <h> element.
			position_of_first_closing_heading_element = its_html.index(/<\/h\d>/)
			its_html.insert(position_of_first_closing_heading_element, @FEEDBACK_LINK) if !position_of_first_closing_heading_element.nil?
			
			#add the feedback form.			
	    its_html.gsub!(/<\/body>/i, feedback_form) 
      
  end  

end

class ShowmeProcessor

  
  def loadFiles (lang, settings_file_root)
  
    @LIST_TEMPLATE = openFile("files/system/showmes/list_link_template_" + lang + ".txt")
    @CONTEXT_TEMPLATE = openFile("files/system/showmes/context_link_template_" + lang + ".txt")
    @SHOWMES = IO.readlines($CONFIG_FILES_ROOT + "files/user/showmes/" + settings_file_root + "_showmes_" + lang + ".txt")
    
  
  end
  
  def copyContextualIcon(webhelp_path)
  
    begin
    
    FileUtils.cp "files/system/showmes/i_help_video.png", webhelp_path + "/i_help_video.png"
  
    rescue Exception => e

      #puts e.to_s

    end
  
  end

  
  def addShowmeLinks (webhelp_file_in_contents_folder, html_of_webhelp_file_in_contents_folder, lang)
  
    s3_bucket = String.new($hSettings["s3_bucket"])
    s3_bucket.gsub!("<LANG>", lang)
    
    @SHOWMES.each do |row_in_showmes_file|
		
      
      #get rid of the newline character that IO.readlines adds to the end of every line.	 
      row_in_showmes_file.chomp!
      
      #skip to the next line if the current line is a comment.
      next if row_in_showmes_file[0,1] == "#"
  
      #get all the bits from the current line.
      #there can be an abitrary number of tabs between the bits.
      text_where_link_goes, wrapper_file_for_showme, page_where_link_goes, showme_width, showme_height = row_in_showmes_file.split(/\t+/)
      
      #skip to the next line in the list of showmes if the current line doesn't match the webhelp file we're looking at.
      next if !(webhelp_file_in_contents_folder == page_where_link_goes)
			
      #use the default height and width if there are no height and width specified in the showme list.
      showme_width = showme_width.nil? ? $hSettings["default_showme_width"] : showme_width
      showme_height = showme_height.nil? ? $hSettings["default_showme_height"] : showme_height
      
      #build the URL to put into the link text.
      url_in_link = s3_bucket + wrapper_file_for_showme
  
      #check whether the file we're looking at is the file that contains the list of showmes, or a file
      #that contains contextual links from within its text.
      #the text we use to build the link is different in these cases.
      if webhelp_file_in_contents_folder == $hSettings["showme_list_" + lang]
    
        #it's the file that contains the list of showmes;
        #we wrap the link around the text_where_link_goes
        link_text_to_add = String.new(@LIST_TEMPLATE)
        link_text_to_add["<LINK_TEXT>"] = text_where_link_goes
				
				#generate the showme wrapper.
				if $hSettings["generate_wrappers"]
				  
					#make the wrappers folder for the language we're processing.
					dir_to_make = $CONFIG_FILES_ROOT + "files/user/showmes/wrappers/" + lang
					FileUtils.makedirs(dir_to_make) unless File.exists?(dir_to_make)
				  
					#build the wrapper for the showme.
					generateWrapper(wrapper_file_for_showme, text_where_link_goes, lang)
				
				end
		
             
      else

        #it's a file that contains contextual links;
        #the link comes immediately after the text_where_link_goes
        link_text_to_add = String.new(@CONTEXT_TEMPLATE)
        link_text_to_add = text_where_link_goes + link_text_to_add
				
				#add the path to the contextual icon.
				#(if it's a legacy system, the icon is in the same folder as the topic file;
				# in a single-sourced system, the icon is two folders up.)
				link_text_to_add["<PATH>"] = $hSettings["webhelp_content_folder"] == "legacy" ? "" : "../../"	 
	 
      end  # is it the showme list or a contextual file?
     
      #set the height and width of the showme popup.
	  
      link_text_to_add["<WIDTH>"] = showme_width.to_s
      link_text_to_add["<HEIGHT>"] = showme_height.to_s
	 
      #finish building the link text by adding the URL of the wrapper file.
      link_text_to_add["<URL>"] = url_in_link
	    
      #update the HTML of the webhelp file with the link.
      begin
			
        html_of_webhelp_file_in_contents_folder[text_where_link_goes] = link_text_to_add			
      rescue Exception => e
        puts "\r\n\r\nShowme links error!\r\nTopic:      " + webhelp_file_in_contents_folder + "\r\nLink text:  " + text_where_link_goes + "\r\nError:      " + e.message + "\r\n\r\n"
			end

    end  #@SHOWMES.each
    
  end  #addShowmeLinks
	
end #ShowmeProcessor


class AboutboxProcessor


  def update_about_box (webhelp_path, lang)
	
	  ###########################################################################
		#NOTE: as well as the changes to the JS here, the ENG whskin_banner.htm 
		#file also has additional code that changes the width of the table 
		#containing the About box text.
		#(line 58 in version 2012.2.0)
		###########################################################################

	  ###########################################################################
	  #first, edit the javascript file that controls the navigation bar in situ. 
	  
		#variables:
		whtbar = "whtbar.js"
	  files_root =  "files/system/aboutbox/"
		splitter_text = "function showBanner()"
		
		#open it.
		javascript = openFile(webhelp_path + "/" + whtbar)
		
		#split the file into two on the name of the function we want to change.
		scriptbits = javascript.split(splitter_text)
		
		#get the About box dimensions.
		width = buildHashFromKeyValueList($hSettings["aboutbox_width"].to_s)
		height = buildHashFromKeyValueList($hSettings["aboutbox_height"].to_s)
		
		#put the dimensions into the second bit of the split file.
		scriptbits[1].sub!(/nWidth=[0-9]*/,"nWidth=" + width[lang])
		scriptbits[1].sub!(/nHeight=[0-9]*/,"nHeight=" + height[lang])
		
		#there is a block of JavaScript that changes the dimensions in IE+ (line 629...)
		#the following code modifies that block by changing the following: 'nHeight+=20'
		#the changes are:
		# * no height increase in JPN
		# * increase the width in JPN and ENG
		# * reduce the height increase in ENG
		change_to = (lang == "ENG" ? "{nHeight+=12;nWidth+=15;}" : "{nHeight+=0;nWidth+=15;}")
		scriptbits[1].sub!(/nHeight\+=20;/, change_to)
		
		#put the file back together and write it to disk.
		new_javascript = scriptbits[0] + splitter_text + scriptbits[1]
		writeFile(webhelp_path + "/" + whtbar, new_javascript)
		
		#done editing the JavaScript.
		###############################################################################
		
		###############################################################################
		#copy the image files
		
		images = ["mdsol_CR3_LR2.jpg", "mdsol_LOGO_LR1.jpg" ]
		images.each { |image| FileUtils.cp files_root + image, webhelp_path + "/" + image }
		
		#done the image files.
    ###############################################################################
	  
		###############################################################################
		#now, the About box itself.
    aboutbox = files_root + "whskin_banner_" + lang + ".htm"
		aboutbox_html = openFile(aboutbox)
		
		placeholders = ["product_name", "product_version", "author_name", "copyright_year"]
		placeholders.each { |ph| aboutbox_html.gsub!("[" + ph + "]", $hSettings[ph].to_s) }
		
		writeFile(webhelp_path + "/whskin_banner.htm", aboutbox_html) 
		
		#done the About box.
		###############################################################################

  end #updateAboutBox

end #Aboutbox processor


class TableIconProcessor

  def copy_icons(webhelp_path)
    
    begin

      FileUtils.cp "files/system/tableicons/lightbulb_d.png", webhelp_path + "/lightbulb_d.png" 
      FileUtils.cp "files/system/tableicons/pushpin_d.png", webhelp_path + "/pushpin_d.png"
      FileUtils.cp "files/system/tableicons/triangle_d.png", webhelp_path + "/triangle_d.png"
    
    rescue Exception => e

      puts e.to_s 

    end  

  end #copyIcons


  def addIcons(html_of_webhelp_page)

    note_icon_text = '<p class="IconNote">'
    note_icon_image = "<img src='../../pushpin_d.png'/>" 
    
    important_icon_text = '<p class="IconImportant">'
    important_icon_image = "<img src='../../triangle_d.png'/>"
 
    tip_icon_text = '<p class="IconTip">' 
    tip_icon_image = "<img src='../../lightbulb_d.png'/>"

    html_of_webhelp_page.gsub!(note_icon_text, note_icon_text + note_icon_image)
    html_of_webhelp_page.gsub!(important_icon_text, important_icon_text + important_icon_image)
    html_of_webhelp_page.gsub!(tip_icon_text, tip_icon_text + tip_icon_image)

  end  #add Icons



end # TableIconProcessor
