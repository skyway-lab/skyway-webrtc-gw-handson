require './peer.rb'

require "net/http"
require "json"
require "socket"

HOST = "localhost"
PORT = 8000
TARGET_ID = "js"

# create_peer, listen_open_eventはpeer.rbへ
# request, async_get_eventはutil.rbへ
# 移動

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

def on_open(peer_id, peer_token)
  (video_id, video_ip, video_port) = create_media(true)

  th_call = listen_call_event(peer_id, peer_token) {|media_connection_id|
    answer(media_connection_id, video_id)
    cmd = "gst-launch-1.0 v4l2src device=/dev/video0 ! videoconvert ! video/x-raw,width=640,height=480,format=I420 ! videoconvert ! x264enc bitrate=8000 pass=quant quantizer=25 rc-lookahead=0 sliced-threads=true speed-preset=superfast sync-lookahead=0 tune=zerolatency ! rtph264pay ! udpsink port=#{video_port} host=#{video_ip} sync=false";
    system(cmd)
  }

  th_call.join
end

if __FILE__ == $0
  if ARGV.length != 1
    p "please input peer id"
    exit(0)
  end
  # 自分のPeer IDは実行時引数で受け取っている
  peer_id = ARGV[0]

  # SkyWayのAPI KEYは盗用を避けるためハードコーディングせず環境変数等から取るのがbetter
  skyway_api_key = ENV['API_KEY']

  # SkyWay WebRTC GatewayにPeer作成の指示を与える
  # 以降、作成したPeer Objectは他のユーザからの誤使用を避けるためtokenを伴って操作する
  peer_token = create_peer(skyway_api_key, peer_id)
  # WebRTC GatewayがSkyWayサーバへ接続し、Peerとして認められると発火する
  # この時点で初めてSkyWay Serverで承認されて正式なpeer_idとなる
  th_onopen = listen_open_event(peer_id, peer_token) {|peer_id, peer_token|
    on_open(peer_id, peer_token)
  }

  th_onopen.join
end
