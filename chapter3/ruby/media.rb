require "net/http"
require "json"
require "socket"

require './util.rb'

# http://35.200.46.204/#/3.media/media
def create_media(is_video)
  params = {
      is_video: is_video,
  }
  res = request(:post, "/media", JSON.generate(params))

  if res.is_a?(Net::HTTPCreated)
    json = JSON.parse(res.body)
    media_id = json["media_id"]
    ip_v4 = json["ip_v4"]
    port = json["port"]
    [media_id, ip_v4, port]
  else
    # 異常動作の場合は終了する
    p res
    exit(1)
  end
end

def listen_call_event(peer_id, peer_token, &callback)
  async_get_event("/peers/#{peer_id}/events?token=#{peer_token}", "CALL") { |e|
    media_connection_id = e["call_params"]["media_connection_id"]
    callback.call(media_connection_id)
  }
end

def answer(media_connection_id, video_id)
  constraints =   {
      "video": true,
      "videoReceiveEnabled": false,
      "audio": false,
      "audioReceiveEnabled": false,
      "video_params": {
          "band_width": 1500,
          "codec": "H264",
          "media_id": video_id,
          "payload_type": 100,
      }
  }
  params = {
      "constraints": constraints,
      "redirect_params": {} # 相手側からビデオを受け取らないため、redirectの必要がない
  }
  res = request(:post, "/media/connections/#{media_connection_id}/answer", JSON.generate(params))
  if res.is_a?(Net::HTTPAccepted)
    JSON.parse(res.body)
  else
    # 異常動作の場合は終了する
    p res
    exit(1)
  end
end

def listen_stream_event(media_connection_id, &callback)
  async_get_event("/media/connections/#{media_connection_id}/events", "STREAM") { |e|
    if callback
      callback.call()
    end
  }
end

def close_media_connection(media_connection_id)
  res = request(:delete, "/media/connections/#{media_connection_id}")
  if res.is_a?(Net::HTTPNoContent)
    # 正常動作の場合NoContentが帰る
  else
    # 異常動作の場合は終了する
    p res
    exit(1)
  end
end