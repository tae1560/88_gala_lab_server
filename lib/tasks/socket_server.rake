# coding: utf-8

namespace :server do
  task :start => :environment do

    class UserInformation
      attr_accessor :name, :io, :enemy_io

      def to_json
        json_data = {}
        json_data["name"] = self.name
        return json_data
      end
    end

    class Server

    end
    def initialize
      puts "initialize"

      @@functions = {} # type, lambda
      @@logon_queue = {} # io, user_information
      @@waiting_queue = [] # user_information

      make_functions
    end
    def make_functions
      # 1. 무작위게임 신청
      @@functions["matching_request"] = lambda{|io, json_data|
        unless @@waiting_queue.include? @user_information
          @@waiting_queue.push @user_information
        end

        if @@waiting_queue.length >= 2
          #matching 0, 1
          user_information1 = @@waiting_queue[0]
          user_information2 = @@waiting_queue[1]

          @@waiting_queue.delete user_information1
          @@waiting_queue.delete user_information2

          user_information1.enemy_io = user_information2.io
          user_information2.enemy_io = user_information1.io

          data = {"type" => "matching_request", "user_information" => user_information1.to_json}
          user_information1.io.puts data.to_s

          data = {"type" => "matching_request", "user_information" => user_information2.to_json}
          user_information2.io.puts data.to_s
        end
      }


      # 스킬 공격
      @@functions["attack_skill"] = lambda { |io, json_data|
        user_information = @@logon_queue[io]

        data = {"type" => "matching_request", "user_information" => user_information1.to_json}
        user_information.io.puts data.to_s
      }



      # TODO
      # 1. 무작위게임 신청
      # 2. 친구와 게임 신청
      # 3. 친구와 게임 수락
      # 4.



    end

    def debug string
      puts string
    end

    # 사용자 정보를 받는다.
    def get_user_name(io)
      str = ""
      while line = io.gets;
        begin
          data = JSON.parse(line)

          if data.has_key? 'type'
            if data['type'] == "username"
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

    def valid_login? name
      if name and name.length > 0
        return true
      end
      return false
    end

    def reading_socket io
      while line = io.gets;
        debug "original_data : #{json_data}"
        json_data = JSON.parse(line)
        debug "json_data : #{json_data.inspect}"

        type = json_data['type']
        if type
          if @@functions[type]
            @@functions[type].call io, json_data
          else
            puts "function #{type} is not implemented"
          end

        end
      end
    end

    # each client
    def client_logic(io)
      # 사용자 정보를 받는다.
      name = get_user_name io
      debug "name = #{name}"

      # login validation
      if valid_login? name
        @user_information = UserInformation.new
        @user_information.name = name
        @user_information.io = io
        @@logon_queue[io] = @user_information

        # 받고 나서 서버 통신 시작
        debug "#{io} has connected"
        loop do
          begin
            # 대기
            reading_socket io
          rescue
            bt = $!.backtrace * "\n  "
            ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
          ensure
            io.close
            break
          end
        end
        debug "#{io} has disconnected"
      end
    end


    require 'socket'  # TCPServer

    # initialize
    initialize

    ss = TCPServer.new(1234)

    debug "Server has been started"
    loop {
      Thread.start(ss.accept) { |io|
        client_logic(io)
      }
    }
    debug "Server has been terminated"

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

