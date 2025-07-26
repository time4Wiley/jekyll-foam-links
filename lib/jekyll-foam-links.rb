# frozen_string_literal: true

require "jekyll"

module Jekyll
  module FoamLinks
    # Hook into the document processing pipeline for wikilinks
    Jekyll::Hooks.register [:pages, :documents], :pre_render do |doc|
      # Only process markdown files
      next unless doc.extname == ".md"
      
      # Get the document content
      content = doc.content
      
      # Regular expressions for matching wikilinks, tags, mentions
      wikilink_regex = /\[\[([^\]]+)\]\]/
      embed_regex = /!\[\[([^\]]+)\]\]/
      tag_regex = /(?:^|[^#\w])#([a-zA-Z0-9][\w-]*)/
      mention_regex = /(?:^|[^@\w])@([a-zA-Z0-9][\w-]*)/
      
      # Find all wikilinks, embedded wikilinks, tags, and mentions
      wikilinks = content.scan(wikilink_regex).flatten
      embeds = content.scan(embed_regex).flatten
      tags = content.scan(tag_regex).flatten
      mentions = content.scan(mention_regex).flatten
      
      # Combine and deduplicate
      all_links = (wikilinks + embeds + tags + mentions).uniq
      
      # Skip if no wikilinks found
      next if all_links.empty?
      
      # Get the site to access all documents
      site = doc.site
      all_documents = site.pages + site.collections.values.flat_map(&:docs)
      
      # Filter to only markdown files
      markdown_files = all_documents.select { |d| d.extname == ".md" }
      
      # Generate reference definitions
      definitions = []
      link_replacements = {}
      
      all_links.each do |link|
        # Clean the link text
        link_text = link.strip
        
        # Handle pipe notation: extract target from [[target|display]]
        if link_text.include?('|')
          target_text = link_text.split('|', 2)[0].strip
        else
          target_text = link_text
        end
        
        # Check if this is a tag or mention
        is_tag = tags.include?(link_text)
        is_mention = mentions.include?(link_text)
        
        if is_tag
          # Check if we have a base URL for tags in the site config
          config = doc.site.config['foam_links'] || {}
          tag_base_url = config['tag_base_url']
          
          if tag_base_url
            # Use full URL if configured
            tag_url = "#{tag_base_url}#{link_text}"
            definition = "[##{link_text}]: #{tag_url} \"Tag: #{link_text}\""
          else
            # Fall back to relative path
            tag_path = "tags/#{link_text}"
            definition = "[##{link_text}]: #{tag_path} \"Tag: #{link_text}\""
          end
          definitions << definition
        elsif is_mention
          # Check if we have a base URL for mentions in the site config
          config = doc.site.config['foam_links'] || {}
          mention_base_url = config['mention_base_url']
          
          if mention_base_url
            # Use full URL if configured
            mention_url = "#{mention_base_url}#{link_text}"
            definition = "[@#{link_text}]: #{mention_url} \"Mention: #{link_text}\""
          else
            # Fall back to relative path
            mention_path = "mentions/#{link_text}"
            definition = "[@#{link_text}]: #{mention_path} \"Mention: #{link_text}\""
          end
          definitions << definition
        else
          # Find the target document
          target = find_target_document(target_text, markdown_files)
          
          if target
            # Generate relative path
            relative_path = generate_relative_path(doc, target)
            
            # Get the title from the target document
            title = extract_title(target)
            
            # Create the definition
            definition = format_definition(link_text, relative_path, title)
            definitions << definition
            
            # Store replacement for wikilink
            link_replacements[target_text] = { path: relative_path, title: title }
          else
            # For non-existent links, create placeholder definition
            definition = "[#{link_text}]: #{link_text} \"#{link_text}\""
            definitions << definition
          end
        end
      end
      
      # Skip if no wikilinks found
      next if all_links.empty?
      
      # Replace wikilinks with reference-style links
      new_content = content.dup
      
      # Replace regular wikilinks
      new_content.gsub!(wikilink_regex) do |match|
        link_text = $1.strip
        # Handle pipe notation: [[target|display text]]
        if link_text.include?('|')
          target, display = link_text.split('|', 2)
          target = target.strip
          display = display.strip
          # Check if we have a valid replacement
          if link_replacements[target]
            "[#{display}](#{link_replacements[target][:path]})"
          else
            "[#{display}](#{target})"
          end
        else
          "[#{link_text}]"
        end
      end
      
      # Replace embedded wikilinks
      new_content.gsub!(embed_regex) do |match|
        link_text = $1.strip
        # Handle pipe notation for embeds
        if link_text.include?('|')
          target, display = link_text.split('|', 2)
          target = target.strip
          "![#{target}]"
        else
          "![#{link_text}]"
        end
      end
      
      # Replace tags with reference-style links
      new_content.gsub!(tag_regex) do |match|
        prefix = match[0] == '#' ? '' : match[0]
        tag_name = $1
        "#{prefix}[##{tag_name}]"
      end
      
      # Replace mentions with reference-style links
      new_content.gsub!(mention_regex) do |match|
        prefix = match[0] == '@' ? '' : match[0]
        mention_name = $1
        "#{prefix}[@#{mention_name}]"
      end
      
      
      # Add reference definitions at the end
      reference_section = [
        "",
        '[//begin]: # "Autogenerated link references for markdown compatibility"',
        definitions.join("\n"),
        '[//end]: # "Autogenerated link references"'
      ].join("\n")
      
      # Update the document content for rendering only
      doc.content = new_content + "\n" + reference_section
      
      Jekyll.logger.debug "Foam Link References:", "Processed #{doc.relative_path}"
    end
    
    private
    
    def self.find_target_document(link_text, all_documents)
      # Remove any path components from the link
      basename = File.basename(link_text, ".*")
      
      # Find matching document by basename
      all_documents.find do |doc|
        doc_basename = File.basename(doc.basename, ".*")
        doc_basename == basename || doc.data["slug"] == basename
      end
    end
    
    def self.generate_relative_path(source, target)
      source_dir = File.dirname(source.relative_path)
      target_path = target.relative_path
      
      # Calculate relative path
      relative = Pathname.new(target_path).relative_path_from(Pathname.new(source_dir))
      
      # Remove .md extension for compatibility
      path = relative.to_s.gsub(/\.md$/, '')
      
      # Handle spaces in filenames
      if path.include?(' ')
        path
      else
        path
      end
    end
    
    def self.extract_title(document)
      # Try to get title from front matter first
      if document.data["title"]
        document.data["title"]
      else
        # Try to get title from content
        content = document.content
        h1_match = content.match(/^#\s+(.+)$/m)
        
        if h1_match
          h1_match[1].strip
        else
          # Use filename without extension as title
          File.basename(document.basename, ".*").gsub(/[-_]/, ' ').capitalize
        end
      end
    end
    
    def self.format_definition(label, url, title)
      # Handle URLs with spaces
      if url.include?(' ')
        "[#{label}]: <#{url}> \"#{title}\""
      else
        "[#{label}]: #{url} \"#{title}\""
      end
    end
    
  end
end