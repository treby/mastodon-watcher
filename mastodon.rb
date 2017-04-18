require 'mastodon'
require 'nokogiri'

RECENT_ID_FILE=ENV.fetch('RECENT_ID_FILE', 'recent_id')
FETCH_INTERVAL=ENV.fetch('FETCH_INTERVAL', '30').to_i
MASTODON_BASE_URL=ENV.fetch('MASTODON_BASE_URL')
MASTODON_BAARER_TOKEN=ENV.fetch('MASTODON_BAARER_TOKEN')
SLACK_WEBHOOK_URL=ENV.fetch('SLACK_WEBHOOK_URL')
SLACK_ROOM_NAME=ENV.fetch('SLACK_ROOM_NAME')

client = Mastodon::REST::Client.new(base_url: MASTODON_BASE_URL, baarer_token: MASTODON_BAARER_TOKEN)

loop do
  retry_count = 0
  begin
    recent_id = 0
    if File.exists?(RECENT_ID_FILE)
      recent_id = open(RECENT_ID_FILE).read.to_i
    end
    max_id = recent_id

    client.public_timeline(local: true).reverse_each do |status|
      next unless recent_id < status.id
      max_id = status.id if max_id < status.id

      `curl -X POST --data-urlencode 'payload={"channel": "#{SLACK_ROOM_NAME}", "username": "#{status.account.username}", "text": "> #{Nokogiri::HTML(status.content).text}\n\n#{status.url}", "icon_url": "#{status.account.avatar}"}' #{SLACK_WEBHOOK_URL}`
    end

    open(RECENT_ID_FILE, 'w') { |f| f.puts max_id }
    sleep FETCH_INTERVAL
  rescue StandardError => e
    if retry_count < 3
      sleep 5
      retry_count += 1
      retry
    end

    `curl -X POST --data-urlencode 'payload={"channel": "#{SLACK_ROOM_NAME}", "username": "mastodon-bot", "text": "Hi, treby. I am down. Please check.\n\n#{e.inspect}", "icon_emoji": ":warning:"}' #{SLACK_WEBHOOK_URL}`
    raise
  end
end
