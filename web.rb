require 'sinatra'
require 'sinatra/json'
require 'json'
require 'open-uri'

get '/' do
  ""
end

get '/api/v1/rapportive/:email' do
  json call_api params[:email]
end

# Sends a query to the undocumented Rapportive API
# return json object if valid email
def call_api(email)
  user = generate_email
  status_url = 'https://rapportive.com/login_status?user_email=' + user
  profile_url = 'https://profiles.rapportive.com/contacts/email/' + email

  # exponential backoff to get session_token
  response = exp_backoff 2, status_url
  session_token = response['session_token'] if response

  if response.nil? || response['error']
    false
  elsif response['status'] == 200 && session_token
    header = { 'X-Session-Token' => session_token }

    response = exp_backoff 2, profile_url, header
    if response.nil?
      false
    elsif response['success'] != 'nothing_useful'
      response['contact']
    end
  end
end

# Exponential Backoff when visiting a URL
def exp_backoff(up_to, url, header = {})
  tries = 0
  begin
    tries += 1
    response = JSON.parse(open(url, header).read)
  rescue OpenURI::HTTPError
    if tries < up_to
      sleep( 2 ** tries )
      retry
    end
  end
end

def generate_email(size = 6)
  charset = %w{ 1 2 3 4 6 7 9 A C D E F G H J K M N P Q R T V W X Y Z a b c d e f g h j k l m p q r s t v z}
  (0...size).map{ charset.to_a[rand(charset.size)] }.join + '@gmail.com'
end
