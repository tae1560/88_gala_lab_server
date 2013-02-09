# coding: utf-8

# 먼저 사용자 정보를 받는다.
def get_user_name(io)
  str = ""
  while line = io.gets;
    str += line

    puts "str : #{str}"
    begin
      data = JSON.parse(str)

      if data.has_key? 'type'
        if data['type'].equal? "username"
          return data['username']
        end

      end
    rescue
      bt = $!.backtrace * "\n  "
      ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
    end

  end
  return nil
end

namespace :server do
  task :start => :environment do

    #require 'gserver'
    #
    #class BasicServer < GServer
    #  def serve(io)
    #    loop do
    #      puts "#{io} has connected"
    #
    #      begin
    #        name = get_user_name io
    #        puts "name = #{name}"
    #
    #      rescue
    #        bt = $!.backtrace * "\n  "
    #        ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
    #      ensure
    #        puts "#{io} has disconnected"
    #        s.close
    #      end
    #    end
    #  end
    #
    #  # 먼저 사용자 정보를 받는다.
    #  def get_user_name(io)
    #    str = ""
    #    while line = io.gets;
    #      str += line
    #      begin
    #        data = JSON.parse(str)
    #
    #        if result.has_key? 'name'
    #          return data['name']
    #        end
    #      rescue
    #        bt = $!.backtrace * "\n  "
    #        ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
    #      end
    #
    #    end
    #    return nil
    #  end
    #end
    #
    #server = BasicServer.new(1234)
    #server.start
    #puts "Server has been started"
    #
    #loop do
    #  break if server.stopped?
    #end
    #puts "Server has been terminated"


    require 'socket'  # TCPServer

    ss = TCPServer.new(1234)
    waiting_queue = []

    puts "Server has been started"
    loop {
      Thread.start(ss.accept) { |io|

        loop do
          puts "#{io} has connected"

          begin
            name = get_user_name io
            puts "name = #{name}"

          rescue
            bt = $!.backtrace * "\n  "
            ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
          ensure
            puts "#{io} has disconnected"
            io.close
            break
          end
        end

        #waiting_queue.push s
        #
        #begin
        #  while clients.length == 1
        #    puts "#{s} start sleep"
        #    sleep(1)
        #  end
        #  puts "ended"
        #  s.print "test"
        #
        #  #while line = s.gets;  # Returns nil on EOF.
        #  #  s.print line.inspect
        #  #  (s << "You wrote: #{line.inspect}\r\n").flush
        #  #  puts line.inspect
        #  #
        #  #  clients.each do |client|
        #  #    client.print "TESMP\n"
        #  #  end
        #  #end
        #rescue
        #  bt = $!.backtrace * "\n  "
        #  ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
        #ensure
        #  s.close
        #end
        #clients.delete s
      }
    }

    puts "Server has been terminated"

  end
end