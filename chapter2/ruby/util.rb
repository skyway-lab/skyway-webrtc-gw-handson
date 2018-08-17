require "net/http"
require "json"
require "socket"

#同期的にREST APIにアクセスする
def request(method_name, uri, *args)
  response = nil
  Net::HTTP.start(HOST, PORT) { |http|
    response = http.send(method_name, uri, *args)
  }
  response
end

#Long PollでEventを取得する
def async_get_event(uri, event, &callback)
  e = nil
  thread_event = Thread.new do
    # timeoutする場合があるのでその時はやり直す
    while e == nil or e["event"] != event
      res = request(:get, uri)
      # Status Code 200で以下のようなJSONが帰ってくるのでparseする
      # {
      #   "event"=>EVENT_NAME,
      #   "params"=> OBJEDT
      # }
      if res.is_a?(Net::HTTPOK)
        e = JSON.parse(res.body)
      end
    end
    if callback
      callback.call(e)
    end
  end.run
  thread_event
end

