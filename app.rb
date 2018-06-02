require 'sinatra'
require 'json'
require 'active_support/time'
require 'intercom'
require 'nokogiri'
require 'dotenv'
require 'open-uri'
require 'securerandom'

Dotenv.load

DEBUG = ENV["DEBUG"] || nil

# allow all files in the public directory to be read
get '/' do
  File.read(File.join('public', 'index.html'))
end

post '/' do
  request.body.rewind
  payload_body = request.body.read
  if DEBUG then
    puts "==============================================================="
    puts payload_body
    puts "==============================================================="
  end
  verify_signature(payload_body)
  response = JSON.parse(payload_body)
  if DEBUG then
    puts "Topic Recieved: #{response['topic']}"
  end
  if is_supported_topic(response['topic']) then
    process_webhook(response)
  end
end

def init_intercom
  if @intercom.nil? then
    @intercom = Intercom::Client.new(token: ENV["TOKEN"])
  end
end

def is_supported_topic(topic)
  topic.index("conversation.user.created") || topic.index("conversation.user.replied") || topic.index("conversation.admin.replied")
end

def process_webhook(response)
  if DEBUG then
    puts "Process webhook....."
  end

  begin
    message = response['data']['item']['conversation_message']
    conversation_parts = response['data']['item']['conversation_parts']['conversation_parts']
    conversation_id = response['data']['item']['id']

    if conversation_parts.length > 0 
      attachments = conversation_parts[0]['attachments']
    else 
      attachments = message['attachments']
    end
    puts attachments.inspect
    files = extract_and_return_files(attachments)
    if files.count > 0 then
      send_reply(conversation_id, files)
    end
  rescue Exception => e 
    if DEBUG then
      puts "Exception!"
      puts e.message
      puts e.backtrace.join("\n")
    else
      puts "Exception =("
    end
    return
  end
end

def extract_and_return_files(array_of_files)
    files = []
    return files if (array_of_files.nil? || array_of_files.count == 0)
    main_folder_name = SecureRandom.uuid
    main_folder = File.join(ENV["UPLOAD_DIRECTORY"], main_folder_name)
    Dir.mkdir(main_folder)
    array_of_files.each{|attachment|
      individual_attachment_file = download(attachment["url"], main_folder)
      # create separate folder for each attachment in case contain same attachment name
      individual_attachment_folder_name = SecureRandom.uuid
      individual_attachment_folder = File.join(main_folder, individual_attachment_folder_name)
      Dir.mkdir(individual_attachment_folder)
      extract_attachments_from_file(individual_attachment_file, individual_attachment_folder)
      File.delete(individual_attachment_file) # clean up temp file
      extracted_files = Dir.entries(individual_attachment_folder).reject{|file_name| file_name == "." || file_name == ".."}
      if extracted_files.count == 0
        Dir.unlink(individual_attachment_folder)
      else
        files = files.concat(extracted_files.map{|f| File.join(main_folder_name, individual_attachment_folder_name, f)})
      end
    }
    # if no attachments delete empty folder
    if files.count == 0 
      Dir.unlink(main_folder)
    end
    return files
end

# currently requires tnef
# https://github.com/verdammelt/tnef
def extract_attachments_from_file(input_file, output_directory)
  command = "tnef --save-body -C \"#{output_directory}\" \"#{input_file}\""
  system command
end

def download(url, folder)
  output_name = File.join(folder, SecureRandom.uuid)
  IO.copy_stream(open(url), output_name)
  output_name
end

def send_reply(conversation_id, files)
  init_intercom
  admin_id = ENV["bot_admin_id"] 
  public_urls = files.map{|file| File.join(ENV["SERVER_URL"], file)}
  message = "Extracted attachments: \n- #{public_urls.join("\n- ")}"
  puts conversation_id
  puts admin_id
  puts message
  @intercom.conversations.reply(id: conversation_id, type: 'admin', body: message, admin_id: admin_id, message_type: 'note')
end

def verify_signature(payload_body)
  secret = ENV["secret"]
  expected = request.env['HTTP_X_HUB_SIGNATURE']

  if secret.nil? || secret.empty? then
    puts "No secret specified so accept all data"
  elsif expected.nil? || expected.empty? then
    puts "Not signed. Not calculating"
  else

    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload_body)
    puts "Expected  : #{expected}"
    puts "Calculated: #{signature}"
    if Rack::Utils.secure_compare(signature, expected) then
      puts "   Match"
    else
      puts "   MISMATCH!!!!!!!"
      return halt 500, "Signatures didn't match!"
    end
  end
end