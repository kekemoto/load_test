require "socket"
require "async"

server = TCPServer.new 80

Async do |task|
  loop do
    sock = server.accept

    task.async do
      headers = []
      loop do
        msg = sock.gets
        break if msg == "\r\n"
        headers << msg.chomp
      end

      sleep [0, 0.1, 0.2, 0.3].sample

      sock.puts "HTTP/1.0 200 OK"
      sock.puts "Content-Type: text/plain"
      sock.puts
      sock.puts "message body"
      sock.close
    end
  end
end
